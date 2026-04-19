# Media Analytics ETL — Project Plan

End-to-end plan followed to build the Media Analytics data warehouse in
`media-analytics.ipynb`. The pipeline ingests eight raw sources, cleans and
conforms them, loads a constellation schema into PostgreSQL (`media` schema),
and answers five business questions through analytical SQL in
`analytical-queries.sql`.

---

## Part 1 — Data Sources Profile

Eight CSVs were profiled for row count, null distribution, column types,
uniqueness, and date coverage before any transformation.

| # | File | Rows | Feeds |
|---|---|---|---|
| 1 | `streaming_service.csv` | 777 | FACT_SUBSCRIPTION_PRICING, DIM_SUBSCRIPTION_PLAN |
| 2 | `platform_summary.csv` | 12 | DIM_PLATFORM |
| 3 | `platform_financials_comprehensive.csv` | 10 | FACT_MEDIA_PERFORMANCE |
| 4 | `industry_metrics.csv` | 9 | FACT_MEDIA_PERFORMANCE |
| 5 | `traditional_media_viewership_monthly.csv` | 1,624 | FACT_MEDIA_PERFORMANCE |
| 6 | `platform_subscriber_monthly.csv` | 640 | FACT_MEDIA_PERFORMANCE |
| 7 | `user_engagement_monthly.csv` | 4,120 | FACT_ENGAGEMENT |
| 8 | `switch_factor_survey.csv` | 2,025 | FACT_ENGAGEMENT, DIM_SWITCH_REASON |

Known-issue catalog (mixed date formats, inconsistent casing, embedded units,
duplicate rows, mixed numeric/string columns) was documented per source so
each issue could be tied to a specific downstream transform.

---

## Part 2 — Transformations

Raw frames are cleaned and enriched before any warehouse load. Transformation
families applied across sources:

- **Deduplication** — exact-duplicate removal on traditional media and user
  engagement frames.
- **Date normalization** — collapse mixed formats (`Jan-2010`, `2010/01`,
  `March 2010`, `2015-01`, `01/2015`, `Jul-2011`) to a single `datetime`.
- **Casing and value normalization** — `cable tv` / `CABLE TV` → `Cable TV`;
  `switched_from` variants (`Cable`, `cable tv`, `Cable TV`) → canonical set;
  `retention_rate_pct` mixed decimal/percent strings → uniform percent.
- **Unit stripping** — remove `"M"` suffix from `metric_value`, cast to float.
- **Derived columns** — `price_tier`, `is_digital`, `media_sector`,
  `price_change_mom`, `cumulative_price_increase`, `yoy_growth_pct`,
  `cumulative_subscribers`.
- **Cross-source platform alignment** — reconcile platform names across
  streaming, financial, and subscriber feeds before FK resolution.

---

## Part 3 — Dimension Build and Load

Six dimensions built with full SCD-type coverage and per-dimension delta
demonstrations to prove the SCD behavior works end to end.

| Dimension | SCD | Source | Delta demo |
|---|---|---|---|
| `DIM_DATE` | SCD0 | Generated (2010–2026, monthly grain) | Attempted update to immutable `month_name` is rejected |
| `DIM_MEDIA_TYPE` | SCD1 | `traditional_media` + `user_engagement` | `sub_category` correction overwrites in place |
| `DIM_GEOGRAPHY` | SCD1 | Region/market fields across four sources | Region name correction overwrites in place |
| `DIM_SWITCH_REASON` | SCD1 | `switch_factor_survey` | Reason-category correction overwrites in place |
| `DIM_SUBSCRIPTION_PLAN` | SCD2 | `streaming_service` | Netflix price change ($15.49 → $17.99, Jan 2024): old row expired, new surrogate key inserted |
| `DIM_PLATFORM` | SCD3 | `platform_summary` | Parent-company rebrand: current + previous kept in same row |

---

## Part 4 — Fact Build

Three fact tables, each at a specific grain:

| Fact | Grain | Sources | FKs |
|---|---|---|---|
| `FACT_SUBSCRIPTION_PRICING` | Platform × month | `streaming_service` | platform, date, plan |
| `FACT_MEDIA_PERFORMANCE` | Platform × month (streaming + traditional halves unioned) | `platform_subscriber_monthly`, `platform_financials_comprehensive`, `traditional_media_viewership_monthly`, `industry_metrics` | platform, date, media_type, geography |
| `FACT_ENGAGEMENT` | Platform × month × region | `user_engagement_monthly`, `switch_factor_survey` | platform, date, geography, switch_reason |

`switch_reason_key` on `FACT_ENGAGEMENT` is assigned from the modal
`primary_switch_reason` for users who switched **to** that platform in that
month and region.

---

## Part 5 — PostgreSQL Load (`media` schema)

All six dimensions and three facts are written to the `media` schema using
`psycopg2` with parameterized `INSERT ... ON CONFLICT` loads. Dimension loads
precede fact loads so FK resolution succeeds.

---

## Part 6 — Analytical Queries (`analytical-queries.sql`)

Five business questions, each expressed as a complex analytical SQL query
using CTEs and window functions.

| # | Business question | Techniques |
|---|---|---|
| BQ1 | Traditional vs. digital viewership/subscriber trend, 2015–2024 | Multi-fact join, conditional aggregation |
| BQ2 | When did the shift from traditional to digital accelerate most? | CTE pipeline, pivot via `CASE`, 3-year moving-average window |
| BQ3 | User engagement comparison by media type and region | CTE aggregation, `LAG` window for year-over-year retention delta |
| BQ4 | Streaming price changes over time and relation to subscriber growth | `LAG` for prior price, percent-change math, `RANK` window |
| BQ5 | Factors most influencing users to switch to digital | Aggregation with `COUNT(*) OVER ()` percent-of-total window |

Results are rendered inline in the notebook and exported as CSVs to drive the
Tableau/Power BI visualizations.

---

## Deliverables

- `media-analytics.ipynb` — end-to-end pipeline (profile, transform, model, load).
- `analytical-queries.sql` — five analytical queries against the `media` schema.
- `Diagrams/` — physical data flow and constellation schema diagrams.
- CSV exports — result sets feeding the visualization layer.
