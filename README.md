# OpenClaw KaanAssist Mod

Sith-style AI agent for Lord Kaan's construction + PMS + condo operations in Las Terrenas, DR.

Same architecture as `openclaw-kaan-mod` (Retena dev bot), different personality + skills + MCP config.

---

## What this container provides

- OpenClaw gateway (port 18789)
- **Smart router (port 18792)** — same one from Retena bot: routes to `codexlb.voz-clara.com/v1`, defaults to gpt-5.4 (BIG), downgrades to mini for heartbeats/simple queries, auto-retries on stream failures
- Node 24 + Go 1.23 runtime
- Codex CLI + OpenClaude (optional)
- Notion MCP server (@notionhq/notion-mcp-server)
- Workspace skeleton: SOUL, USER, AGENTS, MEMORY, HEARTBEAT + 2 subagent contexts (Contador, Capataz)

## What you need to add locally (before first push)

The container skeleton is ~2MB. Your existing skills/scripts are >100MB.
**Drop these into `workspace/app/skills/` and `workspace/skills/` locally before pushing:**

```
workspace/
├── app/skills/
│   ├── notion/              ← quick-add.js, maintenance-log.js, todo-costo.js, prestamos.js, reimbursement-report.js, weekly-financial.js, etc.
│   ├── kdrive/              ← upload scripts
│   ├── pms/                 ← pms-bridge.js, share-invoice.js, backup-pms.js
│   ├── todoist/             ← get-today-tasks.js, reschedule-today-to-tomorrow.js
│   ├── bamboojam/           ← Bamboojam Google Sheets scripts
│   ├── weather/             ← weather watch scripts
│   └── morning-briefing/    ← morning-briefing.js
└── skills/                  ← SKILL.md files
    ├── expense/SKILL.md
    ├── pull-skills/SKILL.md
    └── condo-manager-os/SKILL.md
```

The `startup.sh` script automatically seeds these from the Docker image into `/root/.openclaw/` at container boot.

---

## Deployment to Zeabur

### 1. Create GitHub repo
```bash
# Locally
cd openclaw-kaanassist-mod
git init
git branch -M main
git remote add origin https://github.com/Djeyff/openclaw-kaanassist-mod.git

# Drop your workspace/app/skills/ and workspace/skills/ here first
# Then:
git add -A
git commit -m "v1: initial KaanAssist mod"
git push -u origin main
```

### 2. Wait for GH Actions build (~5-8 min)
Image will be at `ghcr.io/djeyff/openclaw-kaanassist-mod:latest`.

### 3. Create Zeabur service (separate from Retena services)
- New service → Docker image
- Image: `ghcr.io/djeyff/openclaw-kaanassist-mod:latest`
- Port: 18789
- Volume: `/root/.openclaw` (persistence)

### 4. Set environment variables on Zeabur

#### REQUIRED (codexlb routing)
```
TELEGRAM_BOT_TOKEN=8568392325:AAFjaAdIqPScRsVinFR8hckvm0x8SaXGMGk
CODEX_LB_API_KEY=<your codexlb key>
NOTION_TOKEN=secret_...
```

#### Optional smart router tuning
```
SMART_ROUTER_UPSTREAM=https://codexlb.voz-clara.com/v1    (default)
SMART_ROUTER_BIG=gpt-5.4                                   (default)
SMART_ROUTER_MINI=gpt-5.4-mini                             (default)
OPENAI_MODEL=gpt-5.4                                       (default big)
```

#### Cron / fallback models (optional)
```
GROQ_API_KEY=gsk_...
CEREBRAS_API_KEY=csk-...
GEMINI_API_KEY=AIza...       (for web search)
```

#### Construction / PMS / kDrive
```
KDRIVE_TOKEN=...
SUPABASE_PMS_URL=https://tsfswvmwkfairaoccfqa.supabase.co
SUPABASE_PMS_SERVICE_KEY=...
```

#### Optional integrations
```
TODOIST_API_TOKEN=...
GOOGLE_SHEETS_SA_KEY_JSON={"type":"service_account",...}   (full JSON as string)
```

### 5. Start the service

Watch the logs for:
```
╔══════════════════════════════════════════════════════════════╗
║  OpenClaw KaanAssist Mod  [v1-2026-04-10]                    ║
╚══════════════════════════════════════════════════════════════╝
[startup] Seeding volume from /opt/openclaw-seed...
  ✓ openclaw.json seeded
  ✓ workspace docs updated
  ✓ scripts updated
[startup] .env written (XX vars)
[startup] [v1-2026-04-10] Starting gateway...
[gateway] ready
[telegram] starting provider
```

### 6. Test the bot

Send a message to your new Telegram bot. You should get a Sith-style reply ending with ⚡.

---

## File layout

```
openclaw-kaanassist-mod/
├── Dockerfile                    # Node 24 + Go + OpenClaw + Codex CLI
├── openclaw.json                 # codexlb (GPT 5.4) via smart router, Groq/Cerebras fallback
├── scripts/
│   └── startup.sh               # Seed + validate + launch gateway
├── workspace/
│   ├── SOUL.md                  # Sith-style personality
│   ├── USER.md                  # About Lord Kaan
│   ├── AGENTS.md                # CONTADOR + CAPATAZ routing rules
│   ├── MEMORY.md                # Construction doctrine, DB IDs, tenants
│   ├── HEARTBEAT.md             # Heartbeat instructions
│   ├── agents/
│   │   ├── contador/CONTEXT.md  # Expense/invoice subagent
│   │   └── capataz/CONTEXT.md   # Timesheet/maintenance subagent
│   ├── skills/                  # [YOU ADD] SKILL.md files
│   └── app/skills/              # [YOU ADD] Notion/kDrive/PMS/Todoist scripts
└── .github/workflows/
    └── build-docker-image.yaml  # Builds to ghcr.io on push to main
```

---

## Critical gotchas (learned from Retena bot)

1. **NEVER set `plugins.allow` in openclaw.json** — it acts as an allowlist for ALL plugins including Telegram and kills them (Issue #57219). Current config has `entries: {}` with NO `allow` key.

2. **Volume mount wipes COPY'd files** — `/root/.openclaw` is a Zeabur volume that clobbers Docker COPY. Solution: stage in `/opt/openclaw-seed/`, copy at boot via `startup.sh`.

3. **OpenClaw sanitizes subprocess env** — scripts spawned by agents don't inherit container env vars. Solution: `startup.sh` dumps all env to `/root/.openclaw/.env` and `workspace/memory/credentials.env` (chmod 600).

4. **Notion MCP format** — this MCP uses standard Notion API with `database_id`, NOT `collection://data_source_id`. Writes: `notion-create-pages` with `parent.database_id`.

5. **Memory plugin disabled** — needs OpenAI embeddings API key we don't use. Set `plugins.slots.memory = "none"`.

6. **Port** — OpenClaw listens on 18789. Set `PORT=18789` on Zeabur if needed, or just expose that port.

---

## Updating skills

After deployment, skills live in `/root/.openclaw/skills/` (persisted in volume). You can:

1. **Edit in Notion** (if using pull-skills skill) → bot pulls with "pull skills" command
2. **Push updated container** — startup.sh always overwrites from `/opt/openclaw-seed/workspace/skills/` on boot, so new image = new skills
3. **Edit directly in container** via Zeabur command tab (fast iteration, not persisted on rebuild)

---

## Version

**v1-2026-04-10** — initial release, forked from openclaw-kaan-mod v34 architecture
