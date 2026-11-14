CREATE VIEW rpt_product_sales AS
SELECT product_name,
       product_category,
       product_brand,
       count(*) AS sales_cnt,
       round(sum(sale_total_price), 2) AS total_revenue,
       round(avg(product_price), 2) AS avg_price,
       round(avg(product_rating), 2) AS avg_rating,
       round(avg(product_reviews), 2) AS avg_reviews
FROM mock_data
GROUP BY product_name, product_category, product_brand;

CREATE VIEW rpt_customer_sales AS
SELECT customer_first_name AS first_name,
       customer_last_name AS last_name,
       customer_email AS email,
       customer_country AS country,
       count(*) AS sales_cnt,
       round(sum(sale_total_price), 2) AS total_revenue,
       round(avg(sale_total_price), 2) AS avg_check
FROM mock_data
GROUP BY customer_first_name, customer_last_name, customer_email, customer_country;

CREATE VIEW rpt_time_sales AS
SELECT extract(year from sale_date)::integer AS year,
       extract(month from sale_date)::integer AS month,
       CASE extract(month from sale_date)::integer
           WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
           WHEN 4 THEN 'April' WHEN 5 THEN 'May' WHEN 6 THEN 'June'
           WHEN 7 THEN 'July' WHEN 8 THEN 'August' WHEN 9 THEN 'September'
           WHEN 10 THEN 'October' WHEN 11 THEN 'November' WHEN 12 THEN 'December'
       END AS month_name,
       count(*) AS sales_cnt,
       round(sum(sale_total_price), 2) AS total_revenue,
       round(avg(sale_total_price), 2) AS avg_order_size
FROM mock_data
GROUP BY 1, 2, 3;

CREATE VIEW rpt_store_sales AS
SELECT store_name,
       store_city,
       store_country,
       count(*) AS sales_cnt,
       round(sum(sale_total_price), 2) AS total_revenue,
       round(avg(sale_total_price), 2) AS avg_check
FROM mock_data
GROUP BY store_name, store_city, store_country;

CREATE VIEW rpt_supplier_sales AS
SELECT supplier_name,
       supplier_city,
       supplier_country,
       count(*) AS sales_cnt,
       round(sum(sale_total_price), 2) AS total_revenue,
       round(avg(product_price), 2) AS avg_product_price
FROM mock_data
GROUP BY supplier_name, supplier_city, supplier_country;

CREATE VIEW rpt_product_quality AS
SELECT product_name,
       product_category,
       product_brand,
       round(avg(product_rating), 2) AS avg_rating,
       round(avg(product_reviews), 2) AS avg_reviews,
       count(*) AS sales_cnt,
       round(sum(sale_total_price), 2) AS total_revenue
FROM mock_data
GROUP BY product_name, product_category, product_brand;
