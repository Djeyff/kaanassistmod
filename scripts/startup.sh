#!/usr/bin/env bash
set -euo pipefail

MOD_VERSION="v1-2026-04-10"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  OpenClaw KaanAssist Mod  [${MOD_VERSION}]                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# ── 1. Seed volume from staged files ────────────────────────────
echo "[startup] Seeding volume from /opt/openclaw-seed..."
mkdir -p /root/.openclaw/workspace/skills
mkdir -p /root/.openclaw/workspace/app/skills
mkdir -p /root/.openclaw/workspace/agents/contador
mkdir -p /root/.openclaw/workspace/agents/capataz
mkdir -p /root/.openclaw/workspace/memory/logs
mkdir -p /root/.openclaw/workspace/scripts
mkdir -p /root/.openclaw/workspace/secrets
mkdir -p /root/.openclaw/credentials
mkdir -p /root/.openclaw/sessions
mkdir -p /root/.openclaw/state

# Always overwrite config (ensures latest version)
cp -f /opt/openclaw-seed/openclaw.json /root/.openclaw/openclaw.json
echo "  ✓ openclaw.json seeded"

# Seed workspace: always update .md docs (latest from image)
for f in /opt/openclaw-seed/workspace/*.md; do
    [ -f "$f" ] && cp -f "$f" /root/.openclaw/workspace/ 2>/dev/null || true
done
echo "  ✓ workspace docs updated (latest from image)"

# Always update subagent contexts
if [ -d /opt/openclaw-seed/workspace/agents ]; then
    cp -rf /opt/openclaw-seed/workspace/agents/* /root/.openclaw/workspace/agents/ 2>/dev/null || true
    echo "  ✓ agent contexts updated"
fi

# Skills: always copy (skill updates via image push)
if [ -d /opt/openclaw-seed/workspace/skills ]; then
    cp -rf /opt/openclaw-seed/workspace/skills/* /root/.openclaw/workspace/skills/ 2>/dev/null || true
    echo "  ✓ skills updated"
fi

# App scripts: always copy (your Notion/PMS/kDrive/Todoist/Bamboojam scripts)
if [ -d /opt/openclaw-seed/workspace/app ]; then
    cp -rf /opt/openclaw-seed/workspace/app/* /root/.openclaw/workspace/app/ 2>/dev/null || true
    echo "  ✓ app scripts updated"
fi

# Copy scripts (smart router, etc.) always
cp -rf /opt/openclaw-seed/scripts/* /root/.openclaw/workspace/scripts/ 2>/dev/null || true
chmod +x /root/.openclaw/workspace/scripts/*.sh /root/.openclaw/workspace/scripts/*.js 2>/dev/null || true
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
[ -z "${NOTION_TOKEN:-}" ] && echo "[startup] WARNING: NOTION_TOKEN not set"
[ -z "${KDRIVE_TOKEN:-}" ] && echo "[startup] WARNING: KDRIVE_TOKEN not set (expense uploads will fail)"
[ -z "${SUPABASE_PMS_SERVICE_KEY:-}" ] && echo "[startup] WARNING: SUPABASE_PMS_SERVICE_KEY not set (PMS will fail)"

if [ -n "$MISSING" ]; then
    echo "[startup] FATAL: Missing:${MISSING}"
    exit 1
fi
echo "[startup] Environment OK."

# ── 5. Write .env for agent exec subprocess access ──────────────
# OpenClaw sanitizes subprocess env — dump all container env vars to .env
# so agent-spawned scripts (quick-add.js, pms-bridge.js, etc.) can source them
echo "[startup] Writing .env for agent subprocess access..."

# System vars to exclude (standard Linux/Node/Docker internals)
EXCLUDE="^(PATH|HOME|HOSTNAME|TERM|SHLVL|PWD|OLDPWD|SHELL|USER|LOGNAME|LANG|LC_|NODE_ENV|NODE_OPTIONS|NODE_PATH|NPM_|COREPACK_|GOPATH|GO_|_=|DEBIAN_|KUBERNETES_|K8S_)"

env | grep -vE "$EXCLUDE" | sort > /root/.openclaw/.env

# Force-add codexlb routing vars (for Codex CLI subprocess calls)
{
  echo "CLAUDE_CODE_USE_OPENAI=1"
  echo "OPENAI_BASE_URL=http://127.0.0.1:18792/v1"
  echo "OPENAI_API_KEY=${CODEX_LB_API_KEY}"
  echo "OPENAI_MODEL=${OPENAI_MODEL:-gpt-5.4}"
  echo "ZEABUR_GRAPHQL_URL=https://api.zeabur.com/graphql"
} >> /root/.openclaw/.env

chmod 600 /root/.openclaw/.env
echo "  ✓ .env written ($(wc -l < /root/.openclaw/.env) vars)"

# Also copy to workspace/memory/credentials.env (legacy path used by handover scripts)
cp /root/.openclaw/.env /root/.openclaw/workspace/memory/credentials.env
chmod 600 /root/.openclaw/workspace/memory/credentials.env

# ── 6. Export OpenClaude/Codex vars ─────────────────────────────
export CLAUDE_CODE_USE_OPENAI=1
export OPENAI_BASE_URL="http://127.0.0.1:18792/v1"
export OPENAI_API_KEY="${CODEX_LB_API_KEY}"
export OPENAI_MODEL="${OPENAI_MODEL:-gpt-5.4}"
echo "[startup] codexlb → ${OPENAI_MODEL} (default big, smart router downgrades simple queries)"

# ── 7. Tool check ──────────────────────────────────────────────
echo "[startup] Tools:"
command -v go >/dev/null 2>&1 && echo "  ✓ Go $(go version | awk '{print $3}')" || echo "  ✗ Go"
command -v openclaw >/dev/null 2>&1 && echo "  ✓ OpenClaw" || echo "  ✗ OpenClaw"
command -v codex >/dev/null 2>&1 && echo "  ✓ Codex CLI" || echo "  ✗ Codex"
command -v openclaude >/dev/null 2>&1 && echo "  ✓ OpenClaude" || echo "  ⚠ OpenClaude (optional)"
echo ""

# ── 8. Verify config was written ───────────────────────────────
if grep -q "gateway" /root/.openclaw/openclaw.json 2>/dev/null; then
    echo "[startup] Config verified at /root/.openclaw/openclaw.json"
else
    echo "[startup] ERROR: Config missing or corrupt!"
fi

# ── 9. Auto-fix config issues ───────────────────────────────────
echo "[startup] Running openclaw doctor --fix..."
openclaw doctor --fix --yes 2>&1 | tail -5 || true
echo ""

# ── 10. Start smart router (model auto-routing) ────────────────
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

# ── 11. Start OpenViking memory server ─────────────────────────
echo "[startup] Configuring OpenViking memory..."
mkdir -p /root/.openviking/data

OV_PROVIDER="${OPENVIKING_EMBEDDING_PROVIDER:-gemini}"
OV_API_KEY="${OPENVIKING_EMBEDDING_API_KEY:-${GEMINI_API_KEY:-}}"
OV_MODEL="${OPENVIKING_EMBEDDING_MODEL:-gemini-embedding-2-preview}"
OV_DIMENSION="${OPENVIKING_EMBEDDING_DIMENSION:-3072}"
OV_GROQ_KEY="${GROQ_API_KEY:-}"

if [ -f /opt/openclaw-seed/openviking/ov.conf.template ]; then
    sed -e "s|__OPENVIKING_EMBEDDING_PROVIDER__|${OV_PROVIDER}|g" \
        -e "s|__OPENVIKING_EMBEDDING_API_KEY__|${OV_API_KEY}|g" \
        -e "s|__OPENVIKING_EMBEDDING_MODEL__|${OV_MODEL}|g" \
        -e "s|__OPENVIKING_EMBEDDING_DIMENSION__|${OV_DIMENSION}|g" \
        -e "s|__GROQ_API_KEY__|${OV_GROQ_KEY}|g" \
        /opt/openclaw-seed/openviking/ov.conf.template > /root/.openviking/ov.conf
    echo "  ✓ ov.conf generated (embed=${OV_PROVIDER}/${OV_MODEL}, vlm=groq/llama-3.3-70b)"
fi

if [ -n "$OV_API_KEY" ]; then
    if command -v openviking >/dev/null 2>&1; then
        openviking serve --config /root/.openviking/ov.conf &
        OV_PID=$!
        sleep 2
        if kill -0 $OV_PID 2>/dev/null; then
            echo "  ✓ OpenViking running (PID: $OV_PID, port 1933)"
        else
            echo "  ✗ OpenViking failed to start — falling back to file-based memory"
        fi
    else
        echo "  ⚠ OpenViking binary not found — trying ov-install..."
        ov-install --workdir /root/.openclaw 2>&1 | tail -3 || echo "  ✗ ov-install failed"
    fi
else
    echo "  ⚠ No GEMINI_API_KEY set — OpenViking disabled (no embedding provider)"
    echo "    Set GEMINI_API_KEY to enable (FREE Google AI Studio embeddings)"
fi

# ── 12. Start gateway ──────────────────────────────────────────
echo "[startup] [${MOD_VERSION}] Starting gateway..."
exec openclaw gateway --port 18789 --bind lan --allow-unconfigured --verbose
