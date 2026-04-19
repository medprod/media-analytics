# Media Analytics — Traditional vs. Digital Consumption Shift

CS689 Term Project — Medha Prodduturi

## Objective

Model the shift from traditional media (cable, broadcast, print, radio) to
digital streaming between 2010 and 2024, and use the resulting warehouse to
answer five business questions:

1. How have viewership and subscriber metrics trended for traditional vs.
   digital platforms from 2015–2024?
2. When did the shift from traditional to digital media accelerate most
   significantly?
3. How does user engagement (hours, sessions, retention) compare across media
   types and regions?
4. How have streaming subscription prices changed over time, and how do
   pricing tiers relate to subscriber growth?
5. What factors most influence users to switch from traditional to digital
   media?

The deliverable is an end-to-end ETL pipeline that ingests eight raw CSVs,
cleans and conforms them, loads a constellation-schema data warehouse into
PostgreSQL, and answers the five questions with analytical SQL.

## Architecture

- **Sources** — eight CSVs covering streaming pricing, platform metadata,
  platform financials, industry aggregates, traditional-media viewership,
  platform subscriber series, user engagement, and a switch-factor survey.
- **Transform layer** — pandas (notebook-based) for profiling, cleaning,
  deduplication, date normalization, value canonicalization, and derived-
  column computation.
- **Warehouse** — PostgreSQL `media` schema, constellation schema with three
  fact tables sharing conformed dimensions.
- **Analytical layer** — SQL with CTEs and window functions; result sets
  exported to CSV for the visualization layer (Tableau / Power BI).

### Warehouse model

Three fact tables:

- `FACT_SUBSCRIPTION_PRICING` — platform × month pricing.
- `FACT_MEDIA_PERFORMANCE` — platform × month performance (streaming and
  traditional halves unioned).
- `FACT_ENGAGEMENT` — platform × month × region engagement and switching.

Six dimensions spanning all four SCD types:

- `DIM_DATE` (SCD0), `DIM_MEDIA_TYPE` (SCD1), `DIM_GEOGRAPHY` (SCD1),
  `DIM_SWITCH_REASON` (SCD1), `DIM_SUBSCRIPTION_PLAN` (SCD2),
  `DIM_PLATFORM` (SCD3).

Each dimension includes a delta demonstration proving its SCD behavior
(rejected update for SCD0, in-place overwrite for SCD1, expire-and-insert for
SCD2, current + previous columns for SCD3).

## Repository Layout

```
media-analytics.ipynb            End-to-end ETL pipeline (profile → load)
analytical-queries.sql           Five analytical queries against media schema
PLAN.md                          Project plan (parts 1–6)
Diagrams/                        Data-flow and constellation-schema diagrams
data sources/                    Raw CSV sources
```

## Running the Pipeline

Prerequisites: Python 3.12+, `pandas`, `numpy`, `psycopg2`, and a running
PostgreSQL instance with a `media` schema the pipeline can write to.

1. Place raw CSVs under `data sources/` (structure preserved from the
   original drop).
2. Open `media-analytics.ipynb` and execute cells sequentially. The notebook
   profiles each source, applies transformations, builds dimensions and
   facts, and loads them into PostgreSQL.
3. Execute `analytical-queries.sql` against the `media` schema to produce the
   five BQ result sets.

## What the Project Demonstrated

- **Constellation-schema modeling in practice.** Three facts sharing
  conformed dimensions made cross-question reuse cheap: the same
  `DIM_DATE`, `DIM_PLATFORM`, and `DIM_GEOGRAPHY` serve pricing, performance,
  and engagement analyses without re-modeling time, platform, or region per
  fact.
- **Full-spectrum SCD handling.** Implementing SCD0 through SCD3 in one
  warehouse clarified the trade-offs: SCD0 guards protect truly immutable
  attributes, SCD1 is appropriate when historical labels add no analytical
  value, SCD2 is required whenever a metric depends on the attribute over
  time (pricing tiers), and SCD3 is sufficient when only the previous state
  is ever referenced (parent-company rebrands).
- **Upstream data quality dominates.** The bulk of engineering effort went
  into parsing mixed date formats, normalizing casing variants
  (`cable tv` / `Cable TV` / `CABLE TV`), reconciling platform names across
  feeds, stripping embedded units (`"13.8M"` strings), and resolving
  duplicate survey responses. Each of these is a small fix in isolation but
  a correctness requirement for any downstream join or aggregate.
- **Window functions are the right tool for most BQs.** Four of the five
  business questions reduced cleanly to CTE-plus-window-function patterns:
  `LAG` for year-over-year and prior-price deltas, moving-average windows
  for trend smoothing, `RANK` for ordering price-change events, and
  `COUNT(*) OVER ()` for percent-of-total. Pre-aggregating these at
  warehouse load time would have been premature; computing at query time
  keeps the warehouse model simple.
- **Grain discipline.** `FACT_MEDIA_PERFORMANCE` unioning a streaming half
  and a traditional half at the same platform × month grain (with
  `media_type_key` distinguishing them) kept the cross-category comparisons
  in BQ1 and BQ2 expressible in a single query rather than forcing a union
  in SQL every time.
- **Separation of pipeline and presentation.** Keeping transformations and
  loads in the notebook, analytical logic in SQL, and visualizations in
  Tableau/Power BI (consuming CSV exports) meant each layer could be
  iterated independently and re-run without touching the others.
