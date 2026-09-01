Markdown
# Inventory Data Warehouse & Analytics (Snowflake)

An end-to-end data engineering and business intelligence project built using a **Medallion Architecture** in Snowflake. The pipeline ingests raw inventory data, performs Python-based pre-validation, cleans and transforms data through progressive SQL layers, and serves analytics via Power BI.

---

## 🏗️ Architecture & Data Pipeline

The project follows the standard **Medallion Architecture** design:

1. **Python Pre-validation (`python/`):** Validates raw datasets prior to warehouse ingestion.
2. **Bronze Layer (`bronze/`):** Raw data ingestion, environment setup, and raw table creation in Snowflake.
3. **Silver Layer (`silver/`):** Data cleaning, transformations, deduplication, and data quality checks.
4. **Gold Layer (`gold/`):** Business-level aggregations and analytical data models ready for reporting.
5. **Visualization (`power/`):** Business intelligence dashboards connected to Snowflake Gold views.

---

## 📂 Repository Structure

```text
.
├── python/     # 00_pre_load_validation.py (Pre-ingestion data validation & checks)
├── bronze/     # 01_setup_and_load.sql (DDL, Snowflake stage setup, raw data loading)
├── silver/     # 02_transform_and_quality.sql (Cleaning, standardization, quality checks)
├── gold/       # 03_aggregations.sql (Business logic, metrics, and KPI aggregations)
└── power/      # Power BI report files and visualization assets
