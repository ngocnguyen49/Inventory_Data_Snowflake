-- ============================================================
-- 02_load_csv_snowflake_only.sql
-- Upload CSV and COPY INTO raw_orders — runs entirely in
-- Snowflake Worksheets, no Python required
-- ============================================================

USE DATABASE PIPELINE_DB;
USE SCHEMA RAW;
USE WAREHOUSE PIPELINE_WH;

-- ============================================================
-- STEP 1: Upload your CSV file
-- ============================================================
-- Method
--   Go to Data → Databases → PIPELINE_DB → RAW → Stages → CSV_STAGE
--   Click "+ Files" and upload your CSV

-- ============================================================
-- STEP 2: Confirm the file is in the stage
-- ============================================================
LIST @csv_stage;

-- ============================================================
-- STEP 3: Preview first 10 rows before loading
-- ============================================================
SELECT
    $1  AS row_id,
    $2  AS order_id,
    $3  AS order_date,
    $4  AS ship_date,
    $5  AS ship_mode,
    $6  AS customer_id,
    $7  AS customer_name,
    $8  AS segment,
    $9  AS country,
    $10 AS city,
    $11 AS state,
    $12 AS postal_code,
    $13 AS region,
    $14 AS retail_sales_people,
    $15 AS product_id,
    $16 AS category,
    $17 AS sub_category,
    $18 AS product_name,
    $19 AS returned,
    $20 AS sales,
    $21 AS quantity,
    $22 AS discount,
    $23 AS profit
FROM @csv_stage
LIMIT 10;

-- ============================================================
-- STEP 4: COPY INTO raw table
-- ============================================================
COPY INTO RAW.raw_orders (
    row_id, order_id, order_date, ship_date, ship_mode,
    customer_id, customer_name, segment, country, city,
    state, postal_code, region, retail_sales_people,
    product_id, category, sub_category, product_name,
    returned, sales, quantity, discount, profit
)
FROM (
    SELECT
        $1, $2, $3, $4, $5,
        $6, $7, $8, $9, $10,
        $11, $12, $13, $14,
        $15, $16, $17, $18,
        $19, $20, $21, $22, $23
    FROM @csv_stage
)
FILE_FORMAT = (
    TYPE                         = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER                  = 1
    NULL_IF                      = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL          = TRUE
)
ON_ERROR = 'CONTINUE'
PURGE    = FALSE;

-- ============================================================
-- STEP 5: Verify the load
-- ============================================================

-- Total rows loaded
SELECT COUNT(*) AS total_rows FROM RAW.raw_orders;

-- Load history (errors, files, row counts)
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'RAW_ORDERS',
    START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;

-- Preview data
SELECT * FROM RAW.raw_orders LIMIT 20;
