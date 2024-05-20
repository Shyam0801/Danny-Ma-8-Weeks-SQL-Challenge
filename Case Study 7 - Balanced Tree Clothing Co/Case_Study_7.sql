----------------------------------------------------------------

	       ------- CASE STUDY 7 SOLUTIONS --------

-----------------------------------------------------------------

/* 

What was the total quantity sold for all products?
What is the total generated revenue for all products before discounts?
What was the total discount amount for all products?

*/

-- What was the total quantity sold for all products?

SELECT SUM(qty) as total_quantity_sold
FROM sales_b_tree;

-- What is the total generated revenue for all products before discounts?

SELECT SUM(qty * price) as total_revenue
FROM sales_b_tree;

-- What was the total discount amount for all products?

SELECT SUM(discount) as total_discount
FROM sales_b_tree;

/* 

Transaction Analysis
How many unique transactions were there?
What is the average unique products purchased in each transaction?
What are the 25th, 50th and 75th percentile values for the revenue per transaction?
What is the average discount value per transaction?
What is the percentage split of all transactions for members vs non-members?
What is the average revenue for member transactions and non-member transactions?

*/

-- How many unique transactions were there?

SELECT COUNT(DISTINCT txn_id) as unique_transactions
FROM sales_b_tree;

-- What is the average unique products purchased in each transaction?

SELECT AVG(x.unique_products) as avg_unique_products
FROM(
SELECT txn_id, COUNT(DISTINCT prod_id) as unique_products
FROM sales_b_tree
GROUP BY txn_id)x;

-- What are the 25th, 50th and 75th percentile values for the revenue per transaction?

with total_cte as(
SELECT txn_id, SUM(qty * price) as revenue_per_trans
FROM sales_b_tree
GROUP BY txn_id)

SELECT DISTINCT
PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue_per_trans) OVER() as percentile_25th,
PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY revenue_per_trans) OVER() as percentile_50th,
PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue_per_trans) OVER() as percentile_75th
FROM total_cte;

-- What is the average discount value per transaction?

SELECT avg(total_discount) as average_discount
FROM(
SELECT txn_id, SUM(discount) as total_discount
FROM sales_b_tree
GROUP BY txn_id)x;

-- What is the percentage split of all transactions for members vs non-members?

SELECT 100.0 * COUNT(DISTINCT CASE WHEN member = 1 THEN txn_id END) / COUNT(DISTINCT txn_id) as member_percentage,
	   100.0 * COUNT(DISTINCT CASE WHEN member = 0 THEN txn_id END) / COUNT(DISTINCT txn_id) as non_member_percentage
FROM sales_b_tree

-- What is the average revenue for member transactions and non-member transactions?

SELECT member, AVG(total_revenue) as avg_transaction
FROM(
SELECT member, txn_id, SUM(qty*price) as total_revenue
FROM sales_b_tree
GROUP BY member, txn_id)x
GROUP BY x.member

/* 
Product Analysis
What are the top 3 products by total revenue before discount?
What is the total quantity, revenue and discount for each segment?
What is the top selling product for each segment?
What is the total quantity, revenue and discount for each category?
What is the top selling product for each category?
What is the percentage split of revenue by product for each segment?
What is the percentage split of revenue by segment for each category?
What is the percentage split of total revenue by category?
What is the total transaction “penetration” for each product? (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)
What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
*/

-- What are the top 3 products by total revenue before discount?

SELECT TOP 3 p.product_name, SUM(s.qty * s.price) as total_revenue
FROM sales_b_tree s
JOIN product_details p 
ON s.prod_id = p.product_id
GROUP BY p.product_name
ORDER BY total_revenue DESC;

-- What is the total quantity, revenue and discount for each segment?

SELECT p.segment_name, SUM(s.qty) as total_quantity, SUM(s.qty * s.price) as total_revenue, SUM(s.discount) as total_discount
FROM sales_b_tree s
JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY p.segment_name;

-- What is the top selling product for each segment?

SELECT x.segment_name, x.product_name, x.total_quantity, x.total_price
FROM(
SELECT p.segment_name, p.product_name, SUM(s.qty) as total_quantity, SUM(s.price) as total_price,
	   DENSE_RANK() OVER(PARTITION BY p.segment_name ORDER BY SUM(s.qty) DESC) as ranking
FROM sales_b_tree s
JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY p.segment_name, p.product_name)x
WHERE x.ranking = 1;

-- What is the total quantity, revenue and discount for each category?

SELECT p.category_name, SUM(s.qty) AS total_quantity, SUM(s.qty * s.price) as total_price, SUM(s.discount) as total_discount
FROM sales_b_tree s
JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY p.category_name;

-- What is the top selling product for each category?

SELECT x.category_name, x.product_name, x.total_quantity, x.total_price
FROM(
SELECT p.category_name, p.product_name, SUM(s.qty) as total_quantity, SUM(s.price) as total_price,
	   DENSE_RANK() OVER(PARTITION BY p.category_name ORDER BY SUM(s.qty) DESC) as ranking
FROM sales_b_tree s
JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY p.category_name, p.product_name)x
WHERE x.ranking = 1;

-- What is the percentage split of revenue by product for each segment?

WITH segment_total_sales AS (
    SELECT p.segment_name, SUM(s.qty * s.price) as segment_total_sales
    FROM sales_b_tree s
    JOIN product_details p ON s.prod_id = p.product_id
    GROUP BY p.segment_name
),
product_wise_sales AS (
    SELECT p.segment_name, p.product_name, SUM(s.qty * s.price) as product_total_sales
    FROM sales_b_tree s
    JOIN product_details p ON s.prod_id = p.product_id
    GROUP BY p.segment_name, p.product_name
)
SELECT pw.segment_name, pw.product_name,
       CAST(100.0 * pw.product_total_sales / sts.segment_total_sales AS DECIMAL(10,2)) as percentage_of_total_sales
FROM product_wise_sales pw
JOIN segment_total_sales sts ON pw.segment_name = sts.segment_name
ORDER BY percentage_of_total_sales DESC;

-- What is the percentage split of revenue by segment for each category?

WITH category_total_sales AS (
    SELECT p.category_name, SUM(s.qty * s.price) as category_total_sales
    FROM sales_b_tree s
    JOIN product_details p ON s.prod_id = p.product_id
    GROUP BY p.category_name
),
segment_wise_sales AS (
    SELECT p.category_name, p.segment_name, SUM(s.qty * s.price) as segment_total_sales
    FROM sales_b_tree s
    JOIN product_details p ON s.prod_id = p.product_id
    GROUP BY p.category_name, p.segment_name
)
SELECT sw.segment_name, sw.category_name,
       CAST(100.0 * sw.segment_total_sales / cts.category_total_sales AS DECIMAL(10,2)) as percentage_of_total_sales
FROM segment_wise_sales sw
JOIN category_total_sales cts ON sw.category_name = cts.category_name
ORDER BY percentage_of_total_sales DESC;


-- What is the percentage split of total revenue by category?

WITH category_revenue AS (
  SELECT 
    p.category_name,
    SUM(s.qty * s.price) AS revenue
  FROM sales_b_tree s
  JOIN product_details p
    ON s.prod_id = p.product_id
  GROUP BY p.category_name
)

SELECT 
  category_name,
  CAST(100.0 * revenue / SUM(revenue) OVER () AS decimal (10, 2)) AS category_pct
FROM category_revenue;


-- What is the total transaction “penetration” for each product? 
-- (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)

WITH product_transations AS (
  SELECT 
    DISTINCT s.prod_id, pd.product_name,
    COUNT(DISTINCT s.txn_id) AS product_txn,
    (SELECT COUNT(DISTINCT txn_id) FROM sales_b_tree) AS total_txn
  FROM sales_b_tree s
  JOIN product_details pd 
    ON s.prod_id = pd.product_id
  GROUP BY prod_id, pd.product_name
)

SELECT 
  *,
  CAST(100.0 * product_txn / total_txn AS decimal(10,2)) AS penetration_pct
FROM product_transations;

-- What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?

SELECT
    CONCAT(product_1,', ', product_2, ', ', product_3) as product_ids, CONCAT(product_name_1,', ', product_name_2,', ', product_name_3) as product_namess,
    COUNT(DISTINCT txn_id) as times_together
FROM (
    SELECT s1.txn_id, s1.prod_id as product_1, s2.prod_id as product_2, s3.prod_id as product_3,
        p1.product_name as product_name_1, p2.product_name as product_name_2, p3.product_name as product_name_3
    FROM sales_b_tree s1
    JOIN sales_b_tree s2 ON s1.txn_id = s2.txn_id
    JOIN sales_b_tree s3 ON s2.txn_id = s3.txn_id
    JOIN product_details p1 ON s1.prod_id = p1.product_id
    JOIN product_details p2 ON s2.prod_id = p2.product_id
    JOIN product_details p3 ON s3.prod_id = p3.product_id
    WHERE s1.prod_id <> s2.prod_id AND s2.prod_id <> s3.prod_id AND s1.prod_id <> s3.prod_id
	AND s1.prod_id < s2.prod_id AND s2.prod_id < s3.prod_id
) temp
GROUP BY CONCAT(product_1,', ', product_2, ', ', product_3), CONCAT(product_name_1,', ', product_name_2,', ', product_name_3)
ORDER BY times_together DESC;

