# Archon Startup Script for Windows
# This script ensures all services start in the correct order with proper health checks

param(
    [switch]$SkipSupabase,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Wait-ForHealthy {
    param(
        [string]$ContainerName,
        [int]$MaxAttempts = 30,
        [int]$DelaySeconds = 2
    )

    Write-Step "Waiting for $ContainerName to be healthy..."

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        $health = docker inspect --format='{{.State.Health.Status}}' $ContainerName 2>$null

        if ($health -eq "healthy") {
            Write-Success "$ContainerName is healthy"
            return $true
        }

        if ($Verbose) {
            Write-Host "  Attempt $i/$MaxAttempts - Status: $health"
        }

        Start-Sleep -Seconds $DelaySeconds
    }

    Write-Error "$ContainerName failed to become healthy after $($MaxAttempts * $DelaySeconds) seconds"
    return $false
}

function Test-ServiceResponding {
    param(
        [string]$Url,
        [string]$ServiceName,
        [int]$MaxAttempts = 10
    )

    Write-Step "Testing $ServiceName at $Url..."

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 3 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Success "$ServiceName is responding"
                return $true
            }
        } catch {
            if ($Verbose) {
                Write-Host "  Attempt $i/$MaxAttempts - Not responding yet"
            }
        }
        Start-Sleep -Seconds 2
    }

    Write-Error "$ServiceName is not responding"
    return $false
}

# Main startup sequence
Write-Host @"

╔═══════════════════════════════════════════╗
║   Archon Startup Script                   ║
║   Starting all services in correct order  ║
╚═══════════════════════════════════════════╝

"@ -ForegroundColor Blue

# Step 1: Check prerequisites
Write-Step "Checking prerequisites..."

if (!(docker --version 2>$null)) {
    Write-Error "Docker is not installed or not in PATH"
    exit 1
}

if (!(docker compose version 2>$null)) {
    Write-Error "Docker Compose is not available"
    exit 1
}

Write-Success "Docker and Docker Compose are available"

# Step 2: Start Supabase (if not skipped)
if (!$SkipSupabase) {
    Write-Step "Starting local Supabase services..."

    Set-Location ..\supabase-local
    docker compose -p supabase up -d

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start Supabase services"
        Set-Location ..\archon
        exit 1
    }

    # Wait for Supabase DB to be healthy
    if (!(Wait-ForHealthy -ContainerName "supabase-db" -MaxAttempts 30)) {
        Set-Location ..\archon
        exit 1
    }

    # Wait for Supabase Kong to be healthy
    if (!(Wait-ForHealthy -ContainerName "supabase-kong" -MaxAttempts 30)) {
        Set-Location ..\archon
        exit 1
    }

    Set-Location ..\archon
    Write-Success "Supabase services are running"
} else {
    Write-Host "Skipping Supabase startup (assuming already running)" -ForegroundColor Yellow
}

# Step 3: Start Archon backend services
Write-Step "Starting Archon backend services..."

docker compose -p archon up -d archon-server archon-mcp

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to start Archon backend services"
    exit 1
}

# Wait for archon-server to be healthy
if (!(Wait-ForHealthy -ContainerName "archon-server" -MaxAttempts 30)) {
    exit 1
}

# Wait for archon-mcp to be healthy
if (!(Wait-ForHealthy -ContainerName "archon-mcp" -MaxAttempts 30)) {
    exit 1
}

# Step 4: Test API endpoints
if (!(Test-ServiceResponding -Url "http://localhost:8181/api/health" -ServiceName "Archon API")) {
    exit 1
}

if (!(Test-ServiceResponding -Url "http://localhost:8051/health" -ServiceName "Archon MCP")) {
    exit 1
}

# Step 5: Display service status
Write-Step "Service Status"
Write-Host ""
docker compose -p archon ps
Write-Host ""

# Step 6: Display access URLs
Write-Host @"

╔═══════════════════════════════════════════╗
║   All Services Started Successfully! 🎉   ║
╚═══════════════════════════════════════════╝

Access your services:

  📊 Supabase Studio:  http://localhost:60125
  🔧 Archon Backend:   http://localhost:8181
  📚 API Docs:         http://localhost:8181/docs
  🔌 MCP Server:       http://localhost:8051

To start the frontend:
  cd archon-ui-main
  npm run dev

Then visit:  http://localhost:3737

To stop all services:
  docker compose -p archon down

"@ -ForegroundColor Green

Write-Host "Startup complete! All services are healthy and ready." -ForegroundColor Cyan
