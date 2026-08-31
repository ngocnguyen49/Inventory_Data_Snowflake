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
    URL = 's3://my-snowflake-sales-pipeline-data/10.-Retail-Supply-Chain-Sales-Analysis_Challenge-10 - Retails Order Full Dataset.csv'
    CREDENTIALS = (
        AWS_KEY_ID = 'AKIASLSTLIM3B7QDMDLV'
        AWS_SECRET_KEY = '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'
    );

-- ── Named File Format Setup ───────────────────────────────────
-- PARSE_HEADER = TRUE reads first row as column names
-- Required for INFER_SCHEMA and MATCH_BY_COLUMN_NAME to work
CREATE OR REPLACE FILE FORMAT RAW.csv_format
    TYPE                         = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    PARSE_HEADER                 = TRUE
    NULL_IF                      = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL          = TRUE;

-- ── Step 1: Drop and recreate table from INFER_SCHEMA ─────────
-- Always drop first to avoid column mismatch errors on re-runs
DROP TABLE IF EXISTS RAW.raw_orders;

CREATE TABLE RAW.raw_orders
USING TEMPLATE (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
    FROM TABLE(
        INFER_SCHEMA(
            LOCATION    => '@RAW.s3_csv_stage',
            FILE_FORMAT => 'RAW.csv_format'
        )
    )
);

-- ── Step 2: Load CSV into Bronze ──────────────────────────────
-- Add _loaded_at AFTER table creation to avoid column mismatch
-- MATCH_BY_COLUMN_NAME handles any column order in CSV safely
COPY INTO RAW.raw_orders
FROM @RAW.s3_csv_stage
FILE_FORMAT = (FORMAT_NAME = 'RAW.csv_format')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR = 'CONTINUE';

-- ── Step 3: Add audit metadata column after load ──────────────
-- Must be added AFTER COPY INTO to avoid column count mismatch
ALTER TABLE RAW.raw_orders
ADD COLUMN IF NOT EXISTS _loaded_at TIMESTAMP_NTZ;

UPDATE RAW.raw_orders
SET _loaded_at = CURRENT_TIMESTAMP()
WHERE _loaded_at IS NULL;

-- ── Step 4: Verify Bronze load ────────────────────────────────
SELECT COUNT(*) AS total_rows_loaded FROM RAW.raw_orders;
SELECT *        FROM RAW.raw_orders LIMIT 5;
