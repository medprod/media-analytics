# CS689 Term Project – Project Documentation
### Traditional vs. Digital Media Consumption Shift
**Author:** Medha Odduturu  
**Date:** April 2026  
**Course:** CS689 – Cloud Data Warehousing

---

## Business Questions

1. Which traditional media platforms observed decline/impact as digital platforms grew, and which modern streaming platforms show the most engagement over time?
2. When did the shift from traditional to digital media accelerate most significantly?
3. How does engagement differ between traditional and digital streaming (time spent / retention / frequency)?
4. What major factors influence users to switch from traditional to digital media?

---

## Part 1 – What We Have Done So Far

### 1.1 Data Sources Loaded

| File | Source | Rows | Granularity | Used For |
|---|---|---|---|---|
| `streaming_service.csv` | Kaggle | 779 | Monthly, per platform | Subscription pricing history |
| `platform_summary.csv` | Streaming Platform Dataset | ~15 | Per platform (snapshot) | Platform metadata (DIM_PLATFORM) |
| `platform_financials_comprehensive.csv` | Streaming Platform Dataset | ~10 | Quarterly, per platform | Platform financials |
| `industry_metrics.csv` | Streaming Platform Dataset | ~20 | Annual | Industry-level KPIs |
| `global_web_traffic_2026.csv` | Kaggle | 1,500 | Per domain (snapshot) | Web traffic / engagement proxy |
| `all-employees-publishing.xlsx` | BLS | ~30 | Monthly | Media industry employment |

### 1.2 Transformations Completed (Update 3 ETL Notebook)

**On `streaming_service.csv` → StreamingServiceDistinct_df:**

| # | Transformation | Description |
|---|---|---|
| 1 | Date Standardization | Parsed `date` column from `%b-%Y` string (e.g. `Jul-2011`) to proper `datetime` |
| 2 | Price Tier Classification | Derived `price_tier` column: Budget ($0–$7), Mid ($7–$14), Premium (>$14) |
| 3 | Month-over-Month Price Change | Computed `price_change_mom` = diff of `price` per service, sorted by date |
| 4 | Cumulative Price Increase | Computed `cumulative_price_increase` = current price minus the service's first recorded price |
| 5 | Duplicate Removal | Dropped exact duplicate rows |

**On `platform_summary.csv` → PlatformSummaryDistinct_df → DimPlatform:**

| # | Transformation | Description |
|---|---|---|
| 6 | Derived Columns | Added `is_digital=True`, `media_sector='Streaming'`, `platform_age_years`, `launch_decade` |
| 7 | Service Name Normalization | Mapped `HBO Max → Max`, `Prime Video → Amazon Prime Video` for cross-source consistency |
| 8 | Manual Platform Enrichment | Hand-built rows for Crunchyroll, Shudder (present in pricing but missing from summary) |
| 9 | Surrogate Key | Added `platform_key` as integer surrogate key |

### 1.3 Tables Partially Built

| Table | Status | Notes |
|---|---|---|
| `DIM_PLATFORM` | Partially complete | SCD2 columns added (`effective_date`, `end_date`, `is_current`) but only initial load — no actual SCD2 upsert logic |
| `FACT_SUBSCRIPTION_PRICING` | Not yet loaded | Data transformed, not written to warehouse |
| `DIM_DATE` | Not yet created | No date dimension table exists yet |

### 1.4 SCD Status

- **SCD2 on DIM_PLATFORM:** Columns `effective_date`, `end_date`, `is_current` were added, but the actual SCD2 process (detecting changes, expiring old rows, inserting new rows) has **not been implemented**.
- **SCD3:** Not started anywhere yet.

---

## Part 2 – What Needs to Change / Be Fixed

### 2.1 Schema: Need 5–6 Fact Tables

The professor requires **5–6 non-dimension (fact) tables**, each answering one business question using **one fact table + three dimensions** (typically including a date dimension).

**Proposed Constellation Schema:**

```
BQ1 → FACT_PLATFORM_PERFORMANCE    + DIM_PLATFORM + DIM_DATE + DIM_MEDIA_TYPE
BQ1 → FACT_TRADITIONAL_MEDIA       + DIM_PLATFORM + DIM_DATE + DIM_GEOGRAPHY
BQ2 → FACT_MARKET_SHARE            + DIM_PLATFORM + DIM_DATE + DIM_MEDIA_TYPE
BQ3 → FACT_ENGAGEMENT              + DIM_PLATFORM + DIM_DATE + DIM_SUBSCRIPTION_PLAN
BQ4 → FACT_SWITCH_FACTORS          + DIM_SWITCH_REASON + DIM_DATE + DIM_GEOGRAPHY
BQ4 → FACT_SUBSCRIPTION_PRICING    + DIM_PLATFORM + DIM_DATE + DIM_SUBSCRIPTION_PLAN
```

### 2.2 ERD: Must Label Every Dimension with SCD Type

**Every dimension table in the ERD must be labeled with its SCD type.** Current ERD does not show this. Required minimum: at least 1 SCD2 and at least 1 SCD3.

Proposed SCD type assignments:

| Dimension | SCD Type | Reason |
|---|---|---|
| `DIM_DATE` | SCD0 | Static, never changes |
| `DIM_MEDIA_TYPE` | SCD1 | Lookup values (TV, Streaming, Radio, Print); overwrite on change |
| `DIM_GEOGRAPHY` | SCD1 | Regions rarely restructure; overwrite is acceptable |
| `DIM_PLATFORM` | **SCD2** | Parent company changes (e.g., HBO Max → Max, Disney acquiring Hulu), business model changes; need full history |
| `DIM_SUBSCRIPTION_PLAN` | **SCD3** | Track current price tier AND previous price tier; SCD3 stores previous value in same row |
| `DIM_SWITCH_REASON` | SCD1 | Category lookup; unlikely to change |

### 2.3 SCD2 – DIM_PLATFORM (Must Implement for Presentation)

The SCD2 process needs to actually:
1. Compare incoming platform data against the existing dimension
2. If a tracked attribute changed (e.g., `parent_company`, `business_model`): expire the old row (`end_date = today`, `is_current = False`) and insert a new row
3. Assign a new surrogate key to the new row

**Tracked attributes (SCD2 columns):** `parent_company`, `business_model`, `media_sector`  
**Non-tracked attributes (overwrite in place):** `platform_age_years`, `launch_decade`

Known real-world changes to simulate:
- HBO Max rebranded to Max (2023) → parent company/name change
- Disney acquired full ownership of Hulu (2024)
- Peacock changed business model from free+paid to primarily paid

### 2.4 SCD3 – DIM_SUBSCRIPTION_PLAN

SCD3 stores the current value AND the immediately prior value in the same row.

Schema for `DIM_SUBSCRIPTION_PLAN`:

| Column | Type | Description |
|---|---|---|
| `plan_key` | INT | Surrogate key |
| `platform_name` | VARCHAR | Platform |
| `plan_tier` | VARCHAR | Current tier (Budget/Mid/Premium) |
| `current_price` | DECIMAL | Current monthly price |
| `previous_price` | DECIMAL | Previous monthly price (SCD3) |
| `price_change_date` | DATE | Date of last price change (SCD3) |
| `current_tier` | VARCHAR | Current tier label (SCD3) |
| `previous_tier` | VARCHAR | Previous tier label (SCD3) |

### 2.5 Data Sources to Remove

| Source | Reason to Remove |
|---|---|
| `unemployment-rate.xlsx` | Does not directly answer any of the 4 business questions; general economic indicator without causal link to media shift |
| `global_web_traffic_2026.csv` | Single-point-in-time snapshot (Feb 2026); no time dimension; cannot answer "when did shift accelerate" |
| `all-employees-publishing.xlsx` (BLS) | Annual granularity only; previously flagged by professor as too coarse |

### 2.6 Existing Sources to Keep (with Modifications)

| Source | Keep? | What to Fix |
|---|---|---|
| `streaming_service.csv` | Yes | Already transformed; wire into FACT_SUBSCRIPTION_PRICING |
| `platform_summary.csv` | Yes | Used for DIM_PLATFORM; add traditional media platforms manually |
| `platform_financials_comprehensive.csv` | Yes | Use quarterly revenue/subscribers for FACT_PLATFORM_PERFORMANCE |
| `industry_metrics.csv` | Yes | Use for FACT_MARKET_SHARE at industry level |

---

## Part 3 – What Is Missing and Needs to Be Added

### 3.1 Missing: Traditional Media Data

The project has **no traditional media data** — without it, we cannot answer BQ1 or BQ2 at all. We need metrics showing TV viewership, radio listeners, and print circulation over time, ideally monthly, 2010–2025.

### 3.2 Missing: Engagement Metrics

BQ3 asks about time spent, retention, and frequency. None of the current datasets contain this. We need platform-level engagement data: average hours per user per month, churn rate, session frequency.

### 3.3 Missing: Switching Factor Data

BQ4 asks why users switch. No survey or behavioral data exists in the current dataset. We need a dataset with reasons for switching (price, content quality, convenience, recommendation, etc.) broken down over time or by demographic.

---

## Part 4 – Next Steps (AI-Generated Datasets to Create)

The following datasets do not exist in clean form and should be **AI-generated** as realistic synthetic raw data. They should be created as messy, realistic CSVs (inconsistent formatting, some nulls, mixed date formats, duplicate rows) to exercise proper ETL skills.

---

### Dataset A: `traditional_media_viewership_monthly.csv`

**Purpose:** Answers BQ1 and BQ2 — shows traditional media decline over time  
**Target Fact Table:** `FACT_TRADITIONAL_MEDIA`  
**Suggested Columns:**

| Column | Notes |
|---|---|
| `report_month` | Mixed formats: `Jan-2010`, `2010/01`, `January 2010` (messy — needs standardization) |
| `platform_name` | e.g., `CBS`, `NBC`, `ABC`, `Fox`, `CNN`, `ESPN`, `USA Today`, `New York Times`, `NPR` |
| `media_type` | `Broadcast TV`, `Cable TV`, `Print`, `Radio` |
| `metric_name` | `avg_viewers_millions`, `print_circulation_thousands`, `weekly_listeners_millions` |
| `metric_value` | Numeric; some nulls, some as strings like `"14.2M"` |
| `market` | `US`, `UK`, `Global` — some inconsistent casing |
| `source` | Nielsen, Pew Research, etc. |

**Suggested Range:** Jan 2010 – Dec 2024, monthly  
**Suggested Platforms to Include:** CBS Evening News, ABC World News, Fox News, CNN, MSNBC, USA Today, WSJ, NPR Morning Edition, iHeartRadio  
**Intentional Messiness:** Mixed date formats, some `metric_value` as text, missing months for older platforms, inconsistent `media_type` casing

---

### Dataset B: `user_engagement_monthly.csv`

**Purpose:** Answers BQ3 — compares engagement depth across media types  
**Target Fact Table:** `FACT_ENGAGEMENT`  
**Suggested Columns:**

| Column | Notes |
|---|---|
| `year_month` | Format: `YYYY-MM`; some rows have `MM/YYYY` (messy) |
| `platform_name` | Streaming + traditional platforms |
| `media_type` | `Streaming`, `Broadcast TV`, `Cable TV`, `Radio`, `Print` |
| `avg_hours_per_user_per_month` | Some nulls for older platforms |
| `monthly_active_users_millions` | |
| `avg_sessions_per_user_per_month` | |
| `retention_rate_pct` | Churn inverse; some as decimals (0.78), some as pct strings (`78%`) |
| `region` | `North America`, `Europe`, `APAC` |

**Suggested Range:** Q1 2015 – Q4 2024 (quarterly is fine for this one, can extrapolate monthly)  
**Intentional Messiness:** retention stored as decimal in some rows and percent string in others; missing values for newer platforms in early years; duplicate rows for same platform/month

---

### Dataset C: `switch_factor_survey.csv`

**Purpose:** Answers BQ4 — why users switch from traditional to digital  
**Target Fact Table:** `FACT_SWITCH_FACTORS`  
**Suggested Columns:**

| Column | Notes |
|---|---|
| `survey_year` | 2015–2024 |
| `respondent_id` | Unique per survey row |
| `switched_from` | `Cable TV`, `Broadcast TV`, `Satellite Radio`, `Print` |
| `switched_to` | `Netflix`, `Spotify`, `YouTube`, `Hulu`, etc. |
| `primary_switch_reason` | One of: `Price`, `Content Selection`, `Convenience`, `Recommendation`, `Bundling`, `Device Availability` |
| `secondary_switch_reason` | Same values; many nulls |
| `age_group` | `18-24`, `25-34`, `35-44`, `45-54`, `55+` |
| `region` | US region: `Northeast`, `South`, `Midwest`, `West` |
| `household_income_bracket` | `<$35K`, `$35K-$75K`, `$75K-$150K`, `>$150K` |
| `satisfaction_score` | 1–10; some missing |

**Suggested Size:** ~2,000 rows (simulating annual survey waves 2015–2024, ~200/year)  
**Intentional Messiness:** Inconsistent `switched_from` values (`Cable` vs `Cable TV`), missing `secondary_switch_reason`, some duplicate respondent IDs across years (real surveys re-contact some panelists), `satisfaction_score` as float in some rows

---

### Dataset D: `platform_subscriber_monthly.csv` (AI-extended from financials)

**Purpose:** Provides monthly subscriber counts (current financial data is quarterly snapshots only)  
**Target Fact Table:** `FACT_PLATFORM_PERFORMANCE`  
**Suggested Columns:**

| Column | Notes |
|---|---|
| `year_month` | `YYYY-MM` |
| `platform_name` | All major streaming platforms |
| `subscribers_millions` | Interpolated monthly between known quarterly figures |
| `revenue_usd_millions` | Monthly estimate |
| `churn_rate_pct` | Synthetic but realistic |
| `new_subscribers_millions` | Gross adds |
| `cancelled_subscribers_millions` | Gross cancels |
| `country_region` | `US`, `International` |

**Suggested Range:** Jan 2015 – Dec 2024  
**Note:** Use real quarterly anchors from `platform_financials_comprehensive.csv` and interpolate months. Add realistic seasonal churn spikes (January cancellations post-holiday, summer dips).

---

## Part 5 – Final Target Schema Summary

### Fact Tables (6 total)

| Fact Table | Grain | Business Questions | Dimensions |
|---|---|---|---|
| `FACT_PLATFORM_PERFORMANCE` | Platform × Month | BQ1, BQ2 | DIM_PLATFORM, DIM_DATE, DIM_MEDIA_TYPE |
| `FACT_TRADITIONAL_MEDIA` | Platform × Month × Metric | BQ1, BQ2 | DIM_PLATFORM, DIM_DATE, DIM_GEOGRAPHY |
| `FACT_MARKET_SHARE` | Media Type × Month | BQ2 | DIM_MEDIA_TYPE, DIM_DATE, DIM_GEOGRAPHY |
| `FACT_ENGAGEMENT` | Platform × Month × Region | BQ3 | DIM_PLATFORM, DIM_DATE, DIM_GEOGRAPHY |
| `FACT_SUBSCRIPTION_PRICING` | Platform × Month × Plan | BQ3, BQ4 | DIM_PLATFORM, DIM_DATE, DIM_SUBSCRIPTION_PLAN |
| `FACT_SWITCH_FACTORS` | Survey Row | BQ4 | DIM_SWITCH_REASON, DIM_DATE, DIM_GEOGRAPHY |

### Dimension Tables (6 total, with SCD types)

| Dimension | SCD Type | Key Attributes |
|---|---|---|
| `DIM_DATE` | SCD0 | date_key, year, quarter, month, week, day_of_week, is_holiday |
| `DIM_PLATFORM` | **SCD2** | platform_key, platform_name, parent_company, business_model, media_sector, effective_date, end_date, is_current |
| `DIM_MEDIA_TYPE` | SCD1 | media_type_key, media_type, category (Traditional/Digital), sub_category |
| `DIM_GEOGRAPHY` | SCD1 | geo_key, region, country, continent |
| `DIM_SUBSCRIPTION_PLAN` | **SCD3** | plan_key, platform_name, current_price, previous_price, current_tier, previous_tier, price_change_date |
| `DIM_SWITCH_REASON` | SCD1 | reason_key, primary_reason, reason_category, is_cost_related, is_content_related |

---

## Part 6 – SCD Implementation Plan for Presentation

### SCD2 Demo: DIM_PLATFORM

Simulate the following real-world event to demonstrate SCD2:

**Event:** HBO Max rebrands to Max (May 2023). Parent company stays Warner Bros. Discovery, but `platform_name` and `content_focus` change.

**Steps to implement:**
1. Show initial DIM_PLATFORM row for `HBO Max` with `is_current=True`, `effective_date=2020-05-27`, `end_date=NULL`
2. Run SCD2 upsert: detect that `platform_name` changed
3. Update old row: `end_date = 2023-05-23`, `is_current = False`
4. Insert new row: `platform_name = Max`, new `platform_key`, `effective_date = 2023-05-23`, `end_date = NULL`, `is_current = True`
5. Show both rows in final DIM_PLATFORM to prove historical record is preserved

### SCD3 Demo: DIM_SUBSCRIPTION_PLAN

Simulate Netflix Standard plan price increase from $15.49 → $17.99 (Jan 2024).

**Steps to implement:**
1. Show current row: `current_price = 15.49`, `previous_price = NULL`, `current_tier = Mid`
2. Run SCD3 update: shift current → previous columns, write new current
3. Show updated row: `current_price = 17.99`, `previous_price = 15.49`, `current_tier = Premium`, `previous_tier = Mid`, `price_change_date = 2024-01-01`

---

## Part 7 – ETL Checklist: Current vs. Target State

| Step | Status |
|---|---|
| Load staging tables | Partial (2 of 6 sources) |
| Date standardization | Done |
| Price tier classification | Done |
| Price MoM / cumulative change | Done |
| Platform metadata derivations | Done |
| Service name normalization | Done |
| Surrogate key generation | Done (DIM_PLATFORM only) |
| DIM_DATE creation | Not started |
| DIM_MEDIA_TYPE creation | Not started |
| DIM_GEOGRAPHY creation | Not started |
| DIM_SUBSCRIPTION_PLAN (SCD3) | Not started |
| DIM_SWITCH_REASON creation | Not started |
| SCD2 upsert logic (DIM_PLATFORM) | Not started (columns added, no logic) |
| SCD3 update logic (DIM_SUBSCRIPTION_PLAN) | Not started |
| FACT_PLATFORM_PERFORMANCE load | Not started |
| FACT_TRADITIONAL_MEDIA load | Not started (no source data yet) |
| FACT_MARKET_SHARE load | Not started |
| FACT_ENGAGEMENT load | Not started (no source data yet) |
| FACT_SUBSCRIPTION_PRICING load | Not started |
| FACT_SWITCH_FACTORS load | Not started (no source data yet) |
| ERD updated with SCD labels | Not done |
| Cloud load (Snowflake / BigQuery) | Not done |
