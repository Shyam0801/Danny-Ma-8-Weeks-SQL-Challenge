----------------------------------------------------------

		-------- CASE STUDY 4 SOLUTIONS ----------

----------------------------------------------------------

SELECT * FROM regions;

SELECT * FROM customer_nodes;

SELECT * FROM customer_transactions;

----------------------------------------------------------
/* 

A. Customer Nodes Exploration
How many unique nodes are there on the Data Bank system?
What is the number of nodes per region?
How many customers are allocated to each region?
How many days on average are customers reallocated to a different node?
What is the median, 80th and 95th percentile for this same reallocation days metric for each region?

*/

-- How many unique nodes are there on the Data Bank system?

SELECT COUNT(DISTINCT node_id) as unique_nodes
FROM customer_nodes;

-- What is the number of nodes per region?

SELECT cn.region_id, r.region_name, COUNT(cn.node_id) as number_of_nodes
FROM customer_nodes cn
JOIN regions r
ON cn.region_id = r.region_id
GROUP BY cn.region_id, r.region_name
ORDER by cn.region_id;

-- How many customers are allocated to each region?

SELECT cn.region_id, r.region_name, COUNT(DISTINCT cn.customer_id) as customer_count
FROM customer_nodes cn
JOIN regions r
ON cn.region_id = r.region_id
GROUP BY cn.region_id, r.region_name
ORDER by cn.region_id;

-- How many days on average are customers reallocated to a different node?

SELECT AVG(days_stayed) as avg_days
FROM(
SELECT customer_id, region_id, node_id, 
	   SUM(DATEDIFF(day, start_date, end_date)) as days_stayed
FROM customer_nodes
WHERE end_date <> '9999-12-31'
GROUP BY customer_id, region_id, node_id) X;

-- What is the median, 80th and 95th percentile for this same reallocation days metric for each region?

with node_days as(
SELECT c.customer_id, r.region_id, r.region_name, c.node_id,
	   SUM(DATEDIFF(day, c.start_date, c.end_date)) as days_stayed
FROM customer_nodes c
JOIN regions r 
ON c.region_id = r.region_id
WHERE c.end_date <> '9999-12-31'
GROUP BY c.customer_id, r.region_id, c.node_id, r.region_name),

ranked as(
SELECT region_name, days_stayed,
	   ROW_NUMBER() OVER(PARTITION BY region_name ORDER BY days_stayed) as rn
FROM node_days),

counted as(
SELECT region_name, count(rn) as total_count
FROM ranked
GROUP BY region_name)

SELECT r.region_name, r.days_stayed,
CASE WHEN r.rn = ROUND(c.total_count / 2.0, 0) THEN 'median'
	 WHEN r.rn = ROUND(c.total_count * 0.8, 0) THEN '80-th Percentile'
	 WHEN r.rn =  ROUND(c.total_count * 0.95, 0) THEN '95-th Percentile'
	 END as calculations
FROM ranked r
JOIN counted c
ON r.region_name = c.region_name
WHERE r.rn IN (ROUND(c.total_count / 2.0, 0),
			   ROUND(c.total_count * 0.8, 0),
			   ROUND(c.total_count * 0.95, 0));

/* 

B. Customer Transactions
What is the unique count and total amount for each transaction type?
What is the average total historical deposit counts and amounts for all customers?
For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
What is the closing balance for each customer at the end of the month?
What is the percentage of customers who increase their closing balance by more than 5%?

*/

-- What is the unique count and total amount for each transaction type?

SELECT txn_type, count(txn_type) as unique_count, SUM(txn_amount) as total_amount
FROM customer_transactions
WHERE txn_date <> '9999-12-31'
GROUP BY txn_type
ORDER BY unique_count DESC;

SELECT * FROM customer_transactions ORDER BY customer_id;
-- What is the average total historical deposit counts and amounts for all customers?

SELECT AVG(count_of_deposit) avg_count_of_deposits, AVG(total_amount) as total_amount
FROM(
SELECT customer_id, txn_type, COUNT(txn_type) as count_of_deposit, avg(txn_amount) as total_amount
FROM customer_transactions
WHERE txn_type = 'deposit'
GROUP BY customer_id, txn_type) x

-- For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?

SELECT mnth, COUNT(customer_id) as count_of_customers
FROM(
SELECT customer_id, DATEPART(MONTH, txn_date) as mnth,
	   SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) as count_of_deposit,
	   SUM(CASE WHEN txn_type <> 'deposit' THEN 1 ELSE 0 END) as count_of_wit_pur
FROM customer_transactions
GROUP BY customer_id, DATEPART(MONTH, txn_date)) x
WHERE count_of_deposit > 1 and count_of_wit_pur = 1
GROUP BY mnth;

-- What is the closing balance for each customer at the end of the month?

SELECT customer_id, mnth, net_transaction_amnt,
	   SUM(net_transaction_amnt) OVER (PARTITION BY customer_id ORDER BY mnth) AS closing_balance
FROM(
SELECT customer_id, mnth, SUM(txn_amount) as net_transaction_amnt
FROM(
SELECT customer_id, txn_date, DATEPART(MONTH, txn_date) as mnth, txn_type,
	   CASE WHEN txn_type = 'deposit' THEN txn_amount
			ELSE txn_amount * -1 END as txn_amount
FROM customer_transactions) x
GROUP BY customer_id, mnth)y
ORDER BY customer_id;


SELECT * FROM customer_transactions ORDER BY customer_id;

-- What is the percentage of customers who increase their closing balance by more than 5%?

SELECT CAST(SUM(inc_perc_flag) AS FLOAT) / COUNT(inc_perc_flag) as percentage_of_customers_increasing_balance
FROM(
SELECT customer_id, mnth, net_transaction_amnt,closing_balance,
		  LEAD(closing_balance, 1, closing_balance) OVER (PARTITION BY customer_id ORDER BY mnth) as nexth_month_balance,
		  ROUND(((LEAD(closing_balance) OVER (PARTITION BY customer_id ORDER BY mnth) / CAST(closing_balance as FLOAT)) - 1), 2) as percentage_increase,
		  CASE WHEN 
		  LEAD(closing_balance, 1, closing_balance) OVER (PARTITION BY customer_id ORDER BY mnth) IS NOT NULL AND
		  LEAD(closing_balance, 1, closing_balance) OVER (PARTITION BY customer_id ORDER BY mnth) > closing_balance AND
		  ROUND(((LEAD(closing_balance) OVER (PARTITION BY customer_id ORDER BY mnth) / CAST(closing_balance as FLOAT)) - 1), 2) > 0.05 
		  THEN 1 ELSE 0 END as inc_perc_flag
FROM(
SELECT customer_id, mnth, net_transaction_amnt,
	   SUM(net_transaction_amnt) OVER (PARTITION BY customer_id ORDER BY mnth) AS closing_balance
FROM(
SELECT customer_id, mnth, SUM(txn_amount) as net_transaction_amnt
FROM(
SELECT customer_id, txn_date, DATEPART(MONTH, txn_date) as mnth, txn_type,
	   CASE WHEN txn_type = 'deposit' THEN txn_amount
			ELSE txn_amount * -1 END as txn_amount
FROM customer_transactions) x
GROUP BY customer_id, mnth)y) z
WHERE closing_balance <> 0 ) inc_pe;

/* 

C. Data Allocation Challenge
To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers 
would be allocated data using 3 different options:

Option 1: data is allocated based off the amount of money at the end of the previous month
Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
Option 3: data is updated real-time
For this multi-part challenge question - you have been requested to generate the following data elements to help the 
Data Bank team estimate how much data will need to be provisioned for each option:

running customer balance column that includes the impact each transaction
customer balance at the end of each month
minimum, average and maximum values of the running balance for each customer
Using all of the data available - how much data would have been required for each option on a monthly basis?

*/

-- running customer balance column that includes the impact each transaction

SELECT customer_id, txn_date, txn_type, txn_amount, SUM(txn_amount) OVER(PARTITION BY customer_id ORDER BY txn_date) as running_balance
FROM (
SELECT customer_id, txn_date, txn_type, CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE txn_amount * - 1 END as txn_amount
FROM customer_transactions) x;

-- customer balance at the end of each month

SELECT y.customer_id, y.mnth, y.net_transaction_amnt, SUM(y.net_transaction_amnt) OVER(PARTITION BY y.customer_id ORDER BY y.mnth) as closing_balance
FROM(
SELECT x.customer_id, x.mnth, SUM(x.txn_amount) as net_transaction_amnt
FROM(
SELECT customer_id, DATEPART(MONTH, txn_date) as mnth, txn_type, 
	   CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE txn_amount * - 1 END as txn_amount
FROM customer_transactions)x
GROUP BY x.customer_id, x.mnth)y
ORDER BY y.customer_id

-- minimum, average and maximum values of the running balance for each customer

SELECT y.customer_id, y.txn_date, y.txn_type, y.running_balance,
	   MIN(y.running_balance) OVER(PARTITION BY y.customer_id ORDER BY y.txn_date
								range between unbounded preceding and unbounded following) as minimum_running_balance_of_customer,
	   AVG(y.running_balance) OVER(PARTITION BY y.customer_id ORDER BY y.txn_date
								range between unbounded preceding and unbounded following) as average_running_balance_of_customer,
	   MAX(y.running_balance) OVER(PARTITION BY y.customer_id ORDER BY y.txn_date
								range between unbounded preceding and unbounded following) as maximum_running_balance_of_customer
FROM(
SELECT x.customer_id, x.txn_date, x.txn_type, x.txn_amount, SUM(x.txn_amount) OVER(PARTITION BY x.customer_id ORDER BY x.txn_date) AS running_balance
FROM(
SELECT customer_id, txn_date, txn_type, CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE txn_amount * - 1 END AS txn_amount
FROM customer_transactions
) x)y

SELECT y.customer_id, 
	   MIN(y.running_balance) as minimum_customer_running_balance, 
	   AVG(y.running_balance) AS minimum_customer_running_balance, 
	   MAX(y.running_balance) AS maximum_customer_running_balance
FROM(
SELECT x.customer_id, x.txn_date, x.txn_type, x.txn_amount, SUM(x.txn_amount) OVER(PARTITION BY x.customer_id ORDER BY x.txn_date) AS running_balance
FROM(
SELECT customer_id, txn_date, txn_type, CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE txn_amount * - 1 END AS txn_amount
FROM customer_transactions
) x)y
GROUP BY y.customer_id
ORDER BY y.customer_id

-- Option 1: data is allocated based off the amount of money at the end of the previous month

SELECT mnth, SUM(closing_balance) as dat_r
FROM(
SELECT customer_id, mnth, net_transaction_amount, SUM(net_transaction_amount) OVER(PARTITION BY customer_id ORDER BY mnth) as closing_balance
FROM(
SELECT customer_id, mnth, SUM(txn_amount) as net_transaction_amount
FROM (
SELECT customer_id, DATEPART(MONTH, txn_date) as mnth, txn_type, 
	   CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE txn_amount * -1 END AS txn_amount
FROM customer_transactions) x
GROUP BY customer_id, mnth)y)z
GROUP BY mnth;

-- Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days

WITH transformed_cte AS (
SELECT  customer_id, txn_date, txn_type,
		CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE txn_amount * -1 END AS txn_amount
FROM customer_transactions)

SELECT  customer_id, txn_date, txn_type, txn_amount, 
		AVG(txn_amount) OVER(PARTITION BY customer_id ORDER BY txn_date
						ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) as avg_amount
FROM transformed_cte;

