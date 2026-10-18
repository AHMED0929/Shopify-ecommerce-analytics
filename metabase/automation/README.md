# Suite automation

`deploy_suite.py` loads the whole Metabase port with one command: it creates the
`Full-Funnel Suite` collection, saves all 12 questions from `../questions/`
(with the visualizations the spec asks for), creates the derived objects the
v0.64 platform needs — the six **KPI scalar tiles** (`../questions/kpi/`) and the
`08 … (table)` **twin** for the audit page — creates the 3 dashboards,
lays out every card on the 24-column grid, and archives legacy objects left
behind by earlier deploy shapes — then prints a verification table.

It talks to the Metabase REST API directly (login → `/api/card` → `/api/dashboard`)
against the same BigQuery warehouse the Power BI flagship uses. **Idempotent**:
re-running updates existing objects instead of duplicating them. Why the derived
objects exist (v0.64 platform specifics) is documented in the script docstring
and in `../dashboard-spec.md` → "Loaded state".

Platform notes baked in: `04` ships as a **wide native table** (one column per
month) with a `table.column_formatting` heatmap — the v0.64 pivot's fixed minimum
cell width cannot fit 13 month columns into 24 grid units, so the earlier model +
pivot pair is retired (the model gets archived). Series/legend labels on charts
come from **SQL aliases** (viz `column_title` styles tables only) — and BigQuery
rejects aliases with parens/percent, so keep them to plain words. Currency shows
in every cell (`currency_in_header: false`; v0.64 defaults to symbol-in-header).
The `08 … (table)` twin hides `sort_order` via `table.columns`, same as `01`.

## Usage

```powershell
python deploy_suite.py
```

Optional environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `METABASE_URL` | `http://localhost:3000` | Metabase server |
| `METABASE_EMAIL` / `METABASE_PASSWORD` | — | admin credentials (takes precedence) |
| `METABASE_CRED_FILE` | `G:\Tools\metabase\ADMIN-CREDENTIALS.txt` | fallback credential file (`Email:` / `Password:` lines) |

## What it does not do

- It does not connect the BigQuery database — do that once per `../setup.md` §4.
- It does not screenshot dashboards (see `../dashboard-spec.md` → portfolio extras).

Requires only the Python standard library (uses `urllib`).
