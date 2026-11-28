-- select fs.warehouse,
--        Extract(Year from fs.date) as year,
--        Extract(month from fs.date) as month,
--        Extract(day from fs.date) as day,
--        round(sum(fs.real_revenue_czk), 0) as revenue
--        from analytics.fact_sales as fs
-- Group By
--         fs.warehouse,
--         Extract(Year from fs.date),
--         Extract(month from fs.date),
--         Extract(day from fs.date)
-- ORDER BY
--         fs.warehouse,
--         year,
--         month,
--         day
-- Summary: Daily revenue per warehouse is persistent each day


--
-- WITH category_revenue AS (
--     SELECT
--         dm.warehouse,
--         dm.l1_category_name_en,
--         SUM(fs.real_revenue_czk) AS revenue
--     FROM analytics.fact_sales AS fs
--     LEFT JOIN analytics.dim_product AS dm
--         ON fs.unique_id = dm.unique_id
--     GROUP BY
--         dm.warehouse,
--         dm.l1_category_name_en
-- )
-- SELECT
--     warehouse,
--     l1_category_name_en,
--     ROUND(revenue, 2) AS revenue,
--     ROUND(
--         (revenue * 100.0 / NULLIF(SUM(revenue) OVER (PARTITION BY warehouse), 0)),
--         2
--     ) AS warehouse_share_pct
-- FROM category_revenue
-- ORDER BY
--     warehouse,
--     l1_category_name_en;
-- Summary: The primary share of the whole revenue per category lies on Fruit and Vegetables category in each warehouse (from 65 to 74 %)


-- SELECT  dp.l1_category_name_en as category,
--         dp.name as product,
--         round(sum(fs.real_revenue_czk), 0) as revenue_per_product
--         from analytics.fact_sales fs
-- LEFT JOIN analytics.dim_product dp on fs.unique_id = dp.unique_id
-- GROUP BY dp.l1_category_name_en, product
-- ORDER BY revenue_per_product DESC
-- LIMIT 10
-- Summary: Products from Fruit and Vegetables predominate in TOP 10 products by revenue sum


SELECT  dp.l1_category_name_en as category,
        round(sum(fs.real_revenue_czk), 0) as revenue_per_category
        from analytics.fact_sales fs
LEFT JOIN analytics.dim_product dp on fs.unique_id = dp.unique_id
GROUP BY dp.l1_category_name_en
ORDER BY revenue_per_category DESC
-- Summary: Across the data Fruits and Vegetables category brings the highest revenue from all 3 categories




