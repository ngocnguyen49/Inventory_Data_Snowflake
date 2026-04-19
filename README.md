# Sales Analytics Pipeline
### CSV → Snowflake → Power BI

A simple end-to-end data pipeline that loads retail sales data from CSV into Snowflake, transforms it into analytics-ready tables, and visualises it in Power BI.

---

## Pipeline overview

```
CSV File  →  Snowflake Stage  →  Raw Table  →  Transform  →  Power BI Dashboard
```

---

## Repository structure

```
sales-analytics-pipeline/
│
├── data/
│   └── sample_data.csv                  # Sample dataset (23 columns)
│
├── snowflake/
│   ├── 01_snowflake_setup.sql           # Database, schema, stage, raw table
│   ├── 02_load_csv_snowflake_only.sql   # Upload CSV and COPY INTO
│   ├── 03_transform.sql                 # Clean, cast, build analytics tables
│   └── 05_data_quality_checks.sql       # Null, duplicate, range checks
│
├── powerbi/
│   └── sales_dashboard.pbix             # Power BI dashboard file
│
├── .env.example                         # Credentials template
└── README.md
```

---

## Prerequisites

- Snowflake account (free trial works)
- Power BI Desktop (free download from Microsoft)

---

## Quick start

### Step 1 — Snowflake setup
Open `snowflake/01_snowflake_setup.sql` in Snowflake Worksheets and run it.
This creates the database, schema, stage, and raw table.

### Step 2 — Load your CSV
Upload your CSV via the Snowflake UI:
> Data → Databases → PIPELINE_DB → RAW → Stages → CSV_STAGE → + Files

Then run `snowflake/02_load_csv_snowflake_only.sql` to copy data into the raw table.

### Step 3 — Transform
Run `snowflake/03_transform.sql` to create:
- `ANALYTICS.fact_orders` — cleaned, typed, BI-ready fact table
- `ANALYTICS.agg_monthly_sales` — pre-aggregated monthly summary
- `ANALYTICS.agg_customer_summary` — per-customer totals

### Step 4 — Data quality check
Run `snowflake/05_data_quality_checks.sql` to validate the data.
All checks in Section 9 (scorecard) should show **PASS** before proceeding.

### Step 5 — Power BI
1. Open `powerbi/sales_dashboard.pbix` in Power BI Desktop
2. Go to **Home → Transform Data → Data Source Settings**
3. Update the Snowflake server to your account
4. Click **Refresh** — data loads from your Snowflake tables

---

## Data columns

| Column | Type | Description |
|--------|------|-------------|
| Row ID | Integer | Unique row identifier |
| Order ID | Text | Order identifier |
| Order Date | Date | Date order was placed |
| Ship Date | Date | Date order was shipped |
| Ship Mode | Text | Shipping method |
| Customer ID | Text | Customer identifier |
| Customer Name | Text | Customer full name |
| Segment | Text | Consumer / Corporate / Home Office |
| Country | Text | Country |
| City | Text | City |
| State | Text | State |
| Postal Code | Text | Postal code |
| Region | Text | East / West / Central / South |
| Retail Sales People | Text | Assigned sales person |
| Product ID | Text | Product identifier |
| Category | Text | Furniture / Technology / Office Supplies |
| Sub-Category | Text | Product sub-category |
| Product Name | Text | Full product name |
| Returned | Boolean | Whether order was returned |
| Sales | Decimal | Order sales amount |
| Quantity | Integer | Units ordered |
| Discount | Decimal | Discount applied (0.0 – 1.0) |
| Profit | Decimal | Profit amount |

---

## Snowflake objects created

```
PIPELINE_DB
├── RAW
│   └── raw_orders               ← staging table, all columns as STRING
└── ANALYTICS
    ├── vw_clean_orders           ← view: cleaned and cast
    ├── fact_orders               ← table: BI-ready fact table
    ├── agg_monthly_sales         ← table: monthly aggregation
    └── agg_customer_summary      ← table: per-customer totals
```

---

## Dashboard visuals

| Visual | Type | Source table |
|--------|------|--------------|
| Total Sales KPI | Card | fact_orders |
| Total Profit KPI | Card | fact_orders |
| Total Orders KPI | Card | fact_orders |
| Avg Profit Margin KPI | Card | fact_orders |
| Monthly sales trend | Bar / Line chart | agg_monthly_sales |
| Sales by category | Donut chart | fact_orders |
| Sales by sub-category | Bar chart | fact_orders |
| Profit by region | Bar chart | agg_monthly_sales |
| Discount vs profit | Scatter chart | fact_orders |
| Top 10 customers | Table | agg_customer_summary |
| Sales by ship mode | Bar chart | fact_orders |

---

## Notes

- Date format in the SQL is set to `DD/MM/YYYY` — update in `03_transform.sql` if your CSV uses a different format
- The `.pbix` file uses **Import mode** — refresh manually or set a scheduled refresh via Power BI Service
- Never commit your `.env` file — add it to `.gitignore`
