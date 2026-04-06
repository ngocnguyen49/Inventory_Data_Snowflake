# 🛍️ Retail Chain Supply Analytics (Snowflake + Power BI)

## 🚀 Project Overview
This project demonstrates a simple end-to-end analytics workflow using Snowflake and Microsoft Power BI.

The dataset represents a retail chain supply dataset, containing information about orders, products, regions, and sales performance.  
The goal is to transform raw data into meaningful business insights through SQL and visualization.

---

## 🎯 Objectives
- Load and manage raw retail data in Snowflake  
- Perform basic data transformation using SQL  
- Analyze sales and supply performance  
- Build an interactive Power BI dashboard  

---

## 📂 Dataset Description
The dataset includes the following fields:

- `order_id` – Unique identifier for each order  
- `order_date` – Date of the transaction  
- `customer` – Customer name or ID  
- `product` – Product name  
- `region` – Sales region  
- `quantity` – Number of units sold  
- `sales` – Total revenue for the order  

---

## ❄️ Snowflake Implementation

### 1. Data Loading
- The raw CSV file is uploaded into a Snowflake table: `sales_data`

### 2. Data Transformation
- A cleaned view `sales_clean` is created to:
  - Standardize fields  
  - Calculate derived metrics (e.g., price per unit)  

### 3. Sample Analysis
Key SQL queries include:
- Revenue by region  
- Monthly sales trends  
- Product-level performance  

---

## 📊 Power BI Dashboard

The dashboard is built by connecting Power BI directly to Snowflake.

### Key Visuals:
- **Total Revenue KPI** – Overall business performance  
- **Revenue Trend (Line Chart)** – Sales over time  
- **Revenue by Region (Bar Chart)** – Regional comparison  
- **Top Products (Table)** – Best-performing products  

### Key Measures:
- Total Revenue  
- Average Price per Unit  

---

## 📈 Key Insights
- Revenue varies significantly across regions, highlighting top-performing markets  
- Sales show clear trends over time, indicating possible seasonality  
- A small number of products contribute a large share of total revenue  

---

## 🏗️ Architecture
CSV File
↓
Snowflake (Table → View)
↓
Power BI Dashboard

---

## ⚙️ How to Run the Project

1. Upload the dataset (`dataset.csv`) into Snowflake  
2. Run the SQL script in `snowflake/analysis.sql`  
3. Open the Power BI file (`report.pbix`)  
4. Refresh the data connection  

---

## 🧠 Skills Demonstrated

- SQL data transformation in Snowflake  
- Basic data modeling using views  
- Data visualization and DAX in Power BI  
- Business insight generation from raw data  

---

## 📌 Conclusion
This project shows how a single raw dataset can be transformed into actionable insights using modern data tools.  
It highlights the ability to work across the full analytics workflow—from data storage to business reporting.  



