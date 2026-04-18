# Media Analytics ETL — Full Implementation Plan

All implementation goes in `media_analytics_etl.ipynb`. `final.ipynb` is hands-off.

---

## Already Completed ✅

- **Part 1:** All 8 data sources profiled
- **Part 2:** `streaming_service.csv` transformations (T1–T6: dedup, date parse, price tier, MoM change, cumulative increase, name normalization)
- **Part 3:** `platform_summary.csv` transformations (T7–T9: select cols, derived cols, cross-source alignment)
- **Part 4:** `DIM_SUBSCRIPTION_PLAN` (SCD2) built + delta demo; `DIM_PLATFORM` (SCD3) built + delta demo
- **Part 5:** PostgreSQL connection (`cs689` db, `media` schema)
- **Part 6:** `FACT_SUBSCRIPTION_PRICING` built + loaded (777 rows)
- **`UPDATE4.sql`:** BQ4 SQL query written (LAG + RANK window functions)

---

## Stage 1 — Remaining Dimensions
Build and load 4 missing dims. Must include **SCD0 + SCD1 delta demos** (guideline requirement).

| Dim | Source | SCD Type | Key note |
|---|---|---|---|
| `DIM_DATE` | Generated programmatically (2010–2026) | SCD0 | Delta demo: insert-only, no updates ever |
| `DIM_MEDIA_TYPE` | Derived from `traditional_media_df` + `user_engagement_df` | SCD0 | Cols: media_type, category, is_digital |
| `DIM_GEOGRAPHY` | Derived from `platform_subscriber_monthly` + `traditional_media` | SCD1 | Delta demo: overwrite on region name correction |
| `DIM_SWITCH_REASON` | `switch_factor_survey.csv` | SCD0 | Cols: primary/secondary reason, is_price_related, is_content_related |

Load all 4 to PostgreSQL (`media` schema).

---

## Stage 2 — Transform + Load FACT_MEDIA_PERFORMANCE
**Sources:** `traditional_media_viewership_monthly.csv` + `platform_subscriber_monthly.csv` + `platform_financials_comprehensive.csv`

Key transforms needed:
- Fix 4 mixed date formats (`March 2010`, `2016/11`, `Jan-2010`, `June 2010`)
- Normalize `media_type` casing (`cable tv` / `CABLE TV` → `Cable TV`)
- Strip `"M"` suffix from `metric_value` strings (e.g. `13.8M`)
- Remove 25 duplicate rows
- Join subscriber data for `subscribers_millions`, `revenue_usd_millions`
- Resolve FKs: `platform_key`, `media_type_key`, `geography_key`, `date_key`
- Load → `media.fact_media_performance`

---

## Stage 3 — Transform + Load FACT_ENGAGEMENT
**Sources:** `user_engagement_monthly.csv` + `switch_factor_survey.csv`

Key transforms needed:
- Fix 2 mixed date formats (`01/2015` vs `2015-01`)
- Normalize `retention_rate_pct` (decimal `0.9165` vs string `"92.7%"`)
- Remove 40 duplicate rows; keep one canonical row per platform × month × region
- Normalize `switched_from` (18 variants → canonical set)
- Resolve FKs: `platform_key`, `date_key`, `switch_reason_key`, `geography_key`
- Load → `media.fact_engagement`

---

## Stage 4 — BQ4 Analytical Query (run in notebook)
Already written in `UPDATE4.sql`. Run against PostgreSQL, display results in notebook.
- **Tables:** `FACT_SUBSCRIPTION_PRICING` + `DIM_SUBSCRIPTION_PLAN`
- **Complexity:** CTE + LAG window function + RANK window function

---

## Stage 5 — BQ1 Analytical Query (2nd required complex query)
Traditional vs. digital viewership/subscriber trend 2015–2024.
- **Tables:** `FACT_MEDIA_PERFORMANCE` + `DIM_MEDIA_TYPE` + `DIM_DATE`
- **Complexity:** CTE + conditional aggregation (pivot) + YoY window function

---

## Stage 6 — CSV Exports for Visualization
Export clean result sets for each BQ to CSV. Visualizations done in Tableau/Power BI separately.

Guideline requirements:
- At least 3 visualizations
- One with drill-down/roll-up → use `DIM_DATE` hierarchy (decade → year → quarter → month)
- One with filtering
- One with calculated fields
- All dimensions used across visualizations

---

## Guidelines Checklist

| Requirement | Status |
|---|---|
| SCD0 delta demo | Stage 1 |
| SCD1 delta demo | Stage 1 |
| SCD2 delta demo (DIM_SUBSCRIPTION_PLAN) | ✅ Done |
| SCD3 delta demo (DIM_PLATFORM) | ✅ Done |
| 2 analytical SQL queries with complexity | Stages 4–5 |
| CSV exports for visualizations | Stage 6 |
| Physical data flow diagram | ✅ Done (`diagrams/`) |
| Constellation schema diagram | ✅ Done (`diagrams/`) |
