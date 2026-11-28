WITH bounds AS (
    SELECT
        CASE
            WHEN EXTRACT(DAY FROM MIN(date)) = 1 THEN MIN(date)
            ELSE (DATE_TRUNC('month', MIN(date)) + INTERVAL '1 month')::date
        END AS start_date,
        CASE
            WHEN MAX(date) = (DATE_TRUNC('month', MAX(date)) + INTERVAL '1 month - 1 day')::date
                THEN MAX(date)
            ELSE (DATE_TRUNC('month', MAX(date)) - INTERVAL '1 day')::date
        END AS end_date
    FROM analytics.fact_sales
),
monthly_revenue AS (
    SELECT
        fs.warehouse,
        EXTRACT(YEAR FROM fs.date)::int AS year,
        EXTRACT(MONTH FROM fs.date)::int AS month,
        SUM(fs.real_revenue_czk) AS revenue
    FROM analytics.fact_sales AS fs
    CROSS JOIN bounds AS b
    WHERE fs.date BETWEEN b.start_date AND b.end_date
    GROUP BY 1, 2, 3
),
with_lags AS (
    SELECT
        warehouse,
        year,
        month,
        revenue,
        LAG(revenue) OVER (
            PARTITION BY warehouse
            ORDER BY year, month
        ) AS prev_month_revenue,
        LAG(revenue) OVER (
            PARTITION BY warehouse, month
            ORDER BY year
        ) AS prev_year_revenue
    FROM monthly_revenue
)
SELECT
    warehouse,
    year,
    month,
    ROUND(revenue::numeric, 2) AS revenue,
    ROUND(
        ((revenue - prev_month_revenue) * 100.0 / NULLIF(prev_month_revenue, 0))::numeric,
        2
    ) AS mom_growth_pct,
    ROUND(
        ((revenue - prev_year_revenue) * 100.0 / NULLIF(prev_year_revenue, 0))::numeric,
        2
    ) AS yoy_growth_pct
FROM with_lags
ORDER BY
    warehouse,
    year,
    month;

SELECT ROUND(SUM(real_revenue_czk)) AS real_rev,
       ROUND(SUM(lost_revenue_czk)) AS lost_rev,
       COUNT(*)                     AS rows_cnt
FROM analytics.fact_sales;