-- ============================================================
-- 05_data_quality_checks.sql
-- Run after 02_load_csv and 03_transform to validate data
-- ============================================================

USE DATABASE PIPELINE_DB;
USE WAREHOUSE PIPELINE_WH;

-- ============================================================
-- SECTION 1: ROW COUNTS
-- ============================================================

SELECT 'raw_orders'   AS table_name, COUNT(*) AS total_rows FROM RAW.raw_orders
UNION ALL
SELECT 'fact_orders',                COUNT(*)               FROM ANALYTICS.fact_orders;


-- ============================================================
-- SECTION 2: NULL CHECKS  (raw_orders)
-- How many nulls in each column
-- ============================================================

SELECT
    'row_id'              AS column_name, COUNT(*) - COUNT(row_id)              AS null_count, ROUND((COUNT(*) - COUNT(row_id))              / COUNT(*) * 100, 2) AS null_pct FROM RAW.raw_orders UNION ALL
SELECT 'order_id',                        COUNT(*) - COUNT(order_id),                          ROUND((COUNT(*) - COUNT(order_id))                          / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'order_date',                      COUNT(*) - COUNT(order_date),                        ROUND((COUNT(*) - COUNT(order_date))                        / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'ship_date',                       COUNT(*) - COUNT(ship_date),                         ROUND((COUNT(*) - COUNT(ship_date))                         / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'ship_mode',                       COUNT(*) - COUNT(ship_mode),                         ROUND((COUNT(*) - COUNT(ship_mode))                         / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'customer_id',                     COUNT(*) - COUNT(customer_id),                       ROUND((COUNT(*) - COUNT(customer_id))                       / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'customer_name',                   COUNT(*) - COUNT(customer_name),                     ROUND((COUNT(*) - COUNT(customer_name))                     / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'segment',                         COUNT(*) - COUNT(segment),                           ROUND((COUNT(*) - COUNT(segment))                           / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'country',                         COUNT(*) - COUNT(country),                           ROUND((COUNT(*) - COUNT(country))                           / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'city',                            COUNT(*) - COUNT(city),                              ROUND((COUNT(*) - COUNT(city))                              / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'state',                           COUNT(*) - COUNT(state),                             ROUND((COUNT(*) - COUNT(state))                             / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'postal_code',                     COUNT(*) - COUNT(postal_code),                       ROUND((COUNT(*) - COUNT(postal_code))                       / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'region',                          COUNT(*) - COUNT(region),                            ROUND((COUNT(*) - COUNT(region))                            / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'retail_sales_people',             COUNT(*) - COUNT(retail_sales_people),               ROUND((COUNT(*) - COUNT(retail_sales_people))               / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'product_id',                      COUNT(*) - COUNT(product_id),                        ROUND((COUNT(*) - COUNT(product_id))                        / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'category',                        COUNT(*) - COUNT(category),                          ROUND((COUNT(*) - COUNT(category))                          / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'sub_category',                    COUNT(*) - COUNT(sub_category),                      ROUND((COUNT(*) - COUNT(sub_category))                      / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'product_name',                    COUNT(*) - COUNT(product_name),                      ROUND((COUNT(*) - COUNT(product_name))                      / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'returned',                        COUNT(*) - COUNT(returned),                          ROUND((COUNT(*) - COUNT(returned))                          / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'sales',                           COUNT(*) - COUNT(sales),                             ROUND((COUNT(*) - COUNT(sales))                             / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'quantity',                        COUNT(*) - COUNT(quantity),                          ROUND((COUNT(*) - COUNT(quantity))                          / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'discount',                        COUNT(*) - COUNT(discount),                          ROUND((COUNT(*) - COUNT(discount))                          / COUNT(*) * 100, 2) FROM RAW.raw_orders UNION ALL
SELECT 'profit',                          COUNT(*) - COUNT(profit),                            ROUND((COUNT(*) - COUNT(profit))                            / COUNT(*) * 100, 2) FROM RAW.raw_orders
ORDER BY null_count DESC;


-- ============================================================
-- SECTION 3: DUPLICATE CHECKS
-- ============================================================

-- Duplicate row_id (should be 0)
SELECT 'Duplicate row_id' AS check_name,
       COUNT(*) - COUNT(DISTINCT row_id) AS duplicate_count
FROM RAW.raw_orders;

-- Duplicate order_id + product_id combo (each line item should be unique)
SELECT 'Duplicate order+product' AS check_name,
       COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '|', product_id)) AS duplicate_count
FROM RAW.raw_orders;

-- Show actual duplicate rows if any exist
SELECT
    order_id,
    product_id,
    COUNT(*) AS occurrences
FROM RAW.raw_orders
GROUP BY order_id, product_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;


-- ============================================================
-- SECTION 4: INVALID VALUE CHECKS
-- ============================================================

-- Negative or zero sales (should not happen)
SELECT 'Negative or zero sales' AS check_name,
       COUNT(*) AS row_count
FROM RAW.raw_orders
WHERE TRY_CAST(sales AS FLOAT) <= 0;

-- Negative quantity
SELECT 'Negative quantity' AS check_name,
       COUNT(*) AS row_count
FROM RAW.raw_orders
WHERE TRY_CAST(quantity AS INTEGER) <= 0;

-- Discount out of range (should be 0.0 to 1.0)
SELECT 'Discount out of range' AS check_name,
       COUNT(*) AS row_count
FROM RAW.raw_orders
WHERE TRY_CAST(discount AS FLOAT) < 0
   OR TRY_CAST(discount AS FLOAT) > 1;

-- Ship date before order date (impossible)
SELECT 'Ship before order date' AS check_name,
       COUNT(*) AS row_count
FROM RAW.raw_orders
WHERE TRY_TO_DATE(ship_date, 'DD/MM/YYYY') < TRY_TO_DATE(order_date, 'DD/MM/YYYY');

-- Days to ship negative or unreasonably long (> 30 days)
SELECT 'Days to ship > 30' AS check_name,
       COUNT(*) AS row_count
FROM RAW.raw_orders
WHERE DATEDIFF('day',
    TRY_TO_DATE(order_date, 'DD/MM/YYYY'),
    TRY_TO_DATE(ship_date,  'DD/MM/YYYY')) > 30;

-- Invalid returned values (only YES/NO/blank expected)
SELECT 'Unexpected returned values' AS check_name,
       returned,
       COUNT(*) AS row_count
FROM RAW.raw_orders
WHERE UPPER(TRIM(returned)) NOT IN ('YES', 'NO', 'Y', 'N', 'TRUE', 'FALSE', '1', '0', '')
  AND returned IS NOT NULL
GROUP BY returned;


-- ============================================================
-- SECTION 5: UNIQUENESS CHECKS
-- ============================================================

-- How many distinct values per key column
SELECT
    COUNT(DISTINCT order_id)            AS distinct_orders,
    COUNT(DISTINCT customer_id)         AS distinct_customers,
    COUNT(DISTINCT product_id)          AS distinct_products,
    COUNT(DISTINCT category)            AS distinct_categories,
    COUNT(DISTINCT sub_category)        AS distinct_sub_categories,
    COUNT(DISTINCT region)              AS distinct_regions,
    COUNT(DISTINCT state)               AS distinct_states,
    COUNT(DISTINCT city)                AS distinct_cities,
    COUNT(DISTINCT ship_mode)           AS distinct_ship_modes,
    COUNT(DISTINCT segment)             AS distinct_segments,
    COUNT(DISTINCT retail_sales_people) AS distinct_sales_people
FROM RAW.raw_orders;

-- Distinct values for low-cardinality columns (spot unexpected values)
SELECT 'category'   AS column_name, TRIM(category)   AS value, COUNT(*) AS row_count FROM RAW.raw_orders GROUP BY TRIM(category)   ORDER BY 1, 3 DESC;
SELECT 'sub_category',               TRIM(sub_category),        COUNT(*) FROM RAW.raw_orders GROUP BY TRIM(sub_category) ORDER BY 1, 3 DESC;
SELECT 'region',                     TRIM(region),              COUNT(*) FROM RAW.raw_orders GROUP BY TRIM(region)       ORDER BY 1, 3 DESC;
SELECT 'segment',                    TRIM(segment),             COUNT(*) FROM RAW.raw_orders GROUP BY TRIM(segment)      ORDER BY 1, 3 DESC;
SELECT 'ship_mode',                  TRIM(ship_mode),           COUNT(*) FROM RAW.raw_orders GROUP BY TRIM(ship_mode)    ORDER BY 1, 3 DESC;


-- ============================================================
-- SECTION 6: DATE RANGE CHECKS
-- ============================================================

-- Order date range — confirm it matches expected period
SELECT
    MIN(TRY_TO_DATE(order_date, 'DD/MM/YYYY')) AS earliest_order,
    MAX(TRY_TO_DATE(order_date, 'DD/MM/YYYY')) AS latest_order,
    DATEDIFF('day',
        MIN(TRY_TO_DATE(order_date, 'DD/MM/YYYY')),
        MAX(TRY_TO_DATE(order_date, 'DD/MM/YYYY'))
    )                                           AS date_span_days
FROM RAW.raw_orders;

-- Rows where date could not be parsed (returns NULL after cast)
SELECT 'Unparseable order_date' AS check_name,
       COUNT(*) AS row_count
FROM RAW.raw_orders
WHERE order_date IS NOT NULL
  AND TRY_TO_DATE(order_date, 'DD/MM/YYYY') IS NULL;

SELECT 'Unparseable ship_date' AS check_name,
       COUNT(*) AS row_count
FROM RAW.raw_orders
WHERE ship_date IS NOT NULL
  AND TRY_TO_DATE(ship_date, 'DD/MM/YYYY') IS NULL;


-- ============================================================
-- SECTION 7: NUMERIC RANGE SUMMARY
-- ============================================================

-- Min / max / avg for all numeric columns to spot outliers
SELECT
    ROUND(MIN(TRY_CAST(sales    AS FLOAT)), 2) AS min_sales,
    ROUND(MAX(TRY_CAST(sales    AS FLOAT)), 2) AS max_sales,
    ROUND(AVG(TRY_CAST(sales    AS FLOAT)), 2) AS avg_sales,
    ROUND(MIN(TRY_CAST(quantity AS FLOAT)), 0) AS min_qty,
    ROUND(MAX(TRY_CAST(quantity AS FLOAT)), 0) AS max_qty,
    ROUND(AVG(TRY_CAST(quantity AS FLOAT)), 1) AS avg_qty,
    ROUND(MIN(TRY_CAST(discount AS FLOAT)), 2) AS min_discount,
    ROUND(MAX(TRY_CAST(discount AS FLOAT)), 2) AS max_discount,
    ROUND(MIN(TRY_CAST(profit   AS FLOAT)), 2) AS min_profit,
    ROUND(MAX(TRY_CAST(profit   AS FLOAT)), 2) AS max_profit,
    ROUND(AVG(TRY_CAST(profit   AS FLOAT)), 2) AS avg_profit
FROM RAW.raw_orders;


-- ============================================================
-- SECTION 8: FACT TABLE FINAL CHECK
-- Compare raw vs fact row counts — difference = rows dropped
-- ============================================================

SELECT
    raw.total                            AS raw_rows,
    fact.total                           AS fact_rows,
    raw.total - fact.total               AS rows_dropped,
    ROUND((raw.total - fact.total)
        / raw.total * 100, 2)            AS dropped_pct
FROM
    (SELECT COUNT(*) AS total FROM RAW.raw_orders)    raw,
    (SELECT COUNT(*) AS total FROM ANALYTICS.fact_orders) fact;


-- ============================================================
-- SECTION 9: SUMMARY SCORECARD
-- Single view of all critical checks — aim for 0 on all
-- ============================================================

SELECT check_name, result, status FROM (
    SELECT 'Null order_id'            AS check_name, COUNT(*) AS result, IFF(COUNT(*)=0,'PASS','FAIL') AS status FROM RAW.raw_orders WHERE order_id IS NULL            UNION ALL
    SELECT 'Null customer_id',                        COUNT(*),           IFF(COUNT(*)=0,'PASS','FAIL')            FROM RAW.raw_orders WHERE customer_id IS NULL          UNION ALL
    SELECT 'Null product_id',                         COUNT(*),           IFF(COUNT(*)=0,'PASS','FAIL')            FROM RAW.raw_orders WHERE product_id IS NULL           UNION ALL
    SELECT 'Null sales',                              COUNT(*),           IFF(COUNT(*)=0,'PASS','FAIL')            FROM RAW.raw_orders WHERE sales IS NULL                UNION ALL
    SELECT 'Null profit',                             COUNT(*),           IFF(COUNT(*)=0,'PASS','FAIL')            FROM RAW.raw_orders WHERE profit IS NULL               UNION ALL
    SELECT 'Null order_date',                         COUNT(*),           IFF(COUNT(*)=0,'PASS','FAIL')            FROM RAW.raw_orders WHERE order_date IS NULL           UNION ALL
    SELECT 'Duplicate row_id',                        COUNT(*) - COUNT(DISTINCT row_id), IFF(COUNT(*)-COUNT(DISTINCT row_id)=0,'PASS','FAIL') FROM RAW.raw_orders        UNION ALL
    SELECT 'Negative sales',                          COUNT(*),           IFF(COUNT(*)=0,'PASS','FAIL')            FROM RAW.raw_orders WHERE TRY_CAST(sales AS FLOAT) < 0 UNION ALL
    SELECT 'Negative quantity',                       COUNT(*),           IFF(COUNT(*)=0,'PASS','FAIL')            FROM RAW.raw_orders WHERE TRY_CAST(quantity AS INTEGER) < 0 UNION ALL
    SELECT 'Ship before order',                       COUNT(*),           IFF(COUNT(*)=0,'PASS','FAIL')            FROM RAW.raw_orders WHERE TRY_TO_DATE(ship_date,'DD/MM/YYYY') < TRY_TO_DATE(order_date,'DD/MM/YYYY') UNION ALL
    SELECT 'Unparseable order_date',                  COUNT(*),           IFF(COUNT(*)=0,'PASS','FAIL')            FROM RAW.raw_orders WHERE order_date IS NOT NULL AND TRY_TO_DATE(order_date,'DD/MM/YYYY') IS NULL
)
ORDER BY status DESC, result DESC;
