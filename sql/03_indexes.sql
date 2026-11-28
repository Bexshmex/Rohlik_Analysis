CREATE INDEX idx_fact_sales_date       ON analytics.fact_sales (date);
CREATE INDEX idx_fact_sales_warehouse  ON analytics.fact_sales (warehouse);
CREATE INDEX idx_fact_sales_discount   ON analytics.fact_sales (is_discount);

ANALYZE analytics.fact_sales;
ANALYZE analytics.fact_orders;
ANALYZE analytics.dim_product;
ANALYZE analytics.dim_calendar;
