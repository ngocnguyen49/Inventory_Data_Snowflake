-- ============================================================
-- BRONZE LAYER: Setup and Load
-- Purpose: Create infrastructure and load raw CSV into Snowflake
--          exactly as-is — no transformations, full audit trail
-- Output:  RAW.raw_orders (all 23 columns as STRING)
-- ============================================================

-- ── Database and Schema Setup ────────────────────────────────
CREATE DATABASE IF NOT EXISTS PIPELINE_DB;
USE DATABASE PIPELINE_DB;

CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS ANALYTICS;

-- ── Warehouse Setup ──────────────────────────────────────────
CREATE WAREHOUSE IF NOT EXISTS PIPELINE_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE;

USE WAREHOUSE PIPELINE_WH;
USE SCHEMA RAW;

-- ── Internal Stage ───────────────────────────────────────────
CREATE STAGE IF NOT EXISTS csv_stage
    FILE_FORMAT = (
        TYPE                         = 'CSV'
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        SKIP_HEADER                  = 1
        NULL_IF                      = ('NULL', 'null', '')
        EMPTY_FIELD_AS_NULL          = TRUE
        DATE_FORMAT                  = 'AUTO'
        TIMESTAMP_FORMAT             = 'AUTO'
    );

-- ── Bronze Table (all columns as STRING — no transformations) ─
-- Preserves original data exactly as received from source
-- Never update or delete from this table — append only
CREATE TABLE IF NOT EXISTS RAW.raw_orders (
    row_id              STRING,
    order_id            STRING,
    order_date          STRING,
    ship_date           STRING,
    ship_mode           STRING,
    customer_id         STRING,
    customer_name       STRING,
    segment             STRING,
    country             STRING,
    city                STRING,
    state               STRING,
    postal_code         STRING,
    region              STRING,
    retail_sales_people STRING,
    product_id          STRING,
    category            STRING,
    sub_category        STRING,
    product_name        STRING,
    returned            STRING,
    sales               STRING,
    quantity            STRING,
    discount            STRING,
    profit              STRING,
    _loaded_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ── Load CSV into Bronze ──────────────────────────────────────
-- Run this after uploading CSV to stage via:
-- PUT file://path/to/sample_data.csv @csv_stage;
COPY INTO RAW.raw_orders (
    row_id, order_id, order_date, ship_date, ship_mode,
    customer_id, customer_name, segment, country, city,
    state, postal_code, region, retail_sales_people,
    product_id, category, sub_category, product_name,
    returned, sales, quantity, discount, profit
)
FROM @csv_stage
FILE_FORMAT = (
    TYPE                         = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER                  = 1
    NULL_IF                      = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL          = TRUE
)
ON_ERROR = 'CONTINUE';
-- ON_ERROR = CONTINUE logs bad rows without stopping the load
-- Review load errors with: SELECT * FROM TABLE(VALIDATE(raw_orders, JOB_ID => '_last'));

-- ── Verify Bronze load ────────────────────────────────────────
SELECT COUNT(*)    AS total_rows_loaded FROM RAW.raw_orders;
SELECT *           FROM RAW.raw_orders LIMIT 5;
