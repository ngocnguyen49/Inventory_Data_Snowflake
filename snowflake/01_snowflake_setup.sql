-- ============================================================
-- 01_snowflake_setup.sql
-- Create database, schema, stage, and raw table
-- ============================================================

CREATE DATABASE IF NOT EXISTS PIPELINE_DB;
USE DATABASE PIPELINE_DB;

CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS ANALYTICS;

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

-- ── Raw Table  (all columns kept as STRING for safe loading) ─
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
