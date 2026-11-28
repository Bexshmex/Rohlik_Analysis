WITH full_years AS (
    SELECT
        fs.warehouse,
        EXTRACT(YEAR FROM fs.date) AS year,
        SUM(fs.real_revenue_czk) AS revenue
    FROM analytics.fact_sales AS fs
    GROUP BY
        fs.warehouse,
        EXTRACT(YEAR FROM fs.date)
    HAVING COUNT(DISTINCT EXTRACT(MONTH FROM fs.date)) = 12
),
with_prev AS (
    SELECT
        warehouse,
        year,
        revenue,
        LAG(revenue) OVER (
            PARTITION BY warehouse
            ORDER BY year
        ) AS prev_revenue
    FROM full_years
)
SELECT
    warehouse,
    year,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        ((revenue - prev_revenue) * 100.0 / NULLIF(prev_revenue, 0)),
        2
    ) AS yoy_growth_pct
FROM with_prev
ORDER BY
    warehouse,
    year;
-- Summary: YoY for each warehouse and year, revenue increases (includes only years with full 12 months, others are avoided).
-- Frankfurt_1 warehouse leaves without any YoY comparison due to an absence of January in 2022 - it will be calculated separately with help of 'Like for Like'
-- Munich_1 warehouse shows skyrocket increase in revenue 2023 comparing with 2022 revenue (49.99 %)

WITH monthly_revenue AS (
    SELECT
        EXTRACT(YEAR FROM fs.date)AS year,
        EXTRACT(MONTH FROM fs.date) AS month,
        SUM(fs.real_revenue_czk) AS revenue
    FROM analytics.fact_sales AS fs
    WHERE fs.warehouse = 'Frankfurt_1'
    GROUP BY year, month
)
SELECT
    curr.year AS curr_year,
    prev.year AS prev_year,
    curr.month,
    ROUND(prev.revenue,2) AS prev_revenue,
    ROUND(curr.revenue, 2) AS curr_revenue,
    ROUND(
        ((curr.revenue - prev.revenue) * 100.0 / NULLIF(prev.revenue, 0)),
        2
    ) AS yoy_growth_pct
FROM monthly_revenue AS curr
INNER JOIN monthly_revenue AS prev
    ON curr.month = prev.month
    AND curr.year = prev.year + 1
ORDER BY curr.year, curr.month;

-- Summary: A monthly Like-for-Like (LFL) analysis of Frankfurt_1 removes distortions from its December 2021 launch,
-- missing January 2022 data, and the incomplete 2024 calendar year,
-- revealing a clear transition from rapid expansion to a revenue plateau.
