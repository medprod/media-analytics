# Media Analytics – Project Documentation
### Traditional vs. Digital Media Consumption Shift
**Author:** Medha Prodduturi
**Date:** April 2026

---

## Business Questions (5 Required)

| # | Question | Fact Table |
|---|---|---|
| BQ1 | How have viewership and subscriber metrics trended for traditional vs. digital platforms from 2015–2024? | FACT_MEDIA_PERFORMANCE |
| BQ2 | When did the shift from traditional to digital media accelerate most significantly? | FACT_MEDIA_PERFORMANCE |
| BQ3 | How does user engagement (hours, sessions, retention) compare across media types and regions? | FACT_ENGAGEMENT |
| BQ4 | How have streaming subscription prices changed over time, and how do pricing tiers relate to subscriber growth? | FACT_SUBSCRIPTION_PRICING |
| BQ5 | What factors most influence users to switch from traditional to digital media? | FACT_ENGAGEMENT |

---

## Part 1 – Schema Design

### 1.1 Constellation Schema

**3 Fact Tables** (individual project: 2–3 required)

| Fact Table | Type | Grain | Business Questions | Non-Time Dimensions |
|---|---|---|---|---|
| `FACT_MEDIA_PERFORMANCE` | **Cumulative** | Platform × Month | BQ1, BQ2 | DIM_PLATFORM, DIM_MEDIA_TYPE |
| `FACT_ENGAGEMENT` | **Transactional Snapshot** | Platform × Month × Region | BQ3, BQ5 | DIM_PLATFORM, DIM_GEOGRAPHY, DIM_SWITCH_REASON |
| `FACT_SUBSCRIPTION_PRICING` | **Transactional Snapshot** | Platform × Month × Plan | BQ4 | DIM_PLATFORM, DIM_SUBSCRIPTION_PLAN |

> All three fact tables also reference **DIM_DATE** (time dimension).

---

### 1.2 Non-Time Dimensions (5 required — labeled with SCD type)

| Dimension | SCD Type | Key Attributes | Reason for SCD Type |
|---|---|---|---|
| `DIM_PLATFORM` | **SCD2** | platform_key, platform_name, parent_company, business_model, media_sector, effective_date, end_date, is_current | Parent company and branding changes must preserve history (e.g., HBO Max → Max, Disney acquiring Hulu) |
| `DIM_MEDIA_TYPE` | SCD1 | media_type_key, media_type, category (Traditional/Digital), sub_category | Category lookups rarely restructure; overwrite is acceptable |
| `DIM_GEOGRAPHY` | SCD1 | geo_key, region, country, continent | Regional boundaries rarely change; overwrite acceptable |
| `DIM_SUBSCRIPTION_PLAN` | **SCD3** | plan_key, platform_name, current_price, previous_price, current_tier, previous_tier, price_change_date | Need to track both current and immediately prior price/tier in the same row |
| `DIM_SWITCH_REASON` | SCD1 | reason_key, primary_reason, reason_category, is_cost_related, is_content_related | Category lookup; values do not change meaningfully |

### 1.3 Time Dimension

| Dimension | SCD Type | Grain | Key Attributes |
|---|---|---|---|
| `DIM_DATE` | SCD0 | Monthly | date_key, year, quarter, month, month_name, is_holiday_month |

> Time dimension grain is monthly throughout. A quarterly rollup is supported via the `quarter` column for BQ2 trend acceleration analysis.

---

## Part 2 – Data Sources

### 2.1 Sources Used

| File | Source | Rows | Granularity | Feeds |
|---|---|---|---|---|
| `streaming_service.csv` | Kaggle | 779 | Monthly, per platform | FACT_SUBSCRIPTION_PRICING, DIM_SUBSCRIPTION_PLAN |
| `platform_summary.csv` | Streaming Platform Dataset | ~15 | Per platform | DIM_PLATFORM (initial load) |
| `platform_financials_comprehensive.csv` | Streaming Platform Dataset | ~10 | Quarterly | FACT_MEDIA_PERFORMANCE (revenue) |
| `industry_metrics.csv` | Streaming Platform Dataset | ~20 | Annual | FACT_MEDIA_PERFORMANCE (industry-level) |
| `traditional_media_viewership_monthly.csv` | AI-generated (synthetic) | 1,624 | Monthly | FACT_MEDIA_PERFORMANCE |
| `user_engagement_monthly.csv` | AI-generated (synthetic) | 4,120 | Monthly | FACT_ENGAGEMENT |
| `switch_factor_survey.csv` | AI-generated (synthetic) | 2,025 | Annual (survey) | FACT_ENGAGEMENT, DIM_SWITCH_REASON |
| `platform_subscriber_monthly.csv` | AI-generated (synthetic) | 640 | Monthly | FACT_MEDIA_PERFORMANCE |

### 2.2 Sources Removed

| File | Reason |
|---|---|
| `unemployment-rate.xlsx` | Does not directly answer any business question |
| `global_web_traffic_2026.csv` | Single point-in-time snapshot; no time dimension |
| `all-employees-publishing.xlsx` | Annual granularity only; flagged by professor as too coarse |

### 2.3 Intentional Messiness (for ETL demonstration)

| Dataset | Messiness Built In |
|---|---|
| `traditional_media_viewership_monthly.csv` | Mixed date formats (`Jan-2010`, `2010/01`, `March 2010`), some `metric_value` stored as strings (`"13.6M"`), inconsistent `media_type` casing, 25 duplicate rows |
| `user_engagement_monthly.csv` | Mixed date formats (`2015-01` vs `01/2015`), `retention_rate_pct` as decimal in some rows and `"78%"` string in others, nulls for new platforms in early months, 40 duplicate rows |
| `switch_factor_survey.csv` | Inconsistent `switched_from` values (`Cable` vs `Cable TV` vs `cable tv`), many null `secondary_switch_reason`, re-contacted respondent IDs duplicate across survey years, mixed `satisfaction_score` types |
| `platform_subscriber_monthly.csv` | Null `revenue_usd_millions` for some platforms, seasonal churn spikes, quarterly-to-monthly interpolation |

---

## Part 3 – ETL Plan

### 3.1 ETL Checklist

| Step | Status |
|---|---|
| Load staging: streaming_service.csv | Done |
| Load staging: platform_summary.csv | Done |
| Load staging: traditional_media, engagement, switch, subscriber CSVs | Not started |
| Date standardization (mixed formats → YYYY-MM-DD) | Done (streaming only) |
| Price tier classification | Done |
| Price MoM / cumulative change | Done |
| Platform name normalization | Done |
| Surrogate key generation | Done (DIM_PLATFORM only) |
| DIM_DATE build | Not started |
| DIM_MEDIA_TYPE build | Not started |
| DIM_GEOGRAPHY build | Not started |
| DIM_SWITCH_REASON build | Not started |
| DIM_PLATFORM initial load | Done (columns only, no SCD logic) |
| DIM_SUBSCRIPTION_PLAN build | Not started |
| **SCD2 upsert logic – DIM_PLATFORM** | Not started |
| **SCD3 update logic – DIM_SUBSCRIPTION_PLAN** | Not started |
| FACT_MEDIA_PERFORMANCE load | Not started |
| FACT_ENGAGEMENT load | Not started |
| FACT_SUBSCRIPTION_PRICING load | Not started |
| SCD0 demo (DIM_DATE — static, never updated) | Not started |
| SCD1 demo (DIM_MEDIA_TYPE — overwrite on change) | Not started |
| ERD updated with SCD labels on all dims | Not done |

### 3.2 SCD Maintenance to Demonstrate (ETL requirement)

Must show delta load maintenance for SCD0, SCD1, and at least one of SCD2 or SCD3.

**SCD2 Demo — DIM_PLATFORM (HBO Max → Max rebrand)**

| Step | Action |
|---|---|
| 1 | Show initial row: `platform_name = HBO Max`, `is_current = True`, `effective_date = 2020-05-27`, `end_date = NULL` |
| 2 | Simulate incoming delta: `platform_name` changed to `Max` |
| 3 | Expire old row: `end_date = 2023-05-23`, `is_current = False` |
| 4 | Insert new row: `platform_name = Max`, new surrogate key, `effective_date = 2023-05-23`, `end_date = NULL`, `is_current = True` |
| 5 | Show both rows in DIM_PLATFORM — historical record preserved |

**SCD3 Demo — DIM_SUBSCRIPTION_PLAN (Netflix price increase)**

| Step | Action |
|---|---|
| 1 | Show row: `current_price = 15.49`, `previous_price = NULL`, `current_tier = Mid` |
| 2 | Simulate price increase to $17.99 |
| 3 | Shift current → previous columns in place |
| 4 | Show updated row: `current_price = 17.99`, `previous_price = 15.49`, `current_tier = Premium`, `previous_tier = Mid`, `price_change_date = 2024-01-01` |

---

## Part 4 – Analytical Queries

Two of the five business questions must be answered via complex SQL analytical queries (window functions, CTEs, pivots).

### Query 1 — BQ2: When did the shift accelerate?
Use a window function to compute **year-over-year change in subscribers and viewership** per media type.
```sql
-- Rolling 12-month growth rate by media_type using LAG + window
WITH monthly AS (
    SELECT d.year, d.quarter, mt.media_type,
           SUM(f.subscribers_millions) AS total_subs
    FROM FACT_MEDIA_PERFORMANCE f
    JOIN DIM_DATE d ON f.date_key = d.date_key
    JOIN DIM_MEDIA_TYPE mt ON f.media_type_key = mt.media_type_key
    GROUP BY d.year, d.quarter, mt.media_type
),
lagged AS (
    SELECT *, LAG(total_subs, 4) OVER (PARTITION BY media_type ORDER BY year, quarter) AS subs_year_ago
    FROM monthly
)
SELECT *, ROUND((total_subs - subs_year_ago) / subs_year_ago * 100, 2) AS yoy_growth_pct
FROM lagged
WHERE subs_year_ago IS NOT NULL
ORDER BY media_type, year, quarter;
```

### Query 2 — BQ3: Engagement comparison across media types
Use a CTE + PIVOT-style aggregation to compare avg hours and retention side-by-side.
```sql
WITH engagement AS (
    SELECT mt.category, g.region,
           AVG(f.avg_hours_per_user_per_month) AS avg_hours,
           AVG(f.retention_rate_pct)           AS avg_retention,
           AVG(f.avg_sessions_per_user_per_month) AS avg_sessions
    FROM FACT_ENGAGEMENT f
    JOIN DIM_MEDIA_TYPE mt ON f.media_type_key = mt.media_type_key
    JOIN DIM_GEOGRAPHY g   ON f.geo_key = g.geo_key
    JOIN DIM_DATE d        ON f.date_key = d.date_key
    WHERE d.year BETWEEN 2018 AND 2024
    GROUP BY mt.category, g.region
)
SELECT * FROM engagement
ORDER BY category, region;
```

---

## Part 5 – Visualization Plan

Three visualizations required (Tableau / Power BI / Google Data Studio). All dimensions must appear across the three together.

| # | Visualization | Type | BQ Answered | Requirement Met | Dimensions Used |
|---|---|---|---|---|---|
| 1 | Subscriber growth over time: Digital vs. Traditional (drill year → quarter → month) | Line chart with hierarchy | BQ1, BQ2 | Drill-down/roll-up | DIM_DATE, DIM_MEDIA_TYPE, DIM_PLATFORM |
| 2 | Engagement heatmap by region and media type (filterable by year) | Heatmap | BQ3 | Filtering | DIM_GEOGRAPHY, DIM_MEDIA_TYPE, DIM_DATE |
| 3 | Subscription pricing tiers over time with calculated MoM price change | Bar + line combo | BQ4 | Calculated field | DIM_SUBSCRIPTION_PLAN, DIM_PLATFORM, DIM_DATE |

> Visualization 3's calculated field: `MoM Price Change % = (current_price - previous_price) / previous_price * 100`
> DIM_SWITCH_REASON is incorporated in Viz 1 as a tooltip/filter showing top switch reasons per platform.

---

## Part 6 – Presentation Outline (15 min)

| Segment | Time | Content |
|---|---|---|
| Data intro | 2 min | Brief overview of 4 data sources, sample rows, messiness challenges |
| Design | 4 min | Constellation schema, 5 BQs mapped to facts, SCD type labels on all dims, grain decisions |
| ETL | 5 min | Data flow diagram, key transforms (date parsing, price tiers, normalization), SCD2 or SCD3 demo live in notebook |
| Analytics + Viz | 3 min | Walk through 1 analytical query, show 2–3 visualizations |
| Pause for Q&A | After each segment |

**Code must be open and available during presentation — not just slides.**

---

## Part 7 – Deliverables Checklist

| Deliverable | Status |
|---|---|
| PowerPoint (constellation model, data flows, code samples, viz samples) | Not started |
| Dimensional constellation ERD — fully labeled with SCD types | Not done |
| Physical data flow diagram | Partial (drawio files exist, need update) |
| Source code (Python ETL notebook — well documented) | In progress |
| Analytical SQL queries | Not started |
| Tableau / Power BI visualizations (3 minimum) | Not started |
| Delta Report (post-presentation feedback response) | Not started |
