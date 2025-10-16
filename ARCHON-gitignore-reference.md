# 🧭 `.gitignore Reference Guide — ARCHON Project`

**Purpose:**  
This guide explains how your `.gitignore` protects your local environment, keeps `origin` and `upstream` cleanly in sync, and shows what happens when you run `git pull` or `git push` under your new setup.

---

## ⚙️ 1. Overview

Your `.gitignore` ensures that only *core source code and shared assets* are tracked in Git, while everything local (like environment variables, editor settings, and temporary logs) is ignored.

This makes collaboration and syncing with the upstream Archon repo safe and frictionless — no private or environment-specific files ever leak into version control.

---

## 🧩 2. Ignored File Categories

| Category | Description | Examples |
|-----------|--------------|-----------|
| 🧠 **Python cache & venvs** | Prevents compiled or cached Python files from cluttering commits | `__pycache__/`, `.venv/`, `*.pyc` |
| 🧱 **Node / Frontend builds** | Ignores build output and dependencies from the frontend container | `node_modules/`, `dist/`, `build/` |
| 🐘 **Supabase / DB artifacts** | Skips local database files and temp Supabase folders | `.supabase/`, `*.db`, `*.sqlite` |
| 🐳 **Docker & environment** | Protects secrets and local overrides | `.env`, `.env.*`, `docker-compose.override.yml` |
| ⚡ **PowerShell scripts** | Keeps local automation scripts untracked | `sync-archon.ps1`, `*.ps1.bak` |
| 🧰 **Editor / IDE settings** | Ignores user-specific dev environment configs | `.vscode/`, `.idea/`, `.zed/` |
| 🪶 **Temporary / logs / testing** | Keeps runtime and test outputs out of Git | `logs/`, `tmp/`, `UAT/`, `release-notes-*.md` |
| 🧩 **Archon-specific** | Ignores cache/output from example workflows | `archon-example-workflow/output/` |

---

## 🔒 3. Local Files You Can Safely Keep Untracked

These files can exist locally without ever touching Git:

| File / Folder | Purpose |
|----------------|----------|
| `.env` | Supabase + OpenAI credentials |
| `sync-archon.ps1` | Local PowerShell sync script |
| `tmp/`, `logs/` | Temporary debug or workflow output |
| `.vscode/` | Your editor workspace setup |
| `supabase/.local/` | Supabase dev metadata |

✅ Git will automatically **ignore** these files because of your `.gitignore`.

---

## 🔁 4. Understanding `origin`, `upstream`, and Local Behavior

You now have this remote setup:

| Remote | Description | Example URL |
|---------|--------------|--------------|
| `origin` | Your **forked** repo (you push here) | `https://github.com/journeyman33/Archon.git` |
| `upstream` | The **official Archon** source (you pull from here) | `https://github.com/coleam00/Archon.git` |

### ⚙️ Workflow Summary

**Local** ←→ **origin (your fork)** ←→ **upstream (official)**

---

### 🧠 When You Run `git pull`

| Command | What It Does |
|----------|---------------|
| `git pull` | Pulls the latest changes from your current branch’s remote (usually `origin/stable`). |
| `git pull upstream stable` | Pulls the latest official Archon changes into your local branch — this is how you sync your fork. |

**Example full sync:**
```powershell
git fetch upstream
git merge upstream/stable
git push origin stable

