# -*- coding: utf-8 -*-
"""Deploy the Full-Funnel Metabase suite: 12 questions + 1 table twin + 6 KPI tiles + 3 dashboards.

Reads the SQL from ../questions and ../questions/kpi and assembles the dashboards per
../dashboard-spec.md. Idempotent: creates what's missing, updates what exists. Safe to re-run.

Derived objects (v0.64 platform requirements, see dashboard-spec.md "loaded-state notes"):
  * 04 : wide native table (one result column per month index) + per-column heatmap via
         table.column_formatting (fixed 0-15 domain on months 1-12; month 0 is 100% by
         construction and stays plain). An earlier deploy shipped a model + query-builder pivot
         pair; the v0.64 pivot enforces a wide minimum cell width that clipped months 10-12 at
         24 grid units, so this deploy converts the existing 04 card in place (same title) and
         archives the legacy companion model.
  * 08 : second card "(table)" for the audit page; the v0.64 per-dashcard display override requires
         visualizer columnValuesMapping state, so a dedicated table card is used instead.
  * KPI strip: six scalar tiles (questions/kpi/*.sql) pinned above the Executive KPI table.
  * text cards store vs.virtual_card; the frontend merges it into the dashcard's card on load.
  * 10 was renamed to the monthly trend; PREV_TITLES finds the card by its old title on the first
         post-rename run and updates it in place (the card id survives, so dashcards stay linked).

Configuration (env vars, all optional):
  METABASE_URL         default http://localhost:3000
  METABASE_EMAIL       admin email
  METABASE_PASSWORD    admin password
  METABASE_CRED_FILE   file with `Email:` / `Password:` lines (fallback if env creds unset)

Usage:
  python deploy_suite.py
"""
import json
import os
import sys
import urllib.error
import urllib.request

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

BASE = os.environ.get("METABASE_URL", "http://localhost:3000").rstrip("/")
HERE = os.path.dirname(os.path.abspath(__file__))
QUESTIONS_DIR = os.path.normpath(os.path.join(HERE, "..", "questions"))
KPI_DIR = os.path.join(QUESTIONS_DIR, "kpi")
CRED_FILE = os.environ.get("METABASE_CRED_FILE", r"G:\Tools\metabase\ADMIN-CREDENTIALS.txt")
COLLECTION_NAME = "Full-Funnel Suite"

# Cards renamed since the first deploy: on the first run after a rename, look the card up by its
# old title and PUT it (the name changes in place, so pinned dashcards keep working).
PREV_TITLES = {"10": "10 \u00b7 Daily Full-Funnel Trend"}

PROV = ("Synthetic demonstration data \u2014 self-directed portfolio project. Orders are a "
        "synthetic Shopify export; GA4 funnel and ad-spend layers are simulated by a seeded "
        "generator (generate_funnel.py). Full provenance: github.com/AHMED0929/Shopify-ecommerce-analytics")

TEXT_CARD = ("### Full-Funnel Commerce Intelligence \u2014 Metabase port\n"
             "**Synthetic demonstration data** \u2014 self-directed portfolio project \u00b7 "
             "[README & provenance](https://github.com/AHMED0929/Shopify-ecommerce-analytics)")

# Virtual card descriptor the frontend expects for text cards (v0.64).
VC = {"name": None, "display": "text", "visualization_settings": {}, "archived": False}

# (kind, ref, row, col, size_x, size_y[, viz_override])  -- 24-column grid
LAYOUTS = {
    "Full-Funnel Executive": [
        ("text", None, 0, 0, 24, 3),
        ("card", "kpi_gmv", 3, 0, 4, 3),
        ("card", "kpi_net_revenue", 3, 4, 4, 3),
        ("card", "kpi_ad_spend", 3, 8, 4, 3),
        ("card", "kpi_gross_mer", 3, 12, 4, 3),
        ("card", "kpi_blended_cac", 3, 16, 4, 3),
        ("card", "kpi_ltv_12m", 3, 20, 4, 3),
        ("card", "01", 6, 0, 24, 17),
        ("card", "02", 23, 0, 14, 7),
        ("card", "08", 23, 14, 10, 7),
        ("card", "03", 30, 0, 24, 11),
        ("card", "10", 41, 0, 24, 7),
    ],
    "Retention & Cohort LTV": [
        ("text", None, 0, 0, 24, 3),
        ("card", "04", 3, 0, 24, 22),
        ("card", "05", 25, 0, 14, 7),
        ("card", "11", 25, 14, 10, 7),
        ("card", "06", 32, 0, 12, 6),
        ("card", "07", 32, 12, 12, 6),
    ],
    "Reconciliation & Audit Appendix": [
        ("text", None, 0, 0, 24, 3),
        ("card", "09", 3, 0, 24, 8),
        ("card", "12", 11, 0, 24, 6),
        ("card", "08t", 17, 0, 24, 5),
    ],
}

# Formatting helpers (v0.64 key facts, verified in the frontend bundle):
#   * column_settings keys are JSON.stringify'd refs; native and model columns answer to ["name",col].
#   * number formats support number_style/currency/currency_style/decimals/number_separators and
#     prefix/suffix ("Add a suffix") — ratios stay numeric and get a rendered "x".
#   * currency_in_header defaults to TRUE ("symbol in the column heading"); set False so money
#     cells carry the $ symbol themselves ("$6,000,211.80").
CUR = {"number_style": "currency", "currency": "USD", "currency_style": "symbol", "decimals": 2,
       "currency_in_header": False}
RATIO = {"decimals": 2, "suffix": "x"}


def colset(**cols):
    """viz column_settings keyed by column name."""
    return {"column_settings": {json.dumps(["name", c], separators=(",", ":")): v for c, v in cols.items()}}


# Plain-table totals do not exist in v0.64 (pivot-only settings); 01 hides sort_order via
# "table.columns" (entries matched by column name with an enabled flag).
CFG = {
    "01": {"display": "table", "vs": {"table.columns": [
        {"name": "metric", "enabled": True},
        {"name": "value", "enabled": True},
        {"name": "context", "enabled": True},
        {"name": "sort_order", "enabled": False},
    ]}},
    "02": {"display": "bar", "vs": {
        "graph.dimensions": ["step"], "graph.metrics": ["value"],
        "graph.show_values": True,
        "graph.x_axis.title_text": "Funnel stage",
        "graph.y_axis.title_text": "Sessions",
        **colset(value={"column_title": "Sessions"}),
    },
        "sql_replace": ("FROM steps\nORDER BY step_order;",
                        "FROM steps\nWHERE step_order <= 5\nORDER BY step_order;"),
        "desc": ("Visual shows the 5 session steps. Row 6 of the source SQL "
                 "(purchase orders \u2014 audit) documents the 585 session/order grain gap; "
                 "see 02_session_funnel.sql.")},
    "03": {"display": "table", "vs": colset(
        traffic_type={"column_title": "Traffic"},
        campaign_name={"column_title": "Campaign"},
        valid_orders={"column_title": "Orders"},
        gmv={"column_title": "GMV", **CUR},
        refunds={"column_title": "Refunds", **CUR},
        net_revenue={"column_title": "Net revenue", **CUR},
        ad_spend={"column_title": "Ad spend", **CUR},
        net_mer={"column_title": "Net MER", **RATIO},
        cpa={"column_title": "CPA", **CUR},
    )},
    "05": {"display": "line", "vs": {
        "graph.dimensions": ["cohort_month_index"],
        "graph.metrics": ["cumulative_ltv_per_customer"],
        "graph.x_axis.title_text": "Months since acquisition",
        "graph.y_axis.title_text": "Cumulative LTV per customer ($)",
        **colset(cumulative_ltv_per_customer={"column_title": "Cumulative LTV per customer", **CUR}),
    }},
    "06": {"display": "bar", "vs": {
        "graph.dimensions": ["customer_order_tier"], "graph.metrics": ["customers"],
        "graph.show_values": True,
        "graph.x_axis.title_text": "Order tier",
        "graph.y_axis.title_text": "Customers",
        **colset(customers={"column_title": "Customers"}),
    }},
    "07": {"display": "bar", "vs": {
        # Chart series/legend names come from the column names (column_title styles tables only),
        # so the metrics are humanized via SQL aliases in 07_gateway_sku_test.sql.
        "graph.dimensions": ["first_sku"], "graph.metrics": ["Repeat rate", "Store baseline"],
        "graph.x_axis.title_text": "First SKU",
        "graph.y_axis.title_text": "Repeat rate (%)",
    }},
    "08": {"display": "bar", "vs": {
        "graph.dimensions": ["source"], "graph.metrics": ["ratio_vs_spend"],
        "graph.show_values": True,
        "graph.x_axis.title_text": "Source",
        "graph.y_axis.title_text": "Ratio vs spend",
        **colset(ratio_vs_spend={"column_title": "Ratio vs spend", "decimals": 2}),
    }},
    "09": {"display": "table", "vs": colset(
        financial_status={"column_title": "Status"},
        raw_orders={"column_title": "Raw orders"},
        valid_orders={"column_title": "Valid orders"},
        gross_revenue={"column_title": "Gross revenue", **CUR},
        refunds={"column_title": "Refunds", **CUR},
        valid_net_revenue={"column_title": "Net revenue", **CUR},
    )},
    "10": {"display": "line", "vs": {
        # Series/legend names come from the SQL aliases (see 10_monthly_net_revenue_ad_spend.sql).
        "graph.dimensions": ["month"], "graph.metrics": ["Net revenue", "Ad spend"],
        "graph.x_axis.title_text": "Month",
        "graph.y_axis.title_text": "Net revenue & ad spend ($)",
        "column_settings": {
            json.dumps(["name", "Net revenue"], separators=(",", ":")): dict(CUR),
            json.dumps(["name", "Ad spend"], separators=(",", ":")): dict(CUR),
        },
    }},
    "11": {"display": "bar", "vs": {
        "graph.dimensions": ["cohort"], "graph.metrics": ["new_customers"],
        "graph.x_axis.title_text": "Cohort",
        "graph.y_axis.title_text": "New customers",
        **colset(new_customers={"column_title": "New customers"}),
    }},
    "12": {"display": "table", "vs": colset(
        traffic_type={"column_title": "Traffic"},
        valid_orders={"column_title": "Orders"},
        gmv={"column_title": "GMV", **CUR},
        refunds={"column_title": "Refunds", **CUR},
        net_revenue={"column_title": "Net revenue", **CUR},
        ad_spend={"column_title": "Ad spend", **CUR},
        net_mer={"column_title": "Net MER", **RATIO},
    )},
}

# 04 heatmap: robust-formatting "range" rules, matched per column by name (same key the plain
# table renderer consumes via table._cell_background_getter). Months 1-12 share one rule with a
# fixed 0-15 domain (values clamp at the ends); month 0 is 100% by construction and stays plain.
CFG["04"] = {
    "display": "table",
    "vs": {
        "table.column_formatting": [{
            "columns": [f"month_{i}" for i in range(1, 13)],
            "type": "range",
            "colors": ["#F2F8FD", "#0B4F8A"],
            "min_type": "custom", "min_value": 0,
            "max_type": "custom", "max_value": 15,
        }],
        "column_settings": {
            json.dumps(["name", c], separators=(",", ":")): {"column_title": t}
            for c, t in [("cohort", "Cohort")] + [(f"month_{i}", str(i)) for i in range(13)]
        },
    },
    "desc": ("Cohort retention heatmap: rows are monthly cohorts (YYYY-MM), columns are months "
             "since acquisition 0-12. Wide native table (one column per month) with a fixed 0-15 "
             "gradient on months 1-12 via conditional formatting; month 0 is 100% by construction."),
}


def api(method, path, body=None, token=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method)
    if data:
        r.add_header("Content-Type", "application/json")
    if token:
        r.add_header("X-Metabase-Session", token)
    try:
        with urllib.request.urlopen(r, timeout=300) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        return e.code, {"_error": detail[:600]}


def must(status, payload, what):
    if status >= 300:
        raise RuntimeError(f"{what} failed: HTTP {status}: {payload.get('_error') if isinstance(payload, dict) else payload}")
    return payload


def query_cols(card_id, token, what):
    st, res = api("POST", f"/api/card/{card_id}/query", {}, token=token)
    must(st, res, f"query {what}")
    data = res.get("data") or {}
    return data.get("cols") or [], data.get("rows") or []


# ---------- credentials ----------
email = os.environ.get("METABASE_EMAIL")
password = os.environ.get("METABASE_PASSWORD")
if not (email and password):
    creds = {}
    with open(CRED_FILE, encoding="utf-8") as f:
        for line in f:
            if line.startswith("Email:"):
                creds["email"] = line.split(":", 1)[1].strip()
            if line.startswith("Password:"):
                creds["pw"] = line.split(":", 1)[1].strip()
    email, password = creds["email"], creds["pw"]

st, sess = api("POST", "/api/session", {"username": email, "password": password})
must(st, sess, "login")
token = sess["id"]

# ---------- database ----------
st, dbs = api("GET", "/api/database", token=token)
dbs = dbs.get("data", dbs) if isinstance(dbs, dict) else dbs
db_id = [d["id"] for d in dbs if str(d.get("engine", "")).startswith("bigquery")][0]
print(f"database id: {db_id}")

# ---------- collection ----------
st, cols = api("GET", "/api/collection", token=token)
cols = cols.get("data", cols) if isinstance(cols, dict) else cols
coll = next((c for c in cols if c.get("name") == COLLECTION_NAME), None)
if coll:
    coll_id = coll["id"]
else:
    st, coll = api("POST", "/api/collection", {"name": COLLECTION_NAME}, token=token)
    must(st, coll, "create collection")
    coll_id = coll["id"]
print(f"collection id: {coll_id}")


def list_cards_by_name():
    """Cards (incl. models) in the suite collection, keyed by name. /api/card plus collection items."""
    st, cards = api("GET", "/api/card", token=token)
    cards = cards.get("data", cards) if isinstance(cards, dict) else cards
    by = {c["name"]: c for c in cards if c.get("collection_id") == coll_id}
    st, items = api("GET", f"/api/collection/{coll_id}/items", token=token)
    items = items.get("data", items) if isinstance(items, dict) else items
    for i in items:
        name = i.get("name")
        if not name or not i.get("id") or name in by:
            continue
        if (i.get("model") or i.get("type")) == "dashboard":
            continue
        by[name] = {"id": i["id"], "type": i.get("type"), "_stub": True}
    return by


def read_question(num):
    fn = sorted(f for f in os.listdir(QUESTIONS_DIR) if f.startswith(num) and f.endswith(".sql"))[0]
    with open(os.path.join(QUESTIONS_DIR, fn), encoding="utf-8") as f:
        lines = f.read().splitlines()
    title = lines[1][3:].split(" \u2014 ")[0].strip()
    return title, "\n".join(lines)


def native_payload(name, sql, display, vs, desc=None):
    p = {
        "name": name,
        "dataset_query": {"database": db_id, "type": "native", "native": {"query": sql, "template-tags": {}}},
        "display": display,
        "visualization_settings": vs,
        "collection_id": coll_id,
        "parameters": [],
    }
    if desc:
        p["description"] = desc
    return p


# ---------- native cards ----------
by_name = list_cards_by_name()

card_ids = {}
for fn in sorted(f for f in os.listdir(QUESTIONS_DIR) if f.endswith(".sql")):
    num = fn[:2]
    with open(os.path.join(QUESTIONS_DIR, fn), encoding="utf-8") as f:
        lines = f.read().splitlines()
    title = lines[1][3:].split(" \u2014 ")[0].strip()
    sql = "\n".join(lines)
    cfg = CFG.get(num, {})
    if "sql_replace" in cfg:
        old, new = cfg["sql_replace"]
        sql = sql.replace(old, new)

    payload = {
        "name": title,
        "dataset_query": {"database": db_id, "type": "native", "native": {"query": sql, "template-tags": {}}},
        "display": cfg.get("display", "table"),
        "visualization_settings": cfg.get("vs", {}),
        "collection_id": coll_id,
        "parameters": [],
    }
    if cfg.get("desc"):
        payload["description"] = cfg["desc"]

    cid = None
    if title in by_name:
        cid = by_name[title]["id"]
    elif num in PREV_TITLES and PREV_TITLES[num] in by_name:
        cid = by_name[PREV_TITLES[num]]["id"]
        print(f"card {num}: renaming {PREV_TITLES[num]!r} -> {title!r}")
    if cid is not None:
        st, res = api("PUT", f"/api/card/{cid}", payload, token=token)
        must(st, res, f"update card {title}")
    else:
        st, res = api("POST", "/api/card", payload, token=token)
        must(st, res, f"create card {title}")
        cid = res["id"]
    card_ids[num] = cid
print("cards ready:", " ".join(f"{k}={v}" for k, v in sorted(card_ids.items())))

# ---------- KPI scalar tiles ----------
for fn in sorted(f for f in os.listdir(KPI_DIR) if f.endswith(".sql")):
    with open(os.path.join(KPI_DIR, fn), encoding="utf-8") as f:
        lines = f.read().splitlines()
    title = lines[1][3:].split(" \u2014 ")[0].strip()
    payload = native_payload(title, "\n".join(lines), "scalar", {})
    if title in by_name:
        cid = by_name[title]["id"]
        st, res = api("PUT", f"/api/card/{cid}", payload, token=token)
        must(st, res, f"update KPI tile {title}")
    else:
        st, res = api("POST", "/api/card", payload, token=token)
        must(st, res, f"create KPI tile {title}")
        cid = res["id"]
    card_ids[f"kpi_{fn[:-4]}"] = cid
print("KPI tiles:", " ".join(f"{k}={v}" for k, v in sorted(card_ids.items()) if k.startswith("kpi_")))

# ---------- derived cards ----------
# 04 history: earlier deploys pinned a query-builder pivot over a companion "model" card. The
# v0.64 pivot enforces a wide minimum cell width, so months 10-12 could not fit within 24 grid
# units; 04 is now a plain wide native table (one column per month) handled by the native loop
# above, which converts the existing pivot card in place (same title). Retire the legacy model
# so the collection stays clean.
title04, _ = read_question("04")
model_name = f"{title04} \u2014 model"
by_name = list_cards_by_name()
if model_name in by_name:
    st, res = api("PUT", f"/api/card/{by_name[model_name]['id']}", {"archived": True}, token=token)
    must(st, res, f"archive legacy model {model_name}")
    print(f"archived legacy model card: {model_name}")

title08, sql08 = read_question("08")
twin_name = f"{title08} (table)"
twin_vs = {"table.columns": [
    {"name": "source", "enabled": True},
    {"name": "purchases", "enabled": True},
    {"name": "revenue", "enabled": True},
    {"name": "ratio_vs_spend", "enabled": True},
    {"name": "note", "enabled": True},
    {"name": "sort_order", "enabled": False},
]}
twin_vs.update(colset(
    source={"column_title": "Source"},
    purchases={"column_title": "Orders"},
    revenue={"column_title": "Revenue", **CUR},
    ratio_vs_spend={"column_title": "Ratio", **RATIO},
    note={"column_title": "Note"},
))
twin_payload = native_payload(
    twin_name, sql08, "table", twin_vs,
    "Table presentation of the same reconciliation ratios as the bar card (pinned on the audit page; "
    "the bar version stays on the executive page).")
by_name = list_cards_by_name()
if twin_name in by_name:
    twin_id = by_name[twin_name]["id"]
    st, res = api("PUT", f"/api/card/{twin_id}", twin_payload, token=token)
    must(st, res, f"update twin card {twin_name}")
else:
    st, res = api("POST", "/api/card", twin_payload, token=token)
    must(st, res, f"create twin card {twin_name}")
    twin_id = res["id"]
card_ids["08t"] = twin_id
print(f"derived cards: twin={twin_id}")

# ---------- dashboards + dashcards ----------
st, items = api("GET", f"/api/collection/{coll_id}/items", token=token)
items = items.get("data", items) if isinstance(items, dict) else items
dash_by_name = {i["name"]: i["id"] for i in items if (i.get("model") or i.get("type")) == "dashboard"}

for dname, layout in LAYOUTS.items():
    if dname in dash_by_name:
        did = dash_by_name[dname]
    else:
        st, res = api("POST", "/api/dashboard", {"name": dname, "description": PROV, "collection_id": coll_id}, token=token)
        must(st, res, f"create dashboard {dname}")
        did = res["id"]

    st, dash = api("GET", f"/api/dashboard/{did}", token=token)
    existing = dash.get("dashcards") or []
    text_dc = next((dc for dc in existing if dc.get("card_id") is None), None)
    by_card = {dc.get("card_id"): dc["id"] for dc in existing if dc.get("card_id") is not None}

    cards_payload = []
    new_id = -1
    for entry in layout:
        if entry[0] == "text":
            # v0.64: the frontend merges vs.virtual_card into the dashcard card on load (text render).
            cards_payload.append({
                "id": text_dc["id"] if text_dc else new_id,
                "card_id": None,
                "row": entry[2], "col": entry[3], "size_x": entry[4], "size_y": entry[5],
                "visualization_settings": {"virtual_card": VC, "text": TEXT_CARD},
                "card": VC,
            })
            if not text_dc:
                new_id -= 1
        else:
            cid = card_ids[entry[1]]
            vs = entry[6] if len(entry) > 6 else {}
            cards_payload.append({
                "id": by_card.get(cid, new_id),
                "card_id": cid,
                "row": entry[2], "col": entry[3], "size_x": entry[4], "size_y": entry[5],
                "visualization_settings": vs,
            })
            if cid not in by_card:
                new_id -= 1

    st, res = api("PUT", f"/api/dashboard/{did}/cards", {"cards": cards_payload}, token=token)
    if st >= 300 and any("card" in c for c in cards_payload):
        # schema rejected the virtual card key: retry without it (vs.virtual_card alone still renders)
        for c in cards_payload:
            c.pop("card", None)
        st, res = api("PUT", f"/api/dashboard/{did}/cards", {"cards": cards_payload}, token=token)
    must(st, res, f"save dashcards for {dname}")
    print(f"{dname}: saved {len(cards_payload)} dashcards")

# ---------- verify ----------
print("\nverification (top-down):")
for dname, did in sorted(dash_by_name.items()):
    st, dash = api("GET", f"/api/dashboard/{did}", token=token)
    dcs = dash.get("dashcards") or []
    edge_ok = all((dc.get("col") or 0) + (dc.get("size_x") or 0) <= 24 for dc in dcs)
    print(f"\n{dname} (id {did}): {len(dcs)} dashcards, all within 24-col grid: {edge_ok}")
    for dc in sorted(dcs, key=lambda d: (d.get("row", 0), d.get("col", 0))):
        vs = dc.get("visualization_settings") or {}
        nm = (dc.get("card") or {}).get("name") or "(text card)"
        extra = " [virtual text]" if dc.get("card_id") is None and vs.get("virtual_card") else ""
        print(f"  row={dc.get('row'):>3} col={dc.get('col'):>3} {dc.get('size_x'):>2}x{dc.get('size_y'):<2}  {nm}{extra}")

print("\nderived cards:")
for label, cid in [("04", card_ids.get("04")), ("08 twin", card_ids.get("08t"))]:
    st, c = api("GET", f"/api/card/{cid}", token=token)
    print(f"  {label}: {c.get('name')} | type={c.get('type')} display={c.get('display')}")

print("\nrow-count checks:")
for num, expect in (("04", 24), ("09", 6), ("10", 24), ("12", 4)):
    _, rows_ = query_cols(card_ids[num], token, f"card {num}")
    ok = len(rows_) == expect
    print(f"  {num}: {len(rows_)} rows (expected {expect}) {'OK' if ok else 'MISMATCH'}")
    if not ok:
        raise RuntimeError(f"card {num}: expected {expect} rows, got {len(rows_)}")

print("\nKPI tiles:")
for key in sorted(k for k in card_ids if k.startswith("kpi_")):
    _, rows_ = query_cols(card_ids[key], token, key)
    print(f"  {card_ids[key]} {key} = {rows_[0][0] if rows_ else '(no rows)'}")

print("\nDeploy complete.")
