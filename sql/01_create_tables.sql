-- =========================================================
-- Rohlik Analysis: star schema
-- Run once before loading (src/load_clean.py)
-- =========================================================

CREATE SCHEMA IF NOT EXISTS analytics;
DROP TABLE IF EXISTS analytics.fact_sales;
DROP TABLE IF EXISTS analytics.fact_orders;
DROP TABLE IF EXISTS analytics.dim_product;
DROP TABLE IF EXISTS analytics.dim_calendar;

CREATE TABLE analytics.dim_product (
    unique_id            INTEGER      PRIMARY KEY,
    product_unique_id    INTEGER      NOT NULL,
    name                 VARCHAR(100) NOT NULL,
    l1_category_name_en  VARCHAR(100) NOT NULL,
    l2_category_name_en  VARCHAR(100) NOT NULL,
    l3_category_name_en  VARCHAR(100) NOT NULL,
    l4_category_name_en  VARCHAR(100) NOT NULL,
    warehouse            VARCHAR(20)  NOT NULL
);

CREATE TABLE analytics.dim_calendar (
    date          DATE         NOT NULL,
    warehouse     VARCHAR(20)  NOT NULL,
    holiday       BOOLEAN      NOT NULL,
    holiday_name  VARCHAR(100) NOT NULL,
    shops_closed  BOOLEAN      NOT NULL,
    PRIMARY KEY (date, warehouse)
);

CREATE TABLE analytics.fact_orders (
    date          DATE        NOT NULL,
    warehouse     VARCHAR(20) NOT NULL,
    total_orders  INTEGER     NOT NULL,
    PRIMARY KEY (date, warehouse),
    FOREIGN KEY (date, warehouse)
        REFERENCES analytics.dim_calendar (date, warehouse)
);

CREATE TABLE analytics.fact_sales (
    unique_id              INTEGER       NOT NULL,
    date                   DATE          NOT NULL,
    warehouse              VARCHAR(20)   NOT NULL,
    sales                  NUMERIC(12,2) NOT NULL,
    sell_price_main        NUMERIC(12,2) NOT NULL,
    max_discount           NUMERIC(6,4)  NOT NULL,
    is_discount            BOOLEAN       NOT NULL,
    availability           NUMERIC(6,4)  NOT NULL,
    actual_price_czk       NUMERIC(12,4) NOT NULL,
    real_revenue_czk       NUMERIC(14,2) NOT NULL,
    lost_revenue_czk       NUMERIC(14,2) NOT NULL,
    potential_revenue_czk  NUMERIC(14,2) NOT NULL,
    PRIMARY KEY (unique_id, date),
    FOREIGN KEY (unique_id)
        REFERENCES analytics.dim_product (unique_id),
    FOREIGN KEY (date, warehouse)
        REFERENCES analytics.dim_calendar (date, warehouse)
);