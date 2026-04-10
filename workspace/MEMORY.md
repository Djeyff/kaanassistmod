# MEMORY.md — Long-term Curated Memory

This is KaanAssist's permanent knowledge base. Read at every session start.

---

## CONSTRUCTION OS — NOTION

### Notion Data Source (MCP)
- **Construction OS data source:** `025b7c90-4c3f-46ad-bbf2-cce3c32c0b95`
  - Used for `notion-create-pages` MCP calls
  - Parent format: `{"database_id": "b5cb4b86-9980-4935-a4e9-5c834de8ce41"}` (standard Notion API)

### Core Database IDs

| Database | ID |
|---|---|
| Expenses | `b5cb4b86-9980-4935-a4e9-5c834de8ce41` |
| Timesheets | `0aa7fab9-a129-4e44-9e5f-7b85553076c3` |
| People (employees) | `231836394456409b9804a35425eaa3ed` |
| Projects | `e375ef6a3855483ab4368bd7d0038375` |
| Clients | `9cd8eec6cdd44feda5dd2520c1d0a4c6` |
| Material Loans | `31300b56-b6fa-8100-8915-c864ad90367e` |
| Proyectos (Todo Costo) | `30d00b56-b6fa-8111-9a9f-f20a039fbb58` |
| Avances (Todo Costo) | `30d00b56-b6fa-8185-8cdc-c5d3521f36a6` |
| Retena Ops Board | `32b00b56-b6fa-81a2-a4a6-c4d3c01bf6e0` |
| Maintenance Plantas | `30e00b56-b6fa-81cd-8928-ec084b881692` |
| Maintenance Camioneta | `30e00b56-b6fa-817e-a638-f2f7c080c068` |
| Framboyant parent | `30e00b56-b6fa-8154-b553-ccfa094a8fef` |

### Clients (EXACT names — case-sensitive)
- `CaseDamare` (NOT CasaDamare)
- `SportingClub LT`
- `Odalys` (client — different from Odalys the worker)

### Active Projects
- CaseDamare Remodelación (main ongoing, 2026)
- SportingClub LT (maintenance + inline works)
- CoralStone / Filtros (CoralStone 1/1C/3F/4F)
- Casa de Simone (CaseDamare)
- StreetPlaza (CaseDamare)
- Banquito 1 - SportingClub LT

### Project Name → Notion search shortcuts
- "filtros" → "Filtros CoralStone 3"
- "streetplaza" / "sp" → "StreetPlaza"
- "banquito" → "Banquito 1 - SportingClub LT"
- "coralstone 1" / "1c" → "CoralStone 1 - 1C"
- "sporting" / "sc" → "SportingClub"
- "coralstone" alone → ASK which unit
- "remodelacion" → "CaseDamare Remodelación"

### Employee IDs (Notion)

| Employee | ID | Rate |
|---|---|---|
| Jean | `30a00b56-b6fa-8163-a102-c811e64643fe` | 200 DOP/hr |
| Odalys (worker) | `30a00b56-b6fa-810f-8f93-dd92429cfc95` | — |
| Ayudante 1 | `30a00b56-b6fa-8179-810a-e2003bc04d9f` | — |
| Ayudante 2 | `30a00b56-b6fa-814c-915e-d5936a464805` | — |
| Ayudante 3 | `30a00b56-b6fa-8190-b7f8-cd765bb99645` | — |
| Pala (equipment) | `30d00b56-b6fa-818b-bcc4-f40bd1e28dd9` | — |

**1 day = 7.5 hours = 1500 DOP** when "a day" is said without specifying hours.
**Note:** Two Odalys exist — the CLIENT and the WORKER. Always clarify.

### 12 Valid Expense Categories
1. Materials
2. Labor
3. Subcontract
4. Equipment
5. Tools
6. Fuel
7. Food/Meals
8. Transport
9. Supplies
10. Services
11. Permit
12. Other

**NEVER use a 13th value. NEVER use client/project name as Category.**

### Expense Status Rules
- **Cash / Contado / Tarjeta** → `Pending Reimbursement`
- **A Crédito / a 15 dias / a 30 dias** → `Para Contador`

### Contador Assignment (for "A Crédito" expenses)
- CaseDamare → Contador **Max**
- SportingClub LT → Contador **Lisa**
- Unknown → ASK

---

## KDRIVE (FILE STORAGE)

- **Provider:** Infomaniak kDrive
- **Drive ID:** `1795364`
- **Root folder:** `KaanAssist` (ID: 65355)
- **Token env var:** `KDRIVE_TOKEN`

### Folder IDs (key ones)

| Path | ID |
|---|---|
| KaanAssist (root) | 65355 |
| Proyectos/CaseDamare | 65745 |
| Proyectos/CaseDamare/Remodelacion/2026/03 - Marzo | 69298 |
| Proyectos/CaseDamare/StreetPlaza/Facturas | 66152 |
| Proyectos/SportingClub LT/Banquito SportingClub/Facturas | 66149 |
| Proyectos/SportingClub LT/SportingClub/Facturas | 66156 |
| Proyectos/CaseDamare/CoralStone 3/Filtros | 67394 |
| Proyectos/CaseDamare/Casa de Simone/Facturas | 67660 |
| PMS-Invoices | 69753 |

### Filename conventions
- Cash: `factura-[vendor-slug]-[invoice#]-[YYYY-MM-DD].jpg`
- Credit: `acredito-[vendor-slug]-[invoice#]-[YYYY-MM-DD].jpg`

### Rules
- **NEVER use `Recibos-Gastos` folder (65356)** — OBSOLETE
- Every expense = Notion entry + kDrive photo (both always)
- kDrive has no move API — upload to correct folder from start

---

## PMS — PROPERTY MANAGEMENT SYSTEM (Gael's rent)

- **URL:** `https://tsfswvmwkfairaoccfqa.supabase.co`
- **Auth:** `SUPABASE_PMS_SERVICE_KEY` env var
- **Web portal:** https://pms-web-dusky.vercel.app
- **Admin PIN:** `010190` (Jeff/admin)
- **Owner PIN:** `010326` (Gael, read-only)

### Tenants (current)

| Tenant | Business | Rent | Currency |
|---|---|---|---|
| Mario Martinez | RentACar | 300 | USD |
| Eric | Banca Erick | 250 | USD |
| Juan Pablo Bueno De Leon | Bar Juan Pablo | 700 | USD |
| Neyli | Colmado Neyli | 275 | USD |
| Joaquim Chauvaud | Ebanesteria ProJo | 1,155 | USD |
| Nicasio | Banca Nicasio | 175 | USD |
| Luis Coson | (local) | 35,000 | DOP |
| William & Sonia | Le Jardin | 500 | USD |

### Special Rules (CRITICAL)
- **Luis Coson** (ID: `7306d35a`): pays trimester in advance — **NEVER flag as overdue**
- **William & Sonia**: 5+ months overdue — **NO reminders ever** (owner decision, hardcoded exclusion)
- **NEVER mix DOP + USD in totals** — always separate currencies
- **Management fee formula:** `(USD × avg_rate + DOP) × 5%`

---

## BAMBOOJAM VILLA (Sylvie co-ownership)

- **Google Sheet:** https://docs.google.com/spreadsheets/d/1Zom5Guy8fMYYobdRx8QeZU39uHMA7RjT814MYFwXlgs/edit
- **Service account:** `clawsheets@kaanassist.iam.gserviceaccount.com`
- **Sheet tabs:**
  - Dépenses (GID: 1115874758): A=Date (DD.MM), B=Description, F=Total (DOP)
  - Revenus (4626204)
  - Repartition (1451386057)
  - Hors des comptes (826089223)
  - Travaux (583659143)
- **Insert rule:** Always add rows **BEFORE** the "Total" row

Expenses logged to BOTH Google Sheets AND Notion Bamboojam OS.

---

## FRAMBOYANT CONDO

- **Parent Notion page:** `30e00b56-b6fa-8154-b553-ccfa094a8fef`
- **Skill:** `~/.openclaw/skills/condo-manager-os/`
- **Key DBs** (prefix `30e00b56-b6fa-` or `30f00b56-b6fa-`):
  - Units: `81e0` | Ledger: `8102` | Budget: `81aa` | Expenses: `819f`
  - Maintenance: `8169` | Works: `8110` | Cash: `8172`
  - Comms: `817e` | Meetings: `8186` | Movements: `818f`
  - Votes: `81c5` | Financial: `8127`

### Owner list
- A-1 Guérin (active legal dispute, overdue)
- A-2 Métayer/Jean
- A-3 Ondella
- A-4 Facquet
- A-5 Enger
- A-6 Inversiones Ter 187/Santos
- A-7 Hazeltine

### Email template for Framboyant
HTML template established: blue header `#2a5c8f`, 640px centered table on `#f4f4f4`, Arial 15px, blue left-border section titles, orange `#e67e22` blockquotes for citations, red `#c0392b` for threats/legal warnings, green `#27ae60` for third-party responses, grey footer.

**Signature:**
```
Jeffrey Hubert
Administrador
Las Terrenas Properties
+1 809 204 4903
www.lasterrenas.properties
```

**Website always `www.lasterrenas.properties`** (never `www.lti.do`).
**Accountant:** Yunairy Encarnacion (FINACC ENCARNACION S.R.L.)
**Lawyer:** Lic. Dionis F. Tejada Pimentel

---

## CRON JOBS (Automated Reports)

- **Expected count:** 26 active crons
- **Check with:** `openclaw cron list`
- **Model for reports:** `groq/llama-3.3-70b-versatile` (free, fast)
- **Model for simple tasks:** `cerebras/llama3.1-8b` (free, ultra-fast)

### Cron Delivery Rules
- Reports/alerts → `delivery.mode: announce` → Telegram 7707300903
- Backups/syncs → `delivery.mode: none` (silent)
- **CRON REPORTS ARE ALWAYS NO_REPLY** — never relay a cron report confirmation to Lord Kaan

---

## MODELS

| Use case | Model |
|---|---|
| Default main session | `anthropic/claude-sonnet-4-6` |
| Subagent (Contador/Capataz) | `anthropic/claude-haiku-4-5` |
| Cron reports/briefings | `groq/llama-3.3-70b-versatile` (free) |
| Cron simple tasks | `cerebras/llama3.1-8b` (free) |
| Fallback chain | groq/llama-3.3-70b → cerebras/llama-3.3-70b |

---

## INLINE BUTTONS (Telegram)

| Button | Action |
|---|---|
| `pms_receipt_last` | Fetch latest PMS payment, generate PDF, send |
| `quick_timesheet` | Ask: "¿Quién, cuántas horas, qué tarea, qué proyecto?" |
| `quick_expense` | Ask: "Manda foto o dime: descripción, monto, proyecto" |
| `quick_advance` | Ask: "¿Proyecto, monto, descripción?" |
| `quick_maintenance` | Ask: "¿Qué equipo? (Simone / SportingClub / Camioneta / Gasolina)" |
| `quick_day_summary` | Run `daily-eod-report.js` |
| `quick_reimbursements` | Run `reimbursement-report.js` |

---

## DAILY BOOT CHECKLIST

1. Read `SOUL.md` (personality)
2. Read `USER.md` (about Lord Kaan)
3. Read `MEMORY.md` (this file)
4. Read `memory/YYYY-MM-DD.md` if exists (today's notes)
5. Source `/root/.openclaw/.env` before any script
6. Check for pending subagent tasks in Notion Ops Board

---

*End of MEMORY.md*
