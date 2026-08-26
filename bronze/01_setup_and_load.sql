-- ============================================================
-- BRONZE LAYER: Automated Setup and S3 Load
-- Purpose: Create infrastructure, infer CSV schema dynamically from S3, 
--          and load raw data into Snowflake as an exact replica.
-- Output:  RAW.raw_orders (dynamically inferred columns)
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

-- ── External S3 Stage Setup ──────────────────────────────────
-- Replace placeholders with your S3 URI and AWS IAM credentials
CREATE OR REPLACE STAGE RAW.s3_csv_stage
    URL = 's3://your-bucket-name/path/to/files/'
    CREDENTIALS = (
        AWS_KEY_ID = 'YOUR_AWS_ACCESS_KEY_ID'
        AWS_SECRET_KEY = 'YOUR_AWS_SECRET_ACCESS_KEY'
    );

-- ── Named File Format Setup ───────────────────────────────────
-- Required for INFER_SCHEMA to accurately parse headers and fields
CREATE OR REPLACE FILE FORMAT RAW.csv_format
    TYPE                         = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER                  = 1
    NULL_IF                      = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL          = TRUE;

-- ── Automated Table Creation (INFER_SCHEMA) ───────────────────
-- Automatically detects all columns and data types directly from the CSV in S3
CREATE TABLE IF NOT EXISTS RAW.raw_orders
USING TEMPLATE (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
    FROM TABLE(
        INFER_SCHEMA(
            LOCATION => '@RAW.s3_csv_stage',
            FILE_FORMAT => 'RAW.csv_format'
        )
    )
);

-- Add metadata column to track load timing for auditability
ALTER TABLE RAW.raw_orders 
ADD COLUMN IF NOT EXISTS _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();

-- ── Load CSV into Bronze Table ───────────────────────────────
-- MATCH_BY_COLUMN_NAME guarantees safe loading even if CSV column order shifts
COPY INTO RAW.raw_orders
FROM @RAW.s3_csv_stage
FILE_FORMAT = (FORMAT_NAME = 'RAW.csv_format')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR = 'CONTINUE';

-- ── Verify Bronze Load ───────────────────────────────────────
SELECT COUNT(*) AS total_rows_loaded FROM RAW.raw_orders;
SELECT *        FROM RAW.raw_orders LIMIT 5;
