# AGENTS.md — Agent Routing & Subagent Dispatch

## ARCHITECTURE

```
Lord Kaan (Telegram)
       ↓
   CEO Agent (main session = Sonnet 4.6)
    ├── Routes expense/invoice → CONTADOR subagent (Haiku 4.5)
    ├── Routes timesheet/maintenance → CAPATAZ subagent (Haiku 4.5)
    └── Handles PMS / Todoist / scheduling / Framboyant directly
```

## AGENT CONTEXTS

| Agent | Context file |
|---|---|
| CONTADOR | `/root/.openclaw/workspace/agents/contador/CONTEXT.md` |
| CAPATAZ | `/root/.openclaw/workspace/agents/capataz/CONTEXT.md` |

## ROUTING RULES

### Route → CONTADOR when:
- Invoice/receipt photo attached
- Keywords: `expense`, `gasto`, `factura`, `recibo`, `reimbursement`, `reembolso`, `a crédito`, `de contado`
- Client statement, estado de cuenta, weekly financial report
- Bamboojam expenses, Sylvie mentions
- Prestamo de material (material loans)
- Reimbursement reports, Para Contador status

### Route → CAPATAZ when:
- Keywords: `timesheet`, `horas`, `trabajó`, `día de trabajo`, `Jean`, `ayudante`, `Odalys trabajó`
- Maintenance: `mantenimiento`, `Simone`, `Camioneta`, `Gasolina`
- Project advance, `avance de proyecto`
- Buttons: `quick_timesheet`, `quick_maintenance`, `quick_advance`

### Route → BOTH when:
- Task spans accounting + construction (invoice + timesheet same project)
- Advance paid by Jeff (Capataz tracks advance, Contador handles reimbursement)

### CEO handles directly:
- PMS / property management (Gael's rent)
- Todoist / scheduling / reminders
- Condominio Framboyant (condo admin)
- General questions / conversation
- Cron reports (always NO_REPLY — never relay back to Lord Kaan)
- Workspace memory updates

## SPAWNING SUBAGENTS

```js
sessions_spawn({
  task: `[TASK from Lord Kaan]

CONTEXT: [relevant facts]

---
[paste CONTEXT.md content of target subagent]`,
  runtime: "subagent",
  mode: "run",
  model: "anthropic/claude-haiku-4-5"
})
```

**NEVER use `ollama/*` in sessions_spawn** — it fails silently.

## NOTION MCP USAGE

The Notion MCP server (`@notionhq/notion-mcp-server`) uses **standard Notion API** with `database_id` format:

```json
{"database_id": "b5cb4b86-9980-4935-a4e9-5c834de8ce41"}
```

**DO NOT use `data_source_id` or `collection://` format** — those are for a different connector. This MCP uses `database_id`.

For writes, use `notion-create-pages` with `parent.database_id`.

## MISSION MODE (for multi-step tasks)

When Lord Kaan assigns a task requiring 5+ steps, enter mission mode:

1. Write mission file to `/root/.openclaw/workspace/memory/missions/YYYY-MM-DD-slug.md`
2. List all steps with checkboxes
3. Execute each step, updating the file after completion
4. Run `/compact` after every 2 completed steps
5. When all done: commit+push, update MISSION.md, `/compact`, `/new`

## SESSION ROTATION

**You CAN and SHOULD run `/compact` and `/new` yourself.** No permission needed.

### Triggers for immediate `/compact`:
- `toolResult:40+` in context
- `tokenCount > 100000`
- `messages > 100`
- After completing any major task

### Always BEFORE `/compact`:
- Commit + push any code changes
- Write summary to `memory/YYYY-MM-DD.md`

### Auto-compact layer (openclaw.json)
Forced compaction at 65% context window. Last resort.

## CRITICAL RULES (from HANDOVER)

1. **NEVER mental math for financials** — always run scripts
2. **NEVER use today's date** when receipt has its own date
3. **NEVER put client/project name in Category field** — only 12 valid values
4. **NEVER amount = 0** in expenses
5. **NEVER pass hours as amount** for timesheets — always convert (hours × 200 DOP)
6. **NEVER bulk update Zeabur env vars** — GET all first, merge, then update complete set
7. **NEVER start Aladdin daemon** (stays OFF — causes too many Vercel deploys)
8. **NEVER use `ollama/*` in sessions_spawn** — fails silently
9. **Reimbursed ≠ Paid:** `Status=Reimbursed` = client paid Jeff back; `Employee payment=Paid` = Jeff paid worker
10. **Luis Coson pays trimester in advance** — never flag overdue
11. **William & Sonia** — no reminders, ever (owner decision)
12. **No markdown tables on Telegram** — plain text only
13. **Secrets never in replies** — always `[REDACTED]`
