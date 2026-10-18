# Dashboard spec — Metabase port of the Power BI flagship

Three dashboards mirroring the flagship pages. Save each question from `questions/` with the exact name in its header, then assemble per this spec. Reference visuals: the flagship screenshots in `../full-funnel/assets/`.

> **Loaded state (2026-10-18, rev2 — post visual review):** the suite is live — collection **Full-Funnel Suite**, dashboards at `/dashboard/2` (Executive), `/dashboard/3` (Retention), `/dashboard/4` (Audit). Deployed and verified via `automation/deploy_suite.py` (idempotent). v0.64 platform notes from the review fixes: text cards store `visualization_settings.virtual_card` (the frontend merges it into the card on load — without it the card renders empty); `02` is filtered to rows 1–5 for the bar visual (row 6 documented in the card description); the Audit page pins a dedicated **`08 … (table)` twin** (the v0.64 per-dashcard display override needs visualizer `columnValuesMapping` state, so a twin card is the robust route); `01` hides `sort_order` via `table.columns`; every dashboard has the provenance description + title text card.
>
> **Rev3 (2026-10-18, second review round):** the `04` pivot had been stored with **JSON-stringified** split refs, which the frontend treats as plain column *names* and silently drops — split entries must be **raw ref arrays** (`[["field","cohort",null]]`, `[["field","cohort_month_index",null]]`, `[["aggregation",0]]`). The `08 (table)` twin hides `sort_order` (same `table.columns` pattern as `01`). All three dashboards render-verified with headless Edge screenshots (temporary public links, removed after).
>
> **Rev4 (2026-10-18, third review round — the 6 fix areas):** scrollbar/emptiness sweep + formatting polish, all render-verified with headless Edge (public links again temporary, removed).
> * **`04` is no longer a pivot.** The v0.64 pivot enforces a wide fixed minimum cell width, so months 10–12 could never fit 24 grid units (a render showed headers stopping at `9`). `04` is now a **wide native table** — one result column per month (`month_0 … month_12`) — with the heatmap from `table.column_formatting` (robust-formatting "range") on a fixed **0–15** domain applied to months **1–12** only (month 0 is 100% by construction and stays plain). The legacy model card is archived; `deploy_suite.py` converts the existing `04` card in place (same title → same card id → dashcards survive).
> * **Ratios render `4.20x` / `3.30x`** via native number formatting (`{"decimals": 2, "suffix": "x"}`) on `03` / `12` / `08 (table)`; `01` pre-formats in SQL.
> * **Currency renders in every cell** (`$6,000,211.80`): v0.64's `currency_in_header` defaults to TRUE (symbol in the header only) — the suite pins it `false` on all money columns.
> * **Chart legends are humanized via SQL aliases** — viz `column_title` styles tables only, so series names come from the query (`Net revenue` / `Ad spend` on `10`; `Repeat rate` / `Store baseline` on `07`; `11` went back to a **DATE** `cohort` because string categories suppress x-axis labels). **BigQuery alias restriction:** parens/percent chars bomb the card (`Invalid field name` surfaces as "problem displaying this chart") — plain words + spaces only.
> * **`10` is now monthly** (24 rows, Sep 2024 → Aug 2026); `graph.show_values` on `02`/`06`/`08`; cleaned axis titles; a top **KPI strip of 6 equal-width scalar tiles** on the Executive page (the LTV tile shows `$1,120` — exact `$1,120.08` lives in `01`).
> * **Sizes re-tuned against renders** (no scrollbars): text 24×3; KPI 4/4/4/4/4/4 ×3 (v0.64 scalar tiles size their value font by tile width: any 3u tile shrinks and drops its caption, and the 2-decimal `$1,120.08` clipped at 4u — so the LTV tile displays `$1,120` at 0 decimals, letting all six sit equal at 4u in full size; verified with 3× crops); `01` 24×17; `04` 24×22; `09` 24×8 (the extra unit clears the audit table's in-card scrollbar); `12` 24×6; `08 (table)` 24×5. SQL **Total rows** on `09` (12,000 / 11,718 / $6,385,333.39 / $146,198.45 / $6,181,499.29) and `12` (11,718 / $6,252,668.43 / $71,169.14 / $6,181,499.29 / $1,488,730.67 / 4.15x) — plain tables still have no totals in v0.64, so they are computed in SQL and ordered last.

**Global to-dos**

- Every dashboard **description** gets the provenance line (see `setup.md` §Provenance).
- Add a **text card at the top** of each dashboard: title + `Synthetic demonstration data — see README`.
- Column formatting: currency → `$ #,##0.00` (in cells — `currency_in_header: false`); ratios → `4.20x`; percents → 1 decimal. Question `01` is pre-formatted in SQL; others return raw numerics for Metabase to format.
- Question **09/12**: v0.64 has **no totals setting for plain tables** (pivot-only: `pivot.show_row_totals` / `pivot.show_column_totals`) — the Total rows are **computed in SQL** (UNION ALL, ordered last) and the KPI strip carries the headline scalars.

---

## Dashboard 1 — Full-Funnel Executive

| Row | Question | Visualization | Notes |
| --- | --- | --- | --- |
| 0 | KPI strip — 6 scalar tiles (`questions/kpi/*.sql`) | Scalar | GMV $6.25M · Net Revenue $6.18M · Ad Spend $1.49M · Gross MER 4.20x · Blended CAC $299.42 · 12-mo LTV **$1,120** (tile, 0 decimal; exact `$1,120.08` in `01`) |
| 1 | 01 Executive KPIs | Table (hide `sort_order`) | 17 rows; the KPI strip |
| 2 (left, wide) | 02 Session Funnel | Bar (horizontal) or Funnel | Rows 1–5 for the visual; row 6 is the grain-audit proof (see file comment) |
| 2 (right) | 08 Three-Way Reconciliation | Bar: `ratio_vs_spend` by `source` | 1.39 claimed vs 1.10 last-click vs 4.15 net MER — use the `note` column in the tooltip/table toggle |
| 3 | 03 Campaign Unit Economics | Table | Sort `net_revenue` desc; the Organic/Internal rows show $0 spend by design |
| 4 | 10 Monthly Net Revenue & Ad Spend | Line: `Net revenue` + `Ad spend` | 24 months (Sep 2024 – Aug 2026); legend names come from SQL aliases |

**Numbers to eyeball:** GMV $6,252,668.43 · Net $6,181,499.29 · 11,718 orders · 4,972 customers · step rates 31.5/10.8/52.8/46.6%.

## Dashboard 2 — Retention & Cohort LTV

| Row | Question | Visualization | Notes |
| --- | --- | --- | --- |
| 1 | 04 Cohort Retention Matrix | Wide table: `cohort` + `month_0 … month_12` | 24 cohorts × 0–12; heatmap = conditional formatting (fixed 0–15) on months 1–12; month 0 = 100% by construction |
| 2 (left) | 05 Cumulative LTV Curve | Line: `cohort_month_index` → `cumulative_ltv_per_customer` | Ends at $1,120.08 (mature cohorts, 3,638 customers) |
| 2 (right) | 11 Cohort Sizes | Bar: `new_customers` by `cohort` (DATE axis) | 24 bars summing to 4,972 |
| 3 (left) | 06 Customer Tier Mix | Bar: `customers` by `customer_order_tier` | 1,516 / 1,544 / 1,912; store repeat share 87.3% in tooltip |
| 3 (right) | 07 Gateway SKU Test | Bar: `Repeat rate` by `first_sku`, + `Store baseline` second series | **Documented null result** — correlation only, alphabetical-min first_sku, no winner |

**Numbers to eyeball:** 69.5% repeat rate · LTV $1,120.08 · SKUs 73.3% → 65.5% around the 69.5% baseline.

## Dashboard 3 — Reconciliation & Audit Appendix

| Row | Question | Visualization | Notes |
| --- | --- | --- | --- |
| 1 | 09 Order-Status Walk | Table | 12,000 → 282 excluded → 11,718; SQL Total row: $6,385,333.39 − $146,198.45 = $6,181,499.29 |
| 2 | 12 Channel Walk | Table | Internal/Organic/Paid; nets $232,459.32 / $4,312,575.76 / $1,636,464.21; SQL Total row closes paid at 4.15x |
| 3 | 08 Three-Way Reconciliation (table) | Table | Dedicated twin card of question 08 (the bar version stays on Dashboard 1) |

---

## Suggested Metabase ecosystem bits (portfolio extras)

- **Models**: none in the current suite. History: `04` briefly used a companion model + query-builder pivot pair — the v0.64 pivot's fixed minimum cell width could not fit months 10–12 into 24 grid units, so it was replaced by the wide-table + conditional-formatting approach (rev4). The general pattern (save hand-written SQL as a model when a query-builder feature needs it) still applies.
- **Screenshots**: export each dashboard (PNG) for the eventual portfolio README — same discipline as the Power BI page exports. Captured 2026-10-18 via headless Edge into `assets/` (`dashboard1_executive.png`, `dashboard2_retention_cohorts.png`, `dashboard3_reconciliation_audit.png`), re-captured after rev4.
- **Ordering**: pin Board/Story-style from Dashboard 1 → 2 → 3 to walk a reviewer through the same narrative as the flagship (Executive → Retention → Audit).

## Follow-on (next milestone, parked)

**Looker Studio refresh (2-day bound)** — re-point the existing Looker report at this warehouse and redo the Cartify fixes; keep it minimal per the §8 platform decision.
