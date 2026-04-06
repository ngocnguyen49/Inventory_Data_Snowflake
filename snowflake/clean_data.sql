CREATE OR REPLACE VIEW retail_supply_data AS
SELECT
    order_id,
    order_date,
    ship_date,
    DATEDIFF('day', order_date, ship_date) AS shipping_days,
    
    customer_id,
    customer_name,
    segment,
    
    country,
    region,
    state,
    city,
    
    product_id,
    category,
    sub_category,
    product_name,
    
    quantity,
    sales,
    profit,
    discount,
    
    CASE 
        WHEN returned = 'Yes' THEN 1 
        ELSE 0 
    END AS is_returned,
    
    sales / NULLIF(quantity, 0) AS price_per_unit
FROM retail_supply_data;
