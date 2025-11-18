#!/bin/bash
# Archon Startup Script
# This script ensures all services start in the correct order with proper health checks

set -e

SKIP_SUPABASE=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-supabase)
            SKIP_SUPABASE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-supabase    Skip starting Supabase (assume already running)"
            echo "  --verbose, -v      Show verbose output"
            echo "  --help, -h         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_step() {
    echo -e "\n${CYAN}==> $1${NC}"
}

function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function print_error() {
    echo -e "${RED}✗ $1${NC}"
}

function wait_for_healthy() {
    local container_name=$1
    local max_attempts=${2:-30}
    local delay=${3:-2}

    print_step "Waiting for $container_name to be healthy..."

    for ((i=1; i<=max_attempts; i++)); do
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")

        if [ "$health" = "healthy" ]; then
            print_success "$container_name is healthy"
            return 0
        fi

        if [ "$VERBOSE" = true ]; then
            echo "  Attempt $i/$max_attempts - Status: $health"
        fi

        sleep "$delay"
    done

    print_error "$container_name failed to become healthy after $((max_attempts * delay)) seconds"
    return 1
}

function test_service() {
    local url=$1
    local service_name=$2
    local max_attempts=${3:-10}

    print_step "Testing $service_name at $url..."

    for ((i=1; i<=max_attempts; i++)); do
        if curl -sf "$url" >/dev/null 2>&1; then
            print_success "$service_name is responding"
            return 0
        fi

        if [ "$VERBOSE" = true ]; then
            echo "  Attempt $i/$max_attempts - Not responding yet"
        fi

        sleep 2
    done

    print_error "$service_name is not responding"
    return 1
}

# Main startup sequence
echo -e "${BLUE}"
cat << "EOF"

╔═══════════════════════════════════════════╗
║   Archon Startup Script                   ║
║   Starting all services in correct order  ║
╚═══════════════════════════════════════════╝

EOF
echo -e "${NC}"

# Step 1: Check prerequisites
print_step "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not available"
    exit 1
fi

print_success "Docker and Docker Compose are available"

# Step 2: Start Supabase (if not skipped)
if [ "$SKIP_SUPABASE" = false ]; then
    print_step "Starting local Supabase services..."

    cd ../supabase-local || exit 1
    docker compose -p supabase up -d

    # Wait for Supabase DB to be healthy
    wait_for_healthy "supabase-db" 30 || exit 1

    # Wait for Supabase Kong to be healthy
    wait_for_healthy "supabase-kong" 30 || exit 1

    cd ../archon || exit 1
    print_success "Supabase services are running"
else
    echo -e "${YELLOW}Skipping Supabase startup (assuming already running)${NC}"
fi

# Step 3: Start Archon backend services
print_step "Starting Archon backend services..."

docker compose -p archon up -d archon-server archon-mcp

# Wait for archon-server to be healthy
wait_for_healthy "archon-server" 30 || exit 1

# Wait for archon-mcp to be healthy
wait_for_healthy "archon-mcp" 30 || exit 1

# Step 4: Test API endpoints
test_service "http://localhost:8181/api/health" "Archon API" || exit 1
test_service "http://localhost:8051/health" "Archon MCP" || exit 1

# Step 5: Display service status
print_step "Service Status"
echo ""
docker compose -p archon ps
echo ""

# Step 6: Display access URLs
echo -e "${GREEN}"
cat << "EOF"

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

EOF
echo -e "${NC}"

echo -e "${CYAN}Startup complete! All services are healthy and ready.${NC}"
