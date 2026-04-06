# Revenue by Region
SELECT region, SUM(sales) AS revenue
FROM sales_clean
GROUP BY region
ORDER BY revenue DESC;

# Monthly Sales Trend
SELECT 
    DATE_TRUNC('month', order_date) AS month,
    SUM(sales) AS revenue
FROM sales_clean
GROUP BY month
ORDER BY month;

# Top Products
SELECT 
    product_name,
    SUM(sales) AS revenue
FROM sales_clean
GROUP BY product_name
ORDER BY revenue DESC
LIMIT 10;

# Profitability by Category
SELECT 
    category,
    SUM(sales) AS revenue,
    SUM(profit) AS profit
FROM sales_clean
GROUP BY category;

# Return Impact
SELECT 
    is_returned,
    COUNT(*) AS orders,
    SUM(sales) AS revenue
FROM sales_clean
GROUP BY is_returned;
