-- ============================================================
-- GOLD LAYER: Business Aggregations
-- Purpose: Build business-ready tables from Silver fact table
-- Input:   ANALYTICS.fact_orders (Silver)
-- Output:  ANALYTICS.agg_monthly_sales
--          ANALYTICS.agg_customer_summary
--          ANALYTICS.agg_data_quality_summary
-- ============================================================

USE DATABASE PIPELINE_DB;
USE WAREHOUSE PIPELINE_WH;
USE SCHEMA ANALYTICS;

-- ── Step 1: Verify Silver exists before building Gold ─────────
SELECT
    'Silver Row Count'      AS check_name,
    COUNT(*)                AS total_rows,
    CASE WHEN COUNT(*) > 0
         THEN 'PASS ✅ — Safe to build Gold'
         ELSE 'FAIL ❌ — Run Silver layer first'
    END                     AS result
FROM ANALYTICS.fact_orders;

-- ── Step 2: Pipeline health monitoring table ──────────────────
CREATE OR REPLACE TABLE ANALYTICS.agg_data_quality_summary AS
SELECT
    CURRENT_DATE()                          AS report_date,
    (SELECT COUNT(*) 
     FROM RAW.raw_orders)                   AS bronze_row_count,
    (SELECT COUNT(*) 
     FROM ANALYTICS.fact_orders)            AS silver_row_count,
    (SELECT COUNT(*) FROM RAW.raw_orders) -
    (SELECT COUNT(*) FROM ANALYTICS.fact_orders) AS rows_excluded_in_silver,
    ROUND(
        (SELECT COUNT(*) FROM ANALYTICS.fact_orders) * 100.0 /
        NULLIF((SELECT COUNT(*) FROM RAW.raw_orders), 0)
    , 2)                                    AS silver_pass_rate_pct,
    CASE WHEN
        (SELECT COUNT(*) FROM ANALYTICS.fact_orders) * 100.0 /
        NULLIF((SELECT COUNT(*) FROM RAW.raw_orders), 0) >= 95
        THEN 'PASS ✅' ELSE 'REVIEW ⚠️'
    END                                     AS quality_status;

-- ── Step 3: Business aggregations ────────────────────────────

-- Gold Table 1: Monthly Sales KPIs
CREATE OR REPLACE TABLE ANALYTICS.agg_monthly_sales AS
SELECT
    order_year,
    order_month,
    COUNT(DISTINCT order_id)                AS total_orders,
    SUM(sales)                              AS total_sales,
    SUM(profit)                             AS total_profit,
    ROUND(AVG(profit_margin_pct), 2)        AS avg_profit_margin,
    SUM(quantity)                           AS total_units_sold
FROM ANALYTICS.fact_orders
GROUP BY order_year, order_month
ORDER BY order_year, order_month;

-- Gold Table 2: Customer Summary
CREATE OR REPLACE TABLE ANALYTICS.agg_customer_summary AS
SELECT
    customer_id,
    customer_name,
    segment,
    region,
    COUNT(DISTINCT order_id)                AS total_orders,
    SUM(sales)                              AS total_sales,
    SUM(profit)                             AS total_profit,
    ROUND(AVG(profit_margin_pct), 2)        AS avg_profit_margin,
    MIN(order_date)                         AS first_order_date,
    MAX(order_date)                         AS last_order_date,
    DATEDIFF('day',
        MIN(order_date),
        MAX(order_date))                    AS customer_lifetime_days
FROM ANALYTICS.fact_orders
GROUP BY customer_id, customer_name, segment, region;

-- ── Step 4: Verify all Gold tables ───────────────────────────
SELECT 'agg_data_quality_summary' AS table_name, 
       COUNT(*)                   AS row_count 
FROM ANALYTICS.agg_data_quality_summary

UNION ALL

SELECT 'agg_monthly_sales'        AS table_name, 
       COUNT(*)                   AS row_count 
FROM ANALYTICS.agg_monthly_sales

UNION ALL

SELECT 'agg_customer_summary'     AS table_name, 
       COUNT(*)                   AS row_count 
FROM ANALYTICS.agg_customer_summary;

-- ── Step 5: Preview Gold tables ───────────────────────────────
SELECT * FROM ANALYTICS.agg_data_quality_summary;
SELECT * FROM ANALYTICS.agg_monthly_sales   LIMIT 10;
SELECT * FROM ANALYTICS.agg_customer_summary LIMIT 10;
