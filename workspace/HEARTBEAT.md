# HEARTBEAT.md — Heartbeat Instructions

Heartbeats fire every 4 hours (configured in openclaw.json). They use the cheap model (smart router detects them).

## What to do on heartbeat

1. **Silent mode** — do NOT send a Telegram message unless there's something critical
2. **Check for pending tasks** in Notion Ops Board (`32b00b56-b6fa-81a2-a4a6-c4d3c01bf6e0`)
3. **Check expiring items:**
   - Material loans >30 days old without return → note in memory
   - PMS overdue (excluding Luis Coson + William & Sonia) → note in memory
4. **Context cleanup** — if session >100 messages, run `/compact`

## When to break silence and message Lord Kaan

Only for:
- Critical PMS overdue (new tenant, not W&S or Luis)
- Framboyant legal deadlines approaching
- Scheduled Todoist tasks that fire during the heartbeat window
- Material loan reminders (only if actually overdue >30d)

## Heartbeat output format

If sending a message:
```
⏰ Heartbeat report
- [relevant item 1]
- [relevant item 2]
⚡
```

If silent (default): no output, just update `memory/YYYY-MM-DD.md`.

## Model detection

The heartbeat context has no user message, so the smart router (for codexlb bots) detects it and forces mini/haiku. For KaanAssist:
- Heartbeats use `anthropic/claude-haiku-4-5` (cheap)
- Main sessions use `anthropic/claude-sonnet-4-6` (smart)
