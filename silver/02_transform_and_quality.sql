-- ============================================================
-- SILVER LAYER: Transform, Clean, Validate
-- Purpose: Clean and validate Bronze data, derive business columns,
--          and materialize a trusted fact table for Gold
-- Input:   RAW.raw_orders (Bronze)
-- Output:  ANALYTICS.stg_orders (Silver view)
--          ANALYTICS.fact_orders (Silver materialized table)
-- ============================================================

USE DATABASE PIPELINE_DB;
USE WAREHOUSE PIPELINE_WH;

-- ── Step 1: Inspect Bronze columns from INFER_SCHEMA ─────────
-- Confirm column names and types before transforming
SELECT
    column_name,
    data_type,
    ordinal_position
FROM PIPELINE_DB.information_schema.columns
WHERE table_schema = 'RAW'
  AND table_name   = 'RAW_ORDERS'
ORDER BY ordinal_position;

-- ── Step 2: Preview Bronze data ──────────────────────────────
SELECT * FROM RAW.raw_orders LIMIT 10;

-- ── Step 3: Quality checks on Bronze ─────────────────────────
-- All checks must PASS before Silver is built

-- CHECK 1: Row count
SELECT
    'Row Count'             AS check_name,
    COUNT(*)                AS total_rows,
    CASE WHEN COUNT(*) > 0
         THEN 'PASS ✅'
         ELSE 'FAIL ❌'
    END                     AS result
FROM RAW.raw_orders;

-- CHECK 2: Full duplicate rows
SELECT
    'Duplicate Rows'        AS check_name,
    COUNT(*) - COUNT(DISTINCT HASH(*)) AS duplicate_count,
    CASE WHEN COUNT(*) - COUNT(DISTINCT HASH(*)) = 0
         THEN 'PASS ✅'
         ELSE 'FAIL ❌'
    END                     AS result
FROM RAW.raw_orders;

-- CHECK 3: Null check on critical columns
SELECT
    'Null Check'            AS check_name,
    SUM(CASE WHEN order_id   IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN sales      IS NULL THEN 1 ELSE 0 END) AS null_sales,
    SUM(CASE WHEN profit     IS NULL THEN 1 ELSE 0 END) AS null_profit,
    SUM(CASE WHEN quantity   IS NULL THEN 1 ELSE 0 END) AS null_quantity,
    CASE WHEN
        SUM(CASE WHEN order_id   IS NULL THEN 1 ELSE 0 END) = 0
        AND SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) = 0
        AND SUM(CASE WHEN sales  IS NULL THEN 1 ELSE 0 END) = 0
        AND SUM(CASE WHEN profit IS NULL THEN 1 ELSE 0 END) = 0
        AND SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS ✅' ELSE 'FAIL ❌'
    END                     AS result
FROM RAW.raw_orders;

-- CHECK 4: Negative sales
SELECT
    'Negative Sales'        AS check_name,
    SUM(CASE WHEN TRY_CAST(sales AS FLOAT) < 0 THEN 1 ELSE 0 END) AS negative_count,
    CASE WHEN SUM(CASE WHEN TRY_CAST(sales AS FLOAT) < 0 THEN 1 ELSE 0 END) = 0
         THEN 'PASS ✅' ELSE 'FAIL ❌'
    END                     AS result
FROM RAW.raw_orders;

-- CHECK 5: Date range sanity
SELECT
    'Date Range'            AS check_name,
    MIN(TRY_TO_DATE(order_date, 'MM/DD/YYYY')) AS earliest_order,
    MAX(TRY_TO_DATE(order_date, 'MM/DD/YYYY')) AS latest_order,
    CASE WHEN MIN(TRY_TO_DATE(order_date, 'MM/DD/YYYY')) IS NOT NULL
         THEN 'PASS ✅' ELSE 'FAIL ❌'
    END                     AS result
FROM RAW.raw_orders;

-- CHECK 6: Load timestamp present
SELECT
    'Load Timestamp'        AS check_name,
    SUM(CASE WHEN _loaded_at IS NULL THEN 1 ELSE 0 END) AS missing_count,
    MIN(_loaded_at)         AS earliest_load,
    MAX(_loaded_at)         AS latest_load,
    CASE WHEN SUM(CASE WHEN _loaded_at IS NULL THEN 1 ELSE 0 END) = 0
         THEN 'PASS ✅' ELSE 'FAIL ❌'
    END                     AS result
FROM RAW.raw_orders;

-- SCORECARD: All checks in one view
SELECT * FROM (
    SELECT 'Row Count'          AS check_name,
           CASE WHEN COUNT(*) > 0 
                THEN 'PASS ✅' ELSE 'FAIL ❌' END AS result
    FROM RAW.raw_orders
    UNION ALL
    SELECT 'No Duplicates',
           CASE WHEN COUNT(*) = COUNT(DISTINCT HASH(*))
                THEN 'PASS ✅' ELSE 'FAIL ❌' END
    FROM RAW.raw_orders
    UNION ALL
    SELECT 'No Null Order IDs',
           CASE WHEN SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) = 0
                THEN 'PASS ✅' ELSE 'FAIL ❌' END
    FROM RAW.raw_orders
    UNION ALL
    SELECT 'No Null Sales',
           CASE WHEN SUM(CASE WHEN sales IS NULL THEN 1 ELSE 0 END) = 0
                THEN 'PASS ✅' ELSE 'FAIL ❌' END
    FROM RAW.raw_orders
    UNION ALL
    SELECT 'No Negative Sales',
           CASE WHEN SUM(CASE WHEN TRY_CAST(sales AS FLOAT) < 0 THEN 1 ELSE 0 END) = 0
                THEN 'PASS ✅' ELSE 'FAIL ❌' END
    FROM RAW.raw_orders
    UNION ALL
    SELECT 'Valid Dates',
           CASE WHEN SUM(CASE WHEN TRY_TO_DATE(order_date, 'MM/DD/YYYY') IS NULL THEN 1 ELSE 0 END) = 0
                THEN 'PASS ✅' ELSE 'FAIL ❌' END
    FROM RAW.raw_orders
    UNION ALL
    SELECT 'Load Timestamp Present',
           CASE WHEN SUM(CASE WHEN _loaded_at IS NULL THEN 1 ELSE 0 END) = 0
                THEN 'PASS ✅' ELSE 'FAIL ❌' END
    FROM RAW.raw_orders
)
ORDER BY check_name;

-- ── Step 4: Create Silver view ────────────────────────────────
-- Only run after all scorecard checks show PASS
CREATE OR REPLACE VIEW ANALYTICS.stg_orders AS
SELECT
    -- IDs
    TRIM(row_id)                                        AS row_id,
    TRIM(order_id)                                      AS order_id,
    TRIM(customer_id)                                   AS customer_id,
    TRIM(product_id)                                    AS product_id,

    -- Dates — cast from string to date
    TRY_TO_DATE(order_date, 'MM/DD/YYYY')               AS order_date,
    TRY_TO_DATE(ship_date, 'MM/DD/YYYY')                AS ship_date,

    -- Derived date columns for Gold aggregations
    EXTRACT(YEAR  FROM TRY_TO_DATE(order_date, 'MM/DD/YYYY')) AS order_year,
    EXTRACT(MONTH FROM TRY_TO_DATE(order_date, 'MM/DD/YYYY')) AS order_month,

    -- Shipping
    TRIM(ship_mode)                                     AS ship_mode,
    DATEDIFF('day',
        TRY_TO_DATE(order_date, 'MM/DD/YYYY'),
        TRY_TO_DATE(ship_date,  'MM/DD/YYYY'))          AS days_to_ship,

    -- Customer
    TRIM(customer_name)                                 AS customer_name,
    TRIM(segment)                                       AS segment,

    -- Location
    TRIM(country)                                       AS country,
    TRIM(city)                                          AS city,
    TRIM(state)                                         AS state,
    TRIM(postal_code)                                   AS postal_code,
    TRIM(region)                                        AS region,

    -- People
    TRIM(retail_sales_people)                           AS retail_sales_people,

    -- Product
    TRIM(category)                                      AS category,
    TRIM(sub_category)                                  AS sub_category,
    TRIM(product_name)                                  AS product_name,

    -- Returns
    CASE WHEN UPPER(TRIM(returned)) = 'YES'
         THEN TRUE ELSE FALSE END                       AS is_returned,

    -- Numerics — safe cast
    TRY_CAST(sales    AS FLOAT)                         AS sales,
    TRY_CAST(profit   AS FLOAT)                         AS profit,
    TRY_CAST(quantity AS INT)                           AS quantity,
    TRY_CAST(discount AS FLOAT)                         AS discount,

    -- Derived business metrics
    ROUND(
        TRY_CAST(profit AS FLOAT) /
        NULLIF(TRY_CAST(sales AS FLOAT), 0) * 100
    , 2)                                                AS profit_margin_pct,

    -- Lineage timestamps
    _loaded_at                                          AS _bronze_loaded_at,
    CURRENT_TIMESTAMP()                                 AS _silver_processed_at

FROM RAW.raw_orders

-- Exclude rows where critical business columns failed to cast
WHERE TRY_CAST(sales    AS FLOAT) IS NOT NULL
  AND TRY_CAST(profit   AS FLOAT) IS NOT NULL
  AND TRY_CAST(quantity AS INT)   IS NOT NULL
  AND TRY_TO_DATE(order_date, 'MM/DD/YYYY') IS NOT NULL;

-- ── Step 5: Materialize Silver ────────────────────────────────
-- Physical table for Gold to build on — faster than querying view
CREATE OR REPLACE TABLE ANALYTICS.fact_orders AS
SELECT * FROM ANALYTICS.stg_orders;

-- ── Verify Silver ─────────────────────────────────────────────
SELECT COUNT(*) AS silver_rows  FROM ANALYTICS.fact_orders;
SELECT COUNT(*) AS bronze_rows  FROM RAW.raw_orders;

SELECT
    (SELECT COUNT(*) FROM RAW.raw_orders) -
    (SELECT COUNT(*) FROM ANALYTICS.fact_orders) AS rows_excluded;

SELECT * FROM ANALYTICS.fact_orders LIMIT 5;
