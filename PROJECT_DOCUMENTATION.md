# Media Analytics — Project Documentation
### Traditional vs. Digital Media Consumption Shift
**Author:** Medha Prodduturi
**Date:** April 2026

---

## Business Questions

| # | Question | Fact Table |
|---|---|---|
| BQ1 | How have viewership and subscriber metrics trended for traditional vs. digital platforms from 2015–2024? | FACT_MEDIA_PERFORMANCE |
| BQ2 | When did the shift from traditional to digital media accelerate most significantly? | FACT_MEDIA_PERFORMANCE |
| BQ3 | How does user engagement (hours, sessions, retention) compare across media types and regions? | FACT_ENGAGEMENT |
| BQ4 | How have streaming subscription prices changed over time, and how do pricing tiers relate to subscriber growth? | FACT_SUBSCRIPTION_PRICING |
| BQ5 | What factors most influence users to switch from traditional to digital media? | FACT_ENGAGEMENT |

---

## Part 1 — Schema Design

### 1.1 Constellation Schema

Three fact tables share conformed dimensions through `DIM_DATE`,
`DIM_PLATFORM`, and `DIM_GEOGRAPHY`.

| Fact Table | Type | Grain | Business Questions | Non-Time Dimensions |
|---|---|---|---|---|
| `FACT_MEDIA_PERFORMANCE` | Cumulative | Platform × Month | BQ1, BQ2 | DIM_PLATFORM, DIM_MEDIA_TYPE, DIM_GEOGRAPHY |
| `FACT_ENGAGEMENT` | Transactional Snapshot | Platform × Month × Region | BQ3, BQ5 | DIM_PLATFORM, DIM_GEOGRAPHY, DIM_SWITCH_REASON |
| `FACT_SUBSCRIPTION_PRICING` | Transactional Snapshot | Platform × Month × Plan | BQ4 | DIM_PLATFORM, DIM_SUBSCRIPTION_PLAN |

All three fact tables reference `DIM_DATE` (monthly grain).

### 1.2 Non-Time Dimensions

| Dimension | SCD Type | Key Attributes | Reason for SCD Type |
|---|---|---|---|
| `DIM_PLATFORM` | SCD3 | platform_key, platform_name, current_parent_company, previous_parent_company, current_business_model, previous_business_model, parent_company_change_date, content_focus, launch_year, is_digital | Parent/rebrand changes are rare — current and previous state suffice in the same row |
| `DIM_MEDIA_TYPE` | SCD1 | media_type_key, media_type, category (Traditional/Digital), sub_category | Category lookups rarely restructure; overwrite is acceptable |
| `DIM_GEOGRAPHY` | SCD1 | geography_key, region_name, country, continent | Regional boundaries rarely change; overwrite acceptable |
| `DIM_SUBSCRIPTION_PLAN` | SCD2 | plan_key, platform_name, price, price_tier, effective_date, end_date, is_current | Prices change frequently; full price history is required for revenue- and churn-trend analysis |
| `DIM_SWITCH_REASON` | SCD1 | reason_key, primary_reason, reason_category, is_cost_related, is_content_related | Category lookup; values do not change meaningfully |

### 1.3 Time Dimension

| Dimension | SCD Type | Grain | Key Attributes |
|---|---|---|---|
| `DIM_DATE` | SCD0 | Monthly (2010–2026) | date_key, year, quarter, month, month_name, is_holiday_month |

Quarterly rollup is supported through the `quarter` column for BQ2
trend-acceleration analysis.

---

## Part 2 — Data Sources

### 2.1 Sources Used

| File | Source | Rows | Granularity | Feeds |
|---|---|---|---|---|
| `streaming_service.csv` | Kaggle | 777 | Monthly, per platform | FACT_SUBSCRIPTION_PRICING, DIM_SUBSCRIPTION_PLAN |
| `platform_summary.csv` | Streaming Platform Dataset | 12 | Per platform | DIM_PLATFORM |
| `platform_financials_comprehensive.csv` | Streaming Platform Dataset | 10 | Quarterly | FACT_MEDIA_PERFORMANCE (revenue) |
| `industry_metrics.csv` | Streaming Platform Dataset | 9 | Annual | FACT_MEDIA_PERFORMANCE (industry-level) |
| `traditional_media_viewership_monthly.csv` | Synthetic (AI-generated) | 1,624 | Monthly | FACT_MEDIA_PERFORMANCE |
| `user_engagement_monthly.csv` | Synthetic (AI-generated) | 4,120 | Monthly | FACT_ENGAGEMENT |
| `switch_factor_survey.csv` | Synthetic (AI-generated) | 2,025 | Annual (survey) | FACT_ENGAGEMENT, DIM_SWITCH_REASON |
| `platform_subscriber_monthly.csv` | Synthetic (AI-generated) | 640 | Monthly | FACT_MEDIA_PERFORMANCE |

### 2.2 Sources Removed

| File | Reason |
|---|---|
| `unemployment-rate.xlsx` | Does not directly answer any business question |
| `global_web_traffic_2026.csv` | Single point-in-time snapshot; no time dimension |
| `all-employees-publishing.xlsx` | Annual granularity only; too coarse |

### 2.3 Intentional Messiness (for ETL demonstration)

| Dataset | Messiness |
|---|---|
| `traditional_media_viewership_monthly.csv` | Mixed date formats (`Jan-2010`, `2010/01`, `March 2010`); some `metric_value` stored as strings (`"13.6M"`); inconsistent `media_type` casing; 25 duplicate rows |
| `user_engagement_monthly.csv` | Mixed date formats (`2015-01` vs `01/2015`); `retention_rate_pct` as decimal in some rows and `"78%"` string in others; nulls for new platforms in early months; 40 duplicate rows |
| `switch_factor_survey.csv` | Inconsistent `switched_from` values (`Cable` vs `Cable TV` vs `cable tv`); many null `secondary_switch_reason`; re-contacted respondent IDs duplicate across survey years; mixed `satisfaction_score` types |
| `platform_subscriber_monthly.csv` | Null `revenue_usd_millions` for some platforms; seasonal churn spikes; quarterly-to-monthly interpolation |

---

## Part 3 — ETL Pipeline

End-to-end pipeline lives in `media-analytics.ipynb`. All cells execute
top-to-bottom: profile → transform → build dimensions → build facts → load
to PostgreSQL.

### 3.1 Pipeline Checklist

| Step | Status |
|---|---|
| Profile eight raw sources (rows, nulls, uniqueness, date coverage) | Complete |
| Date standardization (all mixed formats → `datetime`) | Complete |
| Value normalization (`media_type` casing, `switched_from` variants, `retention_rate_pct`) | Complete |
| Deduplication (traditional_media, user_engagement) | Complete |
| Unit stripping (`"13.8M"` → `13.8`) | Complete |
| Derived columns (`price_tier`, `is_digital`, `yoy_growth_pct`, `cumulative_subscribers`, `price_change_mom`) | Complete |
| Cross-source platform alignment | Complete |
| DIM_DATE build (SCD0) | Complete |
| DIM_MEDIA_TYPE build (SCD1) | Complete |
| DIM_GEOGRAPHY build (SCD1) | Complete |
| DIM_SWITCH_REASON build (SCD1) | Complete |
| DIM_SUBSCRIPTION_PLAN build (SCD2) | Complete |
| DIM_PLATFORM build (SCD3) | Complete |
| FACT_SUBSCRIPTION_PRICING load | Complete |
| FACT_MEDIA_PERFORMANCE load | Complete |
| FACT_ENGAGEMENT load | Complete |
| PostgreSQL `media` schema load (psycopg2) | Complete |
| SCD0 delta demo (DIM_DATE rejected-update) | Complete |
| SCD1 delta demo (DIM_MEDIA_TYPE overwrite) | Complete |
| SCD1 delta demo (DIM_GEOGRAPHY overwrite) | Complete |
| SCD1 delta demo (DIM_SWITCH_REASON overwrite) | Complete |
| SCD2 delta demo (DIM_SUBSCRIPTION_PLAN expire-and-insert) | Complete |
| SCD3 delta demo (DIM_PLATFORM current/previous shift) | Complete |
| ERD with SCD labels | Complete |

### 3.2 SCD Maintenance Demonstrations

SCD delta load maintenance is demonstrated live in the notebook for every
SCD type.

**SCD0 — DIM_DATE (rejected update)**

| Step | Action |
|---|---|
| 1 | Simulate incoming change: source system wants `month_name` for `2020-03` changed from `March` to `Mar` |
| 2 | Guard rejects any write to immutable columns and leaves the row untouched |
| 3 | Post-check confirms no row changed |

**SCD1 — DIM_MEDIA_TYPE (in-place overwrite)**

| Step | Action |
|---|---|
| 1 | Show current row: `sub_category = Linear TV` |
| 2 | Simulate incoming delta: standardize to `Linear Broadcast` |
| 3 | Overwrite in place — prior label is not retained |

Analogous SCD1 demos run for `DIM_GEOGRAPHY` (region-name correction) and
`DIM_SWITCH_REASON` (reason-category correction).

**SCD2 — DIM_SUBSCRIPTION_PLAN (Netflix price increase)**

| Step | Action |
|---|---|
| 1 | Show current row: `platform = Netflix`, `price = 15.49`, `price_tier = Mid`, `is_current = True`, `end_date = NULL` |
| 2 | Simulate incoming delta: Netflix raises price to $17.99 (Jan 2024) |
| 3 | Expire old row: `end_date = 2023-12-31`, `is_current = False` |
| 4 | Insert new row: `price = 17.99`, `price_tier = Premium`, new `plan_key`, `effective_date = 2024-01-01`, `is_current = True` |
| 5 | Show both rows — full price history preserved |

**SCD3 — DIM_PLATFORM (parent-company rebrand)**

| Step | Action |
|---|---|
| 1 | Show initial row: `current_parent_company = Warner Bros. Discovery`, `previous_parent_company = NULL` |
| 2 | Simulate rebrand delta: business model changes to `Subscription + Ads` (May 2023) |
| 3 | Shift current → previous in place; write new current values |
| 4 | Show updated row: `current_business_model = Subscription + Ads`, `previous_business_model = Subscription`, `parent_company_change_date = 2023-05-23` |

---

## Part 4 — Analytical Queries

Five business questions, each answered by a complex SQL query in
`analytical-queries.sql`. All queries use at least one CTE and at least one
window function.

### BQ1 — Traditional vs. digital trend, 2015–2024

Multi-fact aggregation with conditional grouping on `dim_media_type.category`.

```sql
SELECT d.year AS year, m.category AS media_category,
       ROUND(COALESCE(SUM(f.subscribers_millions), 0)::numeric, 2)   AS total_subscribers_in_millions,
       ROUND(COALESCE(SUM(f.viewership_millions),  0)::numeric, 2)   AS total_viewership_in_millions,
       ROUND(COALESCE(SUM(f.revenue_usd_millions), 0)::numeric, 2)   AS total_revenue_in_millions,
       COUNT(DISTINCT f.platform_key) AS platform_count
FROM media.fact_media_performance f
JOIN media.dim_date d       ON f.date_key = d.date_key
JOIN media.dim_media_type m ON f.media_type_key = m.media_type_key
GROUP BY d.year, m.category
ORDER BY d.year;
```

### BQ2 — When did the shift accelerate?

CTE pipeline with `CASE`-based pivot and a 3-year moving-average window.

```sql
WITH yearly AS (
    SELECT d.year, mt.category,
           SUM(COALESCE(f.subscribers_millions, 0) + COALESCE(f.viewership_millions, 0)) AS audience_m
    FROM media.fact_media_performance f
    JOIN media.dim_date d       ON f.date_key = d.date_key
    JOIN media.dim_media_type mt ON f.media_type_key = mt.media_type_key
    GROUP BY d.year, mt.category
),
pivoted AS (
    SELECT year,
           COALESCE(SUM(CASE WHEN category = 'Digital'     THEN audience_m END), 0) AS digital_m,
           COALESCE(SUM(CASE WHEN category = 'Traditional' THEN audience_m END), 0) AS traditional_m
    FROM yearly
    GROUP BY year
),
shares AS (
    SELECT year, digital_m, traditional_m,
           ROUND(100.0 * digital_m / NULLIF(digital_m + traditional_m, 0), 2) AS total_digital_pct
    FROM pivoted
)
SELECT year, digital_m, traditional_m, total_digital_pct,
       ROUND(AVG(total_digital_pct) OVER (ORDER BY year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)::numeric, 2)
           AS digital_3yr_moving_avg
FROM shares
ORDER BY year;
```

### BQ3 — Engagement by media type and region

CTE aggregation with a `LAG` window for year-over-year retention delta.

```sql
WITH agg AS (
    SELECT d.year, g.region_name AS region,
           CASE WHEN p.is_digital THEN 'Digital' ELSE 'Traditional' END AS media_type,
           ROUND(AVG(f.avg_hours_per_user)::numeric, 2)     AS avg_hours_per_user,
           ROUND(AVG(f.avg_sessions_per_month)::numeric, 2) AS avg_sessions_per_month,
           ROUND(AVG(f.retention_rate_pct)::numeric, 2)     AS avg_retention_pct,
           ROUND(SUM(f.monthly_active_users_millions)::numeric, 2) AS total_mau_m
    FROM media.fact_engagement f
    JOIN media.dim_platform  p ON f.platform_key  = p.platform_key
    JOIN media.dim_geography g ON f.geo_key        = g.geography_key
    JOIN media.dim_date      d ON f.date_key       = d.date_key
    GROUP BY d.year, g.region_name, p.is_digital
)
SELECT year, region, media_type,
       avg_hours_per_user, avg_sessions_per_month, avg_retention_pct, total_mau_m,
       ROUND((avg_retention_pct
            - LAG(avg_retention_pct) OVER (PARTITION BY region, media_type ORDER BY year))::numeric, 2)
           AS retention_yoy_change_pp
FROM agg
ORDER BY year, region, media_type;
```

### BQ4 — Price changes and subscriber growth

`LAG` for prior price, percent-change computation, `RANK` across change events.

```sql
WITH price_history AS (
    SELECT p.platform, d.full_date AS date, f.price, plan.price_tier,
           f.platform_key, f.date_key,
           LAG(f.price) OVER (PARTITION BY p.platform ORDER BY d.full_date) AS prev_price
    FROM media.fact_subscription_pricing f
    JOIN media.dim_platform          p    ON f.platform_key = p.platform_key
    JOIN media.dim_date              d    ON f.date_key     = d.date_key
    JOIN media.dim_subscription_plan plan ON f.plan_key     = plan.plan_key
),
price_changes AS (
    SELECT *, ROUND(((price - prev_price) / NULLIF(prev_price, 0)) * 100, 2) AS pct_increase
    FROM price_history
    WHERE prev_price IS NOT NULL AND price <> prev_price
)
SELECT pc.platform, pc.date AS change_date,
       pc.prev_price AS old_price, pc.price AS new_price,
       pc.price_tier AS new_price_tier,
       pc.pct_increase AS price_percent_increase,
       mp.subscribers_millions, mp.yoy_growth_pct AS subscriber_yoy_growth_pct,
       RANK() OVER (ORDER BY pc.pct_increase DESC) AS percent_increase_rank
FROM price_changes pc
LEFT JOIN media.fact_media_performance mp
       ON mp.platform_key = pc.platform_key AND mp.date_key = pc.date_key
ORDER BY pc.pct_increase DESC;
```

### BQ5 — Factors influencing switches to digital

Aggregation with `COUNT(*) OVER ()` percent-of-total window.

```sql
SELECT sr.reason_category, sr.primary_reason,
       sr.is_cost_related, sr.is_content_related,
       COUNT(*) AS switch_events,
       ROUND(AVG(f.retention_rate_pct)::numeric, 2) AS avg_retention_rate_after_switch,
       ROUND(AVG(f.avg_hours_per_user)::numeric, 2) AS avg_hours_after_switch,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_all_switches
FROM media.fact_engagement     f
JOIN media.dim_switch_reason   sr ON f.switch_reason_key = sr.reason_key
JOIN media.dim_platform        p  ON f.platform_key      = p.platform_key
WHERE p.is_digital = TRUE
GROUP BY sr.reason_category, sr.primary_reason, sr.is_cost_related, sr.is_content_related
ORDER BY switch_events DESC;
```

---

## Part 5 — Visualization Plan

Three visualizations spanning every dimension in the model.

| # | Visualization | Type | BQ | Requirement | Dimensions |
|---|---|---|---|---|---|
| 1 | Subscriber growth over time: Digital vs. Traditional (drill year → quarter → month) | Line chart with hierarchy | BQ1, BQ2 | Drill-down / roll-up | DIM_DATE, DIM_MEDIA_TYPE, DIM_PLATFORM |
| 2 | Engagement heatmap by region and media type (filterable by year) | Heatmap | BQ3 | Filtering | DIM_GEOGRAPHY, DIM_MEDIA_TYPE, DIM_DATE |
| 3 | Subscription pricing tiers over time with calculated MoM price change | Bar + line combo | BQ4 | Calculated field | DIM_SUBSCRIPTION_PLAN, DIM_PLATFORM, DIM_DATE |

Visualization 3 uses the calculated field
`MoM Price Change % = (current_price - previous_price) / previous_price * 100`.
`DIM_SWITCH_REASON` is incorporated in Visualization 1 as a tooltip/filter
surfacing top switch reasons per platform.

---

## Part 6 — Deliverables

| Deliverable | Location |
|---|---|
| Source code (Python ETL notebook) | `media-analytics.ipynb` |
| Analytical SQL queries (BQ1–BQ5) | `analytical-queries.sql` |
| Project plan | `PLAN.md` |
| Project README | `README.md` |
| Constellation ERD with SCD labels | `Diagrams/` |
| Physical data flow diagram | `Diagrams/` |
| Tableau / Power BI visualizations | Separate workbook files |
