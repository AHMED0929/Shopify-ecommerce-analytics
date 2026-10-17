"""
Full-funnel synthetic generator v2 — daily x campaign grain.

Reads : shopify_mock_orders_improved.csv (12,000 orders, DD-MM-YY dates, synthetic)
Writes: dim_campaign.csv, bridge_order_campaign.csv, fact_orders.csv,
        fact_order_items.csv, fact_ga4_funnel.csv, fact_adspend.csv (same folder)

Design rules (see README assumptions when shipped):
  * Shopify Source records PLATFORM, not paid status. Paid/organic is assigned
    here with documented shares: IG 70% paid / FB 70% / Google 65%.
  * Every purchase count ties exactly to the 11,718 valid Shopify orders.
  * Funnel rates mirror the Merch Store demo benchmark (view 65%,
    view->cart ~30%, cart->checkout ~53%, checkout->purchase ~49%).
  * Meta spend exists only at campaign-day grain. The join to orders is
    ALWAYS campaign + date, never user or order.
  * platform_claimed_* inflates +25% to model view-through + First-vs-All,
    so dashboards can show Meta-claimed vs GA4-last-click vs true MER.

Provenance: ALL generated rows are synthetic demonstration data.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

SEED = 42
rng = np.random.default_rng(SEED)

SHOPIFY_CSV = Path(r"C:\Users\Ahmed\Downloads\shopify_mock_orders_improved.csv")
OUT_DIR = Path(__file__).resolve().parent

# campaign_id, name, platform, traffic_type, default medium
DIM_CAMPAIGNS = [
    ("META_PROS_01", "Meta Prospecting", "meta", "Paid", "paid_social"),
    ("META_RET_02", "Meta Retargeting", "meta", "Paid", "paid_social"),
    ("META_SEAS_03", "Meta Seasonal Promo", "meta", "Paid", "paid_social"),
    ("GOOG_BRAND_01", "Google Brand Search", "google", "Paid", "cpc"),
    ("GOOG_PMAX_02", "Google Shopping PMax", "google", "Paid", "cpc"),
    ("ORG_DIRECT", "Direct / Organic", "direct", "Organic", "(none)"),
    ("ORG_IG", "Instagram Organic", "instagram", "Organic", "organic_social"),
    ("ORG_FB", "Facebook Organic", "facebook", "Organic", "organic_social"),
    ("ORG_GG", "Google Organic SEO", "google", "Organic", "organic"),
    ("INT_DRAFT", "Internal Draft Orders", "internal", "Internal", "internal"),
]
PAID = ["META_PROS_01", "META_RET_02", "META_SEAS_03", "GOOG_BRAND_01", "GOOG_PMAX_02"]

P_CHECKOUT, P_PURCHASE = 0.53, 0.49  # bottom-of-funnel invariant: fixed for ALL campaigns
# Top-of-funnel rates per campaign as (P_VIEW, P_CART). The product of all four
# rates MUST equal the campaign conversion rate — otherwise the residual dumps
# silently into checkout completion. Cold traffic bounces early, not at payment.
VIEW_CART_BY_CAMPAIGN = {
    "META_PROS_01": (0.25, 0.031), "GOOG_PMAX_02": (0.25, 0.031),
    "META_SEAS_03": (0.25, 0.031),   # -> ~0.20% overall
    "META_RET_02": (0.40, 0.077), "GOOG_BRAND_01": (0.40, 0.077),  # -> ~0.80%
    "ORG_IG": (0.65, 0.30), "ORG_FB": (0.65, 0.30),
    "ORG_GG": (0.65, 0.30),          # -> ~5.06%
    "ORG_DIRECT": (0.70, 0.33), "INT_DRAFT": (0.70, 0.33),  # -> ~6.0%
}
CLICK_TO_SESSION = 0.88
INFLATION = 1.25
TARGET_MER = 4.2
CPM = {"META_PROS_01": (9, 16), "META_RET_02": (9, 16), "META_SEAS_03": (9, 16),
       "GOOG_BRAND_01": (6, 10), "GOOG_PMAX_02": (9, 16)}
CTR = {"META_PROS_01": (0.010, 0.018), "META_RET_02": (0.010, 0.018),
       "META_SEAS_03": (0.010, 0.018), "GOOG_BRAND_01": (0.020, 0.035),
       "GOOG_PMAX_02": (0.010, 0.018)}


def main() -> None:
    df = pd.read_csv(SHOPIFY_CSV, dtype=str).fillna("")
    headers = df[df["Financial Status"] != ""].copy()
    assert len(headers) == 12_000, f"expected 12000, got {len(headers)}"
    headers["Total"] = headers["Total"].astype(float)
    headers["Refunded Amount"] = headers["Refunded Amount"].astype(float)
    headers["net_total"] = headers["Total"] - headers["Refunded Amount"]
    headers["order_dt"] = pd.to_datetime(headers["Created at"], format="%d-%m-%y %H:%M")
    headers["order_date"] = headers["order_dt"].dt.date
    valid = headers["Financial Status"].isin(["paid", "partially_refunded"])
    n_valid = int(valid.sum())
    print(f"orders={len(headers)} valid={n_valid}")

    dim = pd.DataFrame(DIM_CAMPAIGNS, columns=[
        "campaign_id", "campaign_name", "platform", "traffic_type", "default_utm_medium"])
    dim.to_csv(OUT_DIR / "dim_campaign.csv", index=False)

    # ---- Bridge: every order -> exactly one campaign, zero NULLs ----
    h = headers.reset_index(drop=True)
    camp = np.empty(len(h), dtype=object)
    usrc = np.empty(len(h), dtype=object)
    umed = np.empty(len(h), dtype=object)
    src = h["Source"].to_numpy()
    month = h["order_dt"].dt.month.to_numpy()
    r = rng.random(len(h))
    for i in range(len(h)):
        s = src[i]
        if s == "instagram":
            if r[i] < 0.70:
                c = ("META_PROS_01" if r[i] < 0.35 else
                     "META_RET_02" if r[i] < 0.56 else "META_SEAS_03")
                if c == "META_SEAS_03" and month[i] not in (10, 11, 12, 1):
                    c = "META_PROS_01"
                camp[i] = c
            else:
                camp[i] = "ORG_IG"
            usrc[i], umed[i] = "instagram", ("paid_social" if camp[i].startswith("META") else "organic_social")
        elif s == "facebook":
            if r[i] < 0.70:
                camp[i] = "META_PROS_01" if r[i] < 0.42 else "META_RET_02"
            else:
                camp[i] = "ORG_FB"
            usrc[i], umed[i] = "facebook", ("paid_social" if camp[i].startswith("META") else "organic_social")
        elif s == "google":
            if r[i] < 0.65:
                camp[i] = "GOOG_BRAND_01" if r[i] < 0.26 else "GOOG_PMAX_02"
            else:
                camp[i] = "ORG_GG"
            usrc[i], umed[i] = "google", ("cpc" if camp[i].startswith("GOOG") else "organic")
        elif s == "online_store":
            camp[i] = "ORG_DIRECT"
            usrc[i], umed[i] = "(direct)", "(none)"
        else:  # shopify_draft_order and anything unexpected
            camp[i] = "INT_DRAFT"
            usrc[i], umed[i] = "shopify", "internal"
    bridge = pd.DataFrame({
        "order_name": h["Name"], "order_date": h["order_date"], "source": src,
        "campaign_id": camp, "utm_source": usrc, "utm_medium": umed,
        "financial_status": h["Financial Status"], "order_total": h["Total"],
        "refunded_amount": h["Refunded Amount"], "net_revenue": h["net_total"],
    })
    assert bridge.isna().sum().sum() == 0, "NULLs in bridge"
    assert (bridge["campaign_id"] != "").all(), "blank campaign_id in bridge"
    assert len(bridge) == 12_000
    bridge.to_csv(OUT_DIR / "bridge_order_campaign.csv", index=False)

    # ---- Fact_Orders: 12,000 order header grain with ISO dates & clean schema ----
    fact_orders = pd.DataFrame({
        "order_name": h["Name"],
        "order_date": h["order_date"],  # YYYY-MM-DD
        "order_timestamp": h["order_dt"].dt.strftime("%Y-%m-%d %H:%M:%S"),
        "email": h["Email"],
        "financial_status": h["Financial Status"],
        "source": src,
        "total": h["Total"],
        "refunded_amount": h["Refunded Amount"],
        "net_revenue": h["net_total"],
    })
    assert len(fact_orders) == 12_000
    assert fact_orders["order_name"].nunique() == 12_000
    fact_orders.to_csv(OUT_DIR / "fact_orders.csv", index=False)

    # ---- Fact_OrderItems: line-item grain for SKU analysis ----
    items = df[df["Lineitem quantity"] != ""].copy()
    items["qty"] = items["Lineitem quantity"].astype(float)
    items["price"] = items["Lineitem price"].astype(float)
    items["disc"] = items["Lineitem discount"].replace("", "0").astype(float)
    fact_items = pd.DataFrame({
        "order_name": items["Name"],
        "lineitem_name": items["Lineitem name"],
        "lineitem_sku": items["Lineitem sku"],
        "lineitem_quantity": items["qty"],
        "lineitem_price": items["price"],
        "lineitem_discount": items["disc"],
        "lineitem_net": (items["qty"] * items["price"] - items["disc"]).round(2),
    })
    assert len(fact_items) == 21_587, f"expected 21587 items, got {len(fact_items)}"
    fact_items.to_csv(OUT_DIR / "fact_order_items.csv", index=False)

    # ---- Fact_GA4_Funnel: daily x campaign, purchases exact ----
    bv = bridge[bridge["financial_status"].isin(["paid", "partially_refunded"])].copy()
    g = bv.groupby(["order_date", "campaign_id"]).agg(
        purchases=("order_name", "size"),
        revenue=("order_total", "sum"),
        refunds=("refunded_amount", "sum"),
        net_revenue=("net_revenue", "sum"),
    ).reset_index()
    assert int(g["purchases"].sum()) == n_valid
    p = g["purchases"].to_numpy(dtype=float)
    # Forward computation only: sessions -> viewers -> carts -> checkouts.
    # Per-campaign top rates (bottom rates fixed), so step ratios always hold.
    pv = g["campaign_id"].map(lambda c: VIEW_CART_BY_CAMPAIGN[c][0]).to_numpy()
    pc = g["campaign_id"].map(lambda c: VIEW_CART_BY_CAMPAIGN[c][1]).to_numpy()
    conv = pv * pc * P_CHECKOUT * P_PURCHASE
    noise = lambda: rng.uniform(0.9, 1.1, len(g))
    sessions = np.round(p / conv * noise()).astype(int)
    viewers = np.minimum(np.round(sessions * pv).astype(int), sessions)
    carts = np.minimum(np.round(viewers * pc * noise()).astype(int), viewers)
    checkouts = np.minimum(np.round(carts * P_CHECKOUT * noise()).astype(int), carts)
    # Distinct buying sessions slightly below order count (multi-order sessions).
    purchase_sessions = np.minimum(np.round(p / 1.08).astype(int), sessions)
    funnel = pd.DataFrame({
        "date": g["order_date"], "campaign_id": g["campaign_id"],
        "sessions": sessions, "view_item_sessions": viewers,
        "add_to_cart_sessions": carts, "begin_checkout_sessions": checkouts,
        "purchase_sessions": purchase_sessions, "purchases": g["purchases"].to_numpy(),
        "revenue": g["revenue"].to_numpy().round(2),
        "refunds": g["refunds"].to_numpy().round(2),
        "net_revenue": g["net_revenue"].to_numpy().round(2),
    })
    assert int(funnel["purchases"].sum()) == n_valid
    funnel.to_csv(OUT_DIR / "fact_ga4_funnel.csv", index=False)

    # ---- Fact_AdSpend: daily x paid campaign ----
    paid_f = funnel[funnel["campaign_id"].isin(PAID)].copy()
    paid_f["clicks"] = np.maximum(
        np.round(paid_f["sessions"] / CLICK_TO_SESSION).astype(int), paid_f["sessions"])
    lo_cpm = paid_f["campaign_id"].map(lambda c: CPM[c][0])
    hi_cpm = paid_f["campaign_id"].map(lambda c: CPM[c][1])
    lo_ctr = paid_f["campaign_id"].map(lambda c: CTR[c][0])
    hi_ctr = paid_f["campaign_id"].map(lambda c: CTR[c][1])
    paid_f["impressions"] = np.maximum(
        np.round(paid_f["clicks"] / rng.uniform(lo_ctr, hi_ctr)).astype(int), paid_f["clicks"])
    paid_f["spend_raw"] = (
        paid_f["impressions"] / 1000 * rng.uniform(lo_cpm, hi_cpm))
    # Q4 weight: seasonal + holiday demand.
    m = pd.to_datetime(paid_f["date"]).dt.month.to_numpy()
    q4 = np.where(np.isin(m, [11, 12]), 1.35, np.where(np.isin(m, [10, 1]), 1.15, 1.0))
    seas = np.where(
        (paid_f["campaign_id"] == "META_SEAS_03").to_numpy(),
        np.where(np.isin(m, [10, 11, 12, 1]), 2.2, 0.25), 1.0)
    paid_f["spend_raw"] = paid_f["spend_raw"] * q4 * seas
    gmv = float(bv["order_total"].sum())
    scale = (gmv / TARGET_MER) / float(paid_f["spend_raw"].sum())
    # Guard: calibration must stay near 1.0. A large factor means the funnel
    # rates and the spend model disagree (previously hid a 35x distortion).
    assert 0.5 <= scale <= 1.5, f"spend calibration out of band: scale={scale:.2f}"
    paid_f["spend"] = (paid_f["spend_raw"] * scale).round(2)
    paid_f["platform_claimed_purchases"] = np.round(
        paid_f["purchases"] * INFLATION).astype(int)
    paid_f["platform_claimed_revenue"] = (paid_f["revenue"] * INFLATION).round(2)
    spend = paid_f[["date", "campaign_id", "spend", "impressions", "clicks",
                    "platform_claimed_purchases", "platform_claimed_revenue",
                    "purchases", "revenue"]].sort_values(["date", "campaign_id"])
    spend.to_csv(OUT_DIR / "fact_adspend.csv", index=False)

    # ---- Assertions ----
    assert int(spend["purchases"].sum()) == int(
        funnel[funnel["campaign_id"].isin(PAID)]["purchases"].sum()
    ), "spend/funnel paid purchase mismatch"
    dmin, dmax = bridge["order_date"].min(), bridge["order_date"].max()
    assert spend["date"].min() >= dmin and spend["date"].max() <= dmax
    mer = gmv / float(spend["spend"].sum())
    assert abs(mer - TARGET_MER) / TARGET_MER < 0.02, f"MER {mer}"
    new_customers = int(headers.loc[
        headers["Financial Status"].isin(["paid", "partially_refunded"]), "Email"].nunique())

    print(f"wrote dim_campaign.csv rows={len(dim)}")
    print(f"wrote bridge_order_campaign.csv rows={len(bridge)}")
    print(f"wrote fact_orders.csv rows={len(fact_orders)}")
    print(f"wrote fact_order_items.csv rows={len(fact_items)}")
    print(f"wrote fact_ga4_funnel.csv rows={len(funnel)}")
    print(f"wrote fact_adspend.csv rows={len(spend)}")
    print(f"GMV={gmv:,.2f} spend={float(spend['spend'].sum()):,.2f} "
          f"MER={mer:.2f} scale={scale:.2f}")
    print(f"blended_CPA={float(spend['spend'].sum()) / n_valid:.2f} "
          f"blended_CAC={float(spend['spend'].sum()) / new_customers:.2f} "
          f"(new_customers={new_customers})")
    print(f"net_revenue={float(funnel['net_revenue'].sum()):,.2f} "
          f"refunds={float(funnel['refunds'].sum()):,.2f}")
    print(f"meta_claimed_ROAS="
          f"{float(spend['platform_claimed_revenue'].sum()) / float(spend['spend'].sum()):.2f} "
          f"true_revenue_ROAS={gmv / float(spend['spend'].sum()):.2f}")
    print(f"date_range={dmin}..{dmax}")


if __name__ == "__main__":
    main()
