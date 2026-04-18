SELECT * FROM media.fact_subscription_pricing;
SELECT * FROM media.dim_subscription_plan;


-- BQ4: Subscription price changes and relationship to subscriber growth
WITH price_history AS (
    SELECT f.platform_name, f.date, f.price,
        f.price_tier, f.subscribers_millions, f.churn_rate_pct,
        LAG(f.price) OVER (PARTITION BY f.platform_name ORDER BY f.date) AS prev_price
    FROM media.fact_subscription_pricing f
),
price_changes AS (SELECT *, ROUND((price - prev_price) / prev_price * 100, 2) AS pct_increase
    FROM price_history
    WHERE prev_price IS NOT NULL
	AND price <> prev_price
)
SELECT platform_name,
    date AS change_date,
    prev_price AS old_price,
    price AS new_price,
    price_tier as new_price_tier,
    pct_increase as price_percent_increase,
    subscribers_millions,
    churn_rate_pct as churn_rate_percent,
    RANK() OVER (ORDER BY pct_increase DESC) AS percent_increase_rank
FROM price_changes
ORDER BY pct_increase DESC;
