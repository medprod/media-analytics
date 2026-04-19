-- BQ1 — How have viewership and subscriber metrics trended for 
-- traditional vs. digital platforms from 2015–2024?

--media_type_key, platform_key, subscribers_millions, viewership_millions, revenue_usd_millions
SELECT * FROM media.fact_media_performance limit 10; 
SELECT * FROM media.dim_media_type limit 10; --media_type_key, media_type, category
SELECT * FROM media.dim_date limit 10; --year

SELECT d.year AS year, m.category AS media_category,
ROUND(COALESCE(SUM(f.subscribers_millions), 0)::numeric, 2)   as total_subscribers_in_millions,
ROUND(COALESCE(SUM(f.viewership_millions),  0)::numeric, 2) as total_viewership_in_millions,
ROUND(COALESCE(SUM(f.revenue_usd_millions), 0)::numeric, 2) as total_revenue_in_millions, 
COUNT(DISTINCT f.platform_key) AS platform_count
FROM media.fact_media_performance f
JOIN media.dim_date d ON f.date_key = d.date_key
JOIN media.dim_media_type m ON f.media_type_key = m.media_type_key
GROUP BY d.year, m.category
ORDER BY d.year;

-- BQ2 — When did the shift from traditional to digital media accelerate most significantly? [ANALYTICAL]
WITH yearly AS (
    SELECT d.year, mt.category,
        SUM(COALESCE(f.subscribers_millions, 0) + COALESCE(f.viewership_millions, 0)) AS audience_m
    FROM media.fact_media_performance f
    JOIN media.dim_date d ON f.date_key = d.date_key
    JOIN media.dim_media_type mt ON f.media_type_key = mt.media_type_key
    GROUP BY d.year, mt.category
),
pivoted AS (
    SELECT year, COALESCE(SUM(CASE WHEN category = 'Digital' THEN audience_m END), 0) AS digital_m,
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


-- BQ3 — How does user engagement (hours, sessions, retention) compare across media types and regions?[ANALYTICAL]
SELECT * FROM media.fact_engagement limit 10;
SELECT * FROM media.dim_platform limit 10;
SELECT * FROM media.dim_geography limit 10;

WITH agg AS (
    SELECT d.year, g.region_name AS region,
        CASE WHEN p.is_digital THEN 'Digital' ELSE 'Traditional' END AS media_type,
        ROUND(AVG(f.avg_hours_per_user)::numeric, 2) AS avg_hours_per_user,
        ROUND(AVG(f.avg_sessions_per_month)::numeric, 2) AS avg_sessions_per_month,
        ROUND(AVG(f.retention_rate_pct)::numeric, 2) AS avg_retention_pct,
        ROUND(SUM(f.monthly_active_users_millions)::numeric, 2) AS total_mau_m
    FROM media.fact_engagement f
    JOIN media.dim_platform p ON f.platform_key = p.platform_key
    JOIN media.dim_geography g ON f.geo_key = g.geography_key
    JOIN media.dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, g.region_name, p.is_digital
)
SELECT year, region, media_type,
    avg_hours_per_user, avg_sessions_per_month, avg_retention_pct, total_mau_m,
    ROUND((avg_retention_pct
         - LAG(avg_retention_pct) OVER (PARTITION BY region, media_type ORDER BY year))::numeric, 2)
        AS retention_yoy_change_pp
FROM agg
ORDER BY year, region, media_type;


-- BQ4 — How have streaming subscription prices changed over time, and how do
--       pricing tiers relate to subscriber growth?   [ANALYTICAL]
SELECT * FROM media.fact_subscription_pricing limit 10;
SELECT * FROM media.dim_date limit 10;
SELECT * FROM media.dim_platform limit 10;
SELECT * FROM media.subscription_plan limit 10;
SELECT * FROM media.fact_media_performance limit 10;

WITH price_history AS (
    SELECT p.platform, d.full_date AS date, f.price, plan.price_tier,
        f.platform_key, f.date_key,
        LAG(f.price) OVER (PARTITION BY p.platform ORDER BY d.full_date) AS prev_price
    FROM media.fact_subscription_pricing f
    JOIN media.dim_platform p ON f.platform_key = p.platform_key
    JOIN media.dim_date d ON f.date_key = d.date_key
    JOIN media.dim_subscription_plan plan ON f.plan_key = plan.plan_key
),
price_changes AS (
    SELECT *, ROUND(((price - prev_price) / NULLIF(prev_price, 0)) * 100, 2) AS pct_increase
    FROM price_history
    WHERE prev_price IS NOT NULL AND price <> prev_price
)
SELECT pc.platform,
    pc.date AS change_date,
    pc.prev_price AS old_price,
    pc.price AS new_price,
    pc.price_tier AS new_price_tier,
    pc.pct_increase AS price_percent_increase,
    mp.subscribers_millions,
    mp.yoy_growth_pct AS subscriber_yoy_growth_pct,
    RANK() OVER (ORDER BY pc.pct_increase DESC) AS percent_increase_rank
FROM price_changes pc
LEFT JOIN media.fact_media_performance mp
    ON mp.platform_key = pc.platform_key AND mp.date_key = pc.date_key
ORDER BY pc.pct_increase DESC;


---- BQ5 — What factors most influence users to switch from traditional to digital media?

--switch_reason_key, platform_key, avg_hours_per_user, retention_rate_pct 
SELECT * FROM media.fact_engagement limit 10;
SELECT * FROM media.dim_switch_reason limit 10; 
--primary_reason, reason_category, reason_key, is_cost_related, is_content_related
SELECT * FROM media.dim_platform limit 10; --platform_key, is_digital = TRUE

SELECT sr.reason_category, sr.primary_reason, sr.is_cost_related, sr.is_content_related,
COUNT(*) AS switch_events,
ROUND(AVG(f.retention_rate_pct)::numeric, 2) AS avg_retention_rate_after_switch,
ROUND(AVG(f.avg_hours_per_user)::numeric, 2) AS avg_hours_after_switch,
ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_all_switches
FROM media.fact_engagement f
JOIN media.dim_switch_reason sr ON f.switch_reason_key = sr.reason_key
JOIN media.dim_platform p  ON f.platform_key = p.platform_key
WHERE p.is_digital = TRUE
GROUP BY sr.reason_category, sr.primary_reason, sr.is_cost_related, sr.is_content_related
ORDER BY switch_events DESC;









