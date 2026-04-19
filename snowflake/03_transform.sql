-- ============================================================
-- 03_transform.sql
-- Clean raw_orders → analytics tables for Power BI
-- ============================================================

USE DATABASE PIPELINE_DB;
USE WAREHOUSE PIPELINE_WH;
USE SCHEMA ANALYTICS;

-- ============================================================
-- 1. Cleaned view  (cast all types, flag returned orders)
-- ============================================================
CREATE OR REPLACE VIEW ANALYTICS.vw_clean_orders AS
SELECT
    TRY_CAST(row_id AS INTEGER)               AS row_id,
    order_id,
    TRY_TO_DATE(order_date, 'MM/DD/YYYY')     AS order_date,
    TRY_TO_DATE(ship_date,  'MM/DD/YYYY')     AS ship_date,
    DATEDIFF('day',
        TRY_TO_DATE(order_date, 'MM/DD/YYYY'),
        TRY_TO_DATE(ship_date,  'MM/DD/YYYY')
    )                                         AS days_to_ship,
    ship_mode,
    customer_id,
    TRIM(customer_name)                       AS customer_name,
    UPPER(TRIM(segment))                      AS segment,
    UPPER(TRIM(country))                      AS country,
    TRIM(city)                                AS city,
    TRIM(state)                               AS state,
    postal_code,
    UPPER(TRIM(region))                       AS region,
    TRIM(retail_sales_people)                 AS retail_sales_people,
    product_id,
    TRIM(category)                            AS category,
    TRIM(sub_category)                        AS sub_category,
    TRIM(product_name)                        AS product_name,
    CASE
        WHEN UPPER(TRIM(returned)) IN ('YES', 'Y', 'TRUE', '1') THEN TRUE
        ELSE FALSE
    END                                       AS is_returned,
    TRY_CAST(sales    AS FLOAT)               AS sales,
    TRY_CAST(quantity AS INTEGER)             AS quantity,
    TRY_CAST(discount AS FLOAT)               AS discount,
    TRY_CAST(profit   AS FLOAT)               AS profit,
    ROUND(
        TRY_CAST(profit AS FLOAT) /
        NULLIF(TRY_CAST(sales AS FLOAT), 0) * 100
    , 2)                                      AS profit_margin_pct,
    _loaded_at
FROM RAW.raw_orders
WHERE order_id IS NOT NULL;

-- ============================================================
-- 2. Fact table  (materialized for Power BI speed)
-- ============================================================
CREATE OR REPLACE TABLE ANALYTICS.fact_orders AS
SELECT
    row_id,
    order_id,
    order_date,
    ship_date,
    days_to_ship,
    ship_mode,
    customer_id,
    customer_name,
    segment,
    country,
    city,
    state,
    postal_code,
    region,
    retail_sales_people,
    product_id,
    category,
    sub_category,
    product_name,
    is_returned,
    sales,
    quantity,
    discount,
    profit,
    profit_margin_pct,
    DATE_TRUNC('month', order_date)           AS order_month,
    YEAR(order_date)                          AS order_year,
    MONTHNAME(order_date)                     AS order_month_name,
    _loaded_at
FROM ANALYTICS.vw_clean_orders
WHERE sales    IS NOT NULL
  AND quantity IS NOT NULL
  AND profit   IS NOT NULL;

-- ============================================================
-- 3. Aggregation: monthly sales summary by category
-- ============================================================
CREATE OR REPLACE TABLE ANALYTICS.agg_monthly_sales AS
SELECT
    order_month,
    order_year,
    category,
    sub_category,
    region,
    COUNT(DISTINCT order_id)            AS total_orders,
    SUM(quantity)                       AS total_quantity,
    ROUND(SUM(sales), 2)                AS total_sales,
    ROUND(SUM(profit), 2)               AS total_profit,
    ROUND(AVG(discount) * 100, 2)       AS avg_discount_pct,
    ROUND(SUM(profit) /
        NULLIF(SUM(sales), 0) * 100, 2) AS profit_margin_pct,
    SUM(CASE WHEN is_returned THEN 1 ELSE 0 END) AS returned_orders
FROM ANALYTICS.fact_orders
GROUP BY order_month, order_year, category, sub_category, region
ORDER BY order_month, category;

-- ============================================================
-- 4. Aggregation: customer summary (for customer analytics)
-- ============================================================
CREATE OR REPLACE TABLE ANALYTICS.agg_customer_summary AS
SELECT
    customer_id,
    customer_name,
    segment,
    region,
    state,
    city,
    retail_sales_people,
    COUNT(DISTINCT order_id)            AS total_orders,
    SUM(quantity)                       AS total_quantity,
    ROUND(SUM(sales), 2)                AS total_sales,
    ROUND(SUM(profit), 2)               AS total_profit,
    MIN(order_date)                     AS first_order_date,
    MAX(order_date)                     AS last_order_date,
    SUM(CASE WHEN is_returned THEN 1 ELSE 0 END) AS total_returns
FROM ANALYTICS.fact_orders
GROUP BY customer_id, customer_name, segment, region, state, city, retail_sales_people
ORDER BY total_sales DESC;

-- ============================================================
-- 5. Sanity check
-- ============================================================
SELECT 'fact_orders'         AS tbl, COUNT(*) AS rows FROM ANALYTICS.fact_orders
UNION ALL
SELECT 'agg_monthly_sales',           COUNT(*)         FROM ANALYTICS.agg_monthly_sales
UNION ALL
SELECT 'agg_customer_summary',        COUNT(*)         FROM ANALYTICS.agg_customer_summary;
