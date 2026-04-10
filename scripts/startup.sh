#!/usr/bin/env bash
set -euo pipefail

MOD_VERSION="v2-2026-04-10"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  OpenClaw KaanAssist Mod  [${MOD_VERSION}]                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# ── 1. Seed volume from staged files (first boot or missing) ────
echo "[startup] Seeding volume from /opt/openclaw-seed..."
mkdir -p /root/.openclaw/workspace/skills
mkdir -p /root/.openclaw/workspace/memory
mkdir -p /root/.openclaw/workspace/scripts
mkdir -p /root/.openclaw/credentials
mkdir -p /root/.openclaw/sessions
mkdir -p /root/.openclaw/state

# Always overwrite config (ensures latest version)
cp -f /opt/openclaw-seed/openclaw.json /root/.openclaw/openclaw.json
echo "  ✓ openclaw.json seeded"

# Seed workspace: always update .md docs, preserve skills/memory
for f in /opt/openclaw-seed/workspace/*.md; do
    cp -f "$f" /root/.openclaw/workspace/ 2>/dev/null || true
done
echo "  ✓ workspace docs updated (latest from image)"

# Seed skills only if missing (preserve user-added skills)
if [ ! -d /root/.openclaw/workspace/skills/ceo ]; then
    cp -rn /opt/openclaw-seed/workspace/skills/* /root/.openclaw/workspace/skills/ 2>/dev/null || true
    echo "  ✓ skills seeded (first boot)"
else
    echo "  ✓ skills preserved"
fi

# Copy scripts always (ensure latest)
cp -rf /opt/openclaw-seed/scripts/* /root/.openclaw/workspace/scripts/ 2>/dev/null || true
echo "  ✓ scripts updated"

# ── 2. Clear stale lock files ───────────────────────────────────
find /root/.openclaw -name "*.lock" -delete 2>/dev/null || true
find /root/.openclaw -name "*.jsonl.lock" -delete 2>/dev/null || true
echo "[startup] Lock files cleared."

# ── 3. Git identity ────────────────────────────────────────────
git config --global user.name "Djeyff"
git config --global user.email "djeyff006@gmail.com"

# ── 4. Validate env vars ───────────────────────────────────────
MISSING=""
[ -z "${CODEX_LB_API_KEY:-}" ] && MISSING="${MISSING} CODEX_LB_API_KEY"
[ -z "${TELEGRAM_BOT_TOKEN:-}" ] && echo "[startup] WARNING: TELEGRAM_BOT_TOKEN not set"
[ -z "${NOTION_API_KEY:-}" ] && echo "[startup] WARNING: NOTION_API_KEY not set"
[ -z "${KDRIVE_TOKEN:-}" ] && echo "[startup] WARNING: KDRIVE_TOKEN not set"
[ -z "${SUPABASE_PMS_SERVICE_KEY:-}" ] && echo "[startup] WARNING: SUPABASE_PMS_SERVICE_KEY not set"

if [ -n "$MISSING" ]; then
    echo "[startup] FATAL: Missing:${MISSING}"
    exit 1
fi
echo "[startup] Environment OK."

# ── 5. Write .env for agent exec subprocess access ──────────────
# Dump ALL container env vars except system ones → agent can use them in bash
# Any new var added in Zeabur is available on next restart automatically
echo "[startup] Writing .env for agent subprocess access..."

# System vars to exclude (standard Linux/Node/Docker internals)
EXCLUDE="^(PATH|HOME|HOSTNAME|TERM|SHLVL|PWD|OLDPWD|SHELL|USER|LOGNAME|LANG|LC_|NODE_ENV|NODE_OPTIONS|NODE_PATH|NPM_|COREPACK_|GOPATH|GO_|_=|DEBIAN_|KUBERNETES_|K8S_)"

env | grep -vE "$EXCLUDE" | sort > /root/.openclaw/.env

# Also force-add codexlb routing vars
{
  echo "CLAUDE_CODE_USE_OPENAI=1"
  echo "OPENAI_BASE_URL=http://127.0.0.1:18792/v1"
  echo "OPENAI_API_KEY=${CODEX_LB_API_KEY}"
  echo "OPENAI_MODEL=${OPENAI_MODEL:-gpt-5.4-mini}"
  echo "ZEABUR_GRAPHQL_URL=https://api.zeabur.com/graphql"
} >> /root/.openclaw/.env

chmod 600 /root/.openclaw/.env
echo "  ✓ .env written ($(wc -l < /root/.openclaw/.env) vars)"

# ── 6. Export OpenClaude/Codex vars ─────────────────────────────
export CLAUDE_CODE_USE_OPENAI=1
export OPENAI_BASE_URL="http://127.0.0.1:18792/v1"
export OPENAI_API_KEY="${CODEX_LB_API_KEY}"
export OPENAI_MODEL="${OPENAI_MODEL:-gpt-5.4}"
echo "[startup] codexlb → ${OPENAI_MODEL} (default big, smart router downgrades simple queries)"

# ── 6. Tool check ──────────────────────────────────────────────
echo "[startup] Tools:"
command -v go >/dev/null 2>&1 && echo "  ✓ Go $(go version | awk '{print $3}')" || echo "  ✗ Go"
command -v openclaw >/dev/null 2>&1 && echo "  ✓ OpenClaw" || echo "  ✗ OpenClaw"
command -v codex >/dev/null 2>&1 && echo "  ✓ Codex CLI" || echo "  ✗ Codex"
command -v openclaude >/dev/null 2>&1 && echo "  ✓ OpenClaude" || echo "  ✗ OpenClaude"
echo ""

# ── 7. Verify config was written ───────────────────────────────
if grep -q "gateway" /root/.openclaw/openclaw.json 2>/dev/null; then
    echo "[startup] Config verified at /root/.openclaw/openclaw.json"
else
    echo "[startup] ERROR: Config missing or corrupt!"
fi

# ── 8. Auto-fix config issues ──────────────────────────────────
echo "[startup] Running openclaw doctor --fix..."
openclaw doctor --fix --yes 2>&1 | tail -5 || true
echo ""

# ── 9. Start smart router (model auto-routing) ─────────────────
echo "[startup] Starting smart router..."
if [ -f /opt/openclaw-seed/scripts/smart-router.js ]; then
    node /opt/openclaw-seed/scripts/smart-router.js &
    ROUTER_PID=$!
    sleep 1
    if kill -0 $ROUTER_PID 2>/dev/null; then
        echo "  ✓ Smart router running (PID: $ROUTER_PID, port 18792)"
    else
        echo "  ✗ Smart router failed to start — falling back to direct codexlb"
    fi
else
    echo "  ✗ Smart router script not found — using direct codexlb"
fi

# ── 10. Start gateway ──────────────────────────────────────────
# OpenViking plugin in "local" mode auto-starts the server when gateway boots
echo "[startup] [${MOD_VERSION}] Starting gateway..."
exec openclaw gateway --port 18789 --bind lan --allow-unconfigured --verbose
