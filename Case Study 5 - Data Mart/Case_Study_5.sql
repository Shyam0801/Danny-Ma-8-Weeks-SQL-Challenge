---------------------------------------------------------------

		----- CASE STUDY 5 Solutions --------

----------------------------------------------------------------


-- In a single query, perform the following operations and generate a new table in the data_mart schema named clean_weekly_sales:

-- Convert the week_date to a DATE format

ALTER TABLE weekly_sales
ALTER COLUMN week_date DATE; --- It didn't work

ALTER TABLE weekly_sales
ADD week_date_temp DATE;

UPDATE weekly_sales
SET week_date_temp = CONVERT(DATE, week_date, 3)

ALTER TABLE weekly_sales
DROP COLUMN week_date

SELECT * FROM weekly_sales;

EXEC sp_rename 'weekly_sales.week_date_temp', 'week_date', 'COLUMN';

-- Add a week_number as the second column for each week_date value, for example any value from the 1st of January to 7th of 
-- January will be 1, 8th to 14th will be 2 etc

SELECT week_date, DATEPART(week, week_date) as week_number, region, 
	   platform, segment, customer_type, transactions, sales
FROM weekly_sales;

-- Add a month_number with the calendar month for each week_date value as the 3rd column

SELECT week_date, DATEPART(week, week_date) as week_number, DATEPART(MONTH, week_date) as mnth, region, 
	   platform, segment, customer_type, transactions, sales
FROM weekly_sales;

-- Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values

SELECT week_date, DATEPART(week, week_date) as week_number, DATEPART(MONTH, week_date) as mnth, DATEPART(YEAR, week_date) as yr, region, 
	   platform, segment, customer_type, transactions, sales
FROM weekly_sales;

/*Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value
segment	age_band
1	Young Adults
2	Middle Aged
3 or 4	Retirees*/


SELECT week_date, DATEPART(week, week_date) as week_number, DATEPART(MONTH, week_date) as mnth, DATEPART(YEAR, week_date) as yr, 
	   region, platform, segment, CASE WHEN segment LIKE '%1%' THEN 'Young Adults'
									   WHEN segment LIKE '%2%' THEN 'Middle Aged'
									   WHEN segment LIKE '%3%' or segment LIKE '%4%' THEN 'Retirees'
									   ELSE 'unknown' END as age_band,
	   customer_type, transactions, sales
FROM weekly_sales;

/*Add a new demographic column using the following mapping for the first letter in the segment values:
segment	demographic
C	Couples
F	Families*/

SELECT week_date, DATEPART(week, week_date) as week_number, DATEPART(MONTH, week_date) as mnth, DATEPART(YEAR, week_date) as yr, 
	   region, platform, segment, 
	   CASE WHEN segment LIKE '%1%' THEN 'Young Adults'
									   WHEN segment LIKE '%2%' THEN 'Middle Aged'
									   WHEN segment LIKE '%3%' or segment LIKE '%4%' THEN 'Retirees'
									   ELSE 'unknown' END as age_band,
	   CASE WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
			WHEN LEFT(segment, 1) = 'F' THEN 'Families'
			ELSE 'unknown' END demographic,
	   customer_type, transactions, sales
FROM weekly_sales;

-- Ensure all null string values with an "unknown" string value in the original segment column as well as 
-- the new age_band and demographic columns

SELECT *
FROM (
	SELECT week_date, DATEPART(week, week_date) as week_number, DATEPART(MONTH, week_date) as mnth, DATEPART(YEAR, week_date) as yr, 
	   region, platform, segment, 
	   CASE WHEN segment LIKE '%1%' THEN 'Young Adults'
									   WHEN segment LIKE '%2%' THEN 'Middle Aged'
									   WHEN segment LIKE '%3%' or segment LIKE '%4%' THEN 'Retirees'
									   ELSE 'unknown' END as age_band,
	   CASE WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
			WHEN LEFT(segment, 1) = 'F' THEN 'Families'
			ELSE 'unknown' END demographic,
	   customer_type, transactions, sales
FROM weekly_sales
)x
WHERE x.segment = 'null'

-- Generate a new avg_transaction column as the sales value divided by transactions rounded to 2 decimal places for each record

CREATE TABLE cleaned_weekly_sales (
    week_date DATE,
    week_number INT,
    mnth INT,
    yr INT,
    region VARCHAR(13),
    platform VARCHAR(7),
    segment VARCHAR(4),
    age_band VARCHAR(255),
    demographic VARCHAR(255),
    customer_type VARCHAR(8),
    transactions INT,
    sales INT,
    avg_transactions DECIMAL(10, 2)
);

INSERT INTO cleaned_weekly_sales
SELECT 
    week_date, 
    DATEPART(week, week_date) as week_number,
    DATEPART(MONTH, week_date) as mnth,
    DATEPART(YEAR, week_date) as yr,
    region,
    platform,
    segment,
    CASE WHEN segment LIKE '%1%' THEN 'Young Adults'
         WHEN segment LIKE '%2%' THEN 'Middle Aged'
         WHEN segment LIKE '%3%' or segment LIKE '%4%' THEN 'Retirees'
         ELSE 'unknown' END as age_band,
    CASE WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
         WHEN LEFT(segment, 1) = 'F' THEN 'Families'
         ELSE 'unknown' END as demographic,
    customer_type,
    transactions,
    sales,
    ROUND((sales * 1.0 / transactions), 2) as avg_transactions
FROM weekly_sales;


SELECT * FROM cleaned_weekly_sales;


/* 

2. Data Exploration
What day of the week is used for each week_date value?


What range of week numbers are missing from the dataset?

How many total transactions were there for each year in the dataset?

What is the total sales for each region for each month?

What is the total count of transactions for each platform

What is the percentage of sales for Retail vs Shopify for each month?

What is the percentage of sales by demographic for each year in the dataset?

Which age_band and demographic values contribute the most to Retail sales?

Can we use the avg_transaction column to find the average transaction size for each year for 
Retail vs Shopify? If not - how would you calculate it instead?

*/

-- What day of the week is used for each week_date value?

SELECT *, DATEPART(weekday, week_date) as week_day, DATENAME(weekday, week_date) as week_name
FROM cleaned_weekly_sales;

SELECT DISTINCT(DATENAME(weekday, week_date)) as week_name
FROM cleaned_weekly_sales;
 
-- What range of week numbers are missing from the dataset?

SELECT * FROM GENERATE_SERIES(1, 53) as all_weeks -- generate series not available in ms sql

WITH AllWeeks AS (
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS all_weeks
    FROM sys.objects
),
all_weeks_1 as(
SELECT all_weeks
FROM AllWeeks
WHERE all_weeks <= 53)

SELECT * FROM all_weeks_1
WHERE all_weeks NOT IN (
		SELECT DISTINCT week_number 
		FROM cleaned_weekly_sales
		)


-- How many total transactions were there for each year in the dataset?

SELECT yr, SUM(transactions) as total_transactions
FROM cleaned_weekly_sales
GROUP BY yr
ORDER BY yr;

-- What is the total sales for each region for each month?

SELECT region, mnth, DATENAME(MONTH, week_date) as mnth_name,
SUM(CAST (sales as BIGINT)) as total_sales
FROM cleaned_weekly_sales
GROUP BY region, mnth, DATENAME(MONTH, week_date)
ORDER BY region, mnth;

-- What is the total count of transactions for each platform

SELECT platform, COUNT(transactions) as transactions_cnt
FROM cleaned_weekly_sales
GROUP BY platform;

-- What is the percentage of sales for Retail vs Shopify for each month?


 SELECT 
    yr, mnth,
    ROUND(
        (SUM(CASE WHEN platform = 'Retail' THEN CAST(sales AS DECIMAL(18, 2)) ELSE 0 END) / SUM(CAST(sales AS DECIMAL(18, 2)))) * 100, 2
    ) AS retail_percentage,
    ROUND(
        (SUM(CASE WHEN platform = 'Shopify' THEN CAST(sales AS DECIMAL(18, 2)) ELSE 0 END) / SUM(CAST(sales AS DECIMAL(18, 2)))) * 100, 2
    ) AS shopify_percentage
FROM cleaned_weekly_sales
GROUP BY mnth, yr
ORDER BY yr, mnth;


-- What is the percentage of sales by demographic for each year in the dataset?

SELECT yr,
	ROUND((SUM(CASE WHEN demographic = 'Couples' THEN CAST(sales as DECIMAL(18,2)) ELSE 0 END) / SUM(CAST(sales AS DECIMAL(18, 2)))) * 100, 2
    ) AS couples_percentage,
	ROUND((SUM(CASE WHEN demographic = 'Families' THEN CAST(sales as DECIMAL(18,2)) ELSE 0 END) / SUM(CAST(sales as DECIMAL(18,2)))) * 100, 2
	) AS families_percentage,
	ROUND((SUM(CASE WHEN demographic = 'unknown' THEN CAST(sales as DECIMAL(18,2)) ELSE 0 END) / SUM(CAST(sales as DECIMAL(18,2)))) * 100, 2
	) AS unknown_percentage
FROM cleaned_weekly_sales
GROUP BY yr
ORDER BY yr;

SELECT * FROM cleaned_weekly_sales

-- Which age_band and demographic values contribute the most to Retail sales?

WITH cte as(
SELECT * 
FROM cleaned_weekly_sales
WHERE platform = 'Retail')

SELECT age_band, demographic, SUM(CAST(sales as BIGINT)) as total_sales, 
		ROUND(SUM(CAST(sales AS DECIMAL(18,2))) / (SELECT sum(CAST(sales AS BIGINT)) FROM cte) * 100, 2) as perc
FROM cte
GROUP BY age_band, demographic
ORDER BY total_sales DESC;

-- Can we use the avg_transaction column to find the average transaction size for each year for 
-- Retail vs Shopify? If not - how would you calculate it instead?

SELECT yr, platform, AVG(avg_transactions) as non_correct_average, 
	   ROUND(SUM(CAST(sales AS DECIMAL(18,2)))/SUM(transactions), 2) as correct_avg
FROM cleaned_weekly_sales
GROUP BY yr, platform
ORDER BY yr, platform;

/* 

3. Before & After Analysis
This technique is usually used when we inspect an important event and want to inspect the impact before and after a certain point in time.

Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.

We would include all week_date values for 2020-06-15 as the start of the period after the change and the previous week_date values would be before

Using this analysis approach - answer the following questions:

What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?
What about the entire 12 weeks before and after?
How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?

*/

-- What is the total sales for the 4 weeks before and after 2020-06-15? 
-- What is the growth or reduction rate in actual values and percentage of sales?


With before_cte as(
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN DATEADD(WEEK, -4, '2020-06-15') AND DATEADD(WEEK, -1, '2020-06-15')),

after_cte as(
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN '2020-06-15' AND DATEADD(WEEK, 3, '2020-06-15')
),

before_sum_cte as(
SELECT SUM(CAST(sales as BIGINT)) as four_weeks_before_sales
FROM cleaned_weekly_sales
WHERE week_date IN (SELECT * FROM before_cte)),

after_sum_cte as(
SELECT SUM(CAST(sales as BIGINT)) as four_weeks_after_sales
FROM cleaned_weekly_sales
WHERE week_date IN (SELECT * FROM after_cte))

SELECT four_weeks_before_sales, four_weeks_after_sales, CAST((four_weeks_after_sales - four_weeks_before_sales) as BIGINT) as variance,
		ROUND(100 * CAST((four_weeks_after_sales - four_weeks_before_sales) as DECIMAL(18,2)) / four_weeks_before_sales, 2) as perc
FROM before_sum_cte, after_sum_cte


-- What about the entire 12 weeks before and after?

WITH before_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN DATEADD(week, -12, '2020-06-15') AND DATEADD(week, -1, '2020-06-15')
),
after_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN '2020-06-15' AND DATEADD(week, 11, '2020-06-15')),

before_sum_cte as(
SELECT SUM(CAST(sales as BIGINT)) as twelve_weeks_before_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM before_cte)
),

after_sum_cte as(
SELECT SUM(CAST(sales as BIGINT)) as twelve_weeks_after_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM after_cte)
)

SELECT twelve_weeks_before_sales, twelve_weeks_after_sales, CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as BIGINT) as variance,
	   ROUND(100 * CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as DECIMAL(18,2)) / twelve_weeks_before_sales , 2) as perc
FROM before_sum_cte, after_sum_cte;

-- How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?

-- 4 wk
WITH cte as(
SELECT DISTINCT week_number
FROM cleaned_weekly_sales
WHERE week_date = '2020-06-15'),

four_weeks_before as(
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_number BETWEEN (SELECT week_number FROM cte) - 4 AND (SELECT week_number FROM cte) -1
),
four_weeks_after as(
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_number BETWEEN (SELECT week_number FROM cte) AND (SELECT week_number FROM cte) + 3
),

before_sum_cte as(
SELECT yr, SUM(CAST(SALES as BIGINT)) as four_weeks_before_sales
FROM cleaned_weekly_sales
WHERE week_date IN (SELECT * FROM four_weeks_before)
GROUP BY yr
),

after_sum_cte as(
SELECT yr, SUM(CAST(SALES as BIGINT)) as four_weeks_after_sales
FROM cleaned_weekly_sales
WHERE week_date IN (SELECT * FROM four_weeks_after)
GROUP BY yr
)

SELECT bsc.yr, bsc.four_weeks_before_sales, asct.four_weeks_after_sales,
	   (asct.four_weeks_after_sales - bsc.four_weeks_before_sales) as variance,
	   ROUND(100 * CAST((asct.four_weeks_after_sales - bsc.four_weeks_before_sales) as DECIMAL(18,2)) / bsc.four_weeks_before_sales, 2) as perc
FROM before_sum_cte bsc
JOIN after_sum_cte asct
On bsc.yr = asct.yr;

-- 12 week

WITH cte as(
SELECT DISTINCT week_number
FROM cleaned_weekly_sales
WHERE week_date = '2020-06-15'),

twelve_weeks_before as(
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_number BETWEEN (SELECT week_number FROM cte) - 12 AND (SELECT week_number FROM cte) -1
),
twelve_weeks_after as(
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_number BETWEEN (SELECT week_number FROM cte) AND (SELECT week_number FROM cte) + 11
),

before_sum_cte as(
SELECT yr, SUM(CAST(SALES as BIGINT)) as twelve_weeks_before_sales
FROM cleaned_weekly_sales
WHERE week_date IN (SELECT * FROM twelve_weeks_before)
GROUP BY yr
),

after_sum_cte as(
SELECT yr, SUM(CAST(SALES as BIGINT)) as twelve_weeks_after_sales
FROM cleaned_weekly_sales
WHERE week_date IN (SELECT * FROM twelve_weeks_after)
GROUP BY yr
)

SELECT bsc.yr, bsc.twelve_weeks_before_sales, asct.twelve_weeks_after_sales,
	   (asct.twelve_weeks_after_sales - bsc.twelve_weeks_before_sales) as variance,
	   ROUND(100 * CAST((asct.twelve_weeks_after_sales - bsc.twelve_weeks_before_sales) as DECIMAL(18,2)) / bsc.twelve_weeks_before_sales, 2) as perc
FROM before_sum_cte bsc
JOIN after_sum_cte asct
On bsc.yr = asct.yr;

/*

4. Bonus Question
Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?

region
platform
age_band
demographic
customer_type
Do you have any further recommendations for Danny’s team at Data Mart or any interesting insights based off this analysis?

*/

-- region
WITH before_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN DATEADD(week, -12, '2020-06-15') AND DATEADD(week, -1, '2020-06-15')
),
after_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN '2020-06-15' AND DATEADD(week, 11, '2020-06-15')),

before_sum_cte as(
SELECT region, SUM(CAST(sales as BIGINT)) as twelve_weeks_before_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM before_cte)
GROUP BY region
),

after_sum_cte as(
SELECT region, SUM(CAST(sales as BIGINT)) as twelve_weeks_after_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM after_cte)
GROUP BY region
)

SELECT bsc.region, twelve_weeks_before_sales, twelve_weeks_after_sales, CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as BIGINT) as variance,
	   ROUND(100 * CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as DECIMAL(18,2)) / twelve_weeks_before_sales , 2) as perc
FROM before_sum_cte bsc
JOIN after_sum_cte asct
On bsc.region = asct.region
ORDER BY perc;

-- platform

WITH before_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN DATEADD(week, -12, '2020-06-15') AND DATEADD(week, -1, '2020-06-15')
),
after_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN '2020-06-15' AND DATEADD(week, 11, '2020-06-15')),

before_sum_cte as(
SELECT platform, SUM(CAST(sales as BIGINT)) as twelve_weeks_before_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM before_cte)
GROUP BY platform
),

after_sum_cte as(
SELECT platform, SUM(CAST(sales as BIGINT)) as twelve_weeks_after_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM after_cte)
GROUP BY platform
)

SELECT bsc.platform, twelve_weeks_before_sales, twelve_weeks_after_sales, CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as BIGINT) as variance,
	   ROUND(100 * CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as DECIMAL(18,2)) / twelve_weeks_before_sales , 2) as perc
FROM before_sum_cte bsc
JOIN after_sum_cte asct
On bsc.platform = asct.platform
ORDER BY perc;

-- age_band

WITH before_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN DATEADD(week, -12, '2020-06-15') AND DATEADD(week, -1, '2020-06-15')
),
after_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN '2020-06-15' AND DATEADD(week, 11, '2020-06-15')),

before_sum_cte as(
SELECT age_band, SUM(CAST(sales as BIGINT)) as twelve_weeks_before_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM before_cte)
GROUP BY age_band
),

after_sum_cte as(
SELECT age_band, SUM(CAST(sales as BIGINT)) as twelve_weeks_after_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM after_cte)
GROUP BY age_band
)

SELECT bsc.age_band, twelve_weeks_before_sales, twelve_weeks_after_sales, CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as BIGINT) as variance,
	   ROUND(100 * CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as DECIMAL(18,2)) / twelve_weeks_before_sales , 2) as perc
FROM before_sum_cte bsc
JOIN after_sum_cte asct
On bsc.age_band = asct.age_band
ORDER BY perc;


-- demographic

WITH before_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN DATEADD(week, -12, '2020-06-15') AND DATEADD(week, -1, '2020-06-15')
),
after_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN '2020-06-15' AND DATEADD(week, 11, '2020-06-15')),

before_sum_cte as(
SELECT demographic, SUM(CAST(sales as BIGINT)) as twelve_weeks_before_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM before_cte)
GROUP BY demographic
),

after_sum_cte as(
SELECT demographic, SUM(CAST(sales as BIGINT)) as twelve_weeks_after_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM after_cte)
GROUP BY demographic
)

SELECT bsc.demographic, twelve_weeks_before_sales, twelve_weeks_after_sales, CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as BIGINT) as variance,
	   ROUND(100 * CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as DECIMAL(18,2)) / twelve_weeks_before_sales , 2) as perc
FROM before_sum_cte bsc
JOIN after_sum_cte asct
On bsc.demographic = asct.demographic
ORDER BY perc;


-- customer_type

WITH before_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN DATEADD(week, -12, '2020-06-15') AND DATEADD(week, -1, '2020-06-15')
),
after_cte as (
SELECT DISTINCT week_date
FROM cleaned_weekly_sales
WHERE week_date BETWEEN '2020-06-15' AND DATEADD(week, 11, '2020-06-15')),

before_sum_cte as(
SELECT customer_type, SUM(CAST(sales as BIGINT)) as twelve_weeks_before_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM before_cte)
GROUP BY customer_type
),

after_sum_cte as(
SELECT customer_type, SUM(CAST(sales as BIGINT)) as twelve_weeks_after_sales
FROM cleaned_weekly_sales
WHERE week_date in (SELECT * FROM after_cte)
GROUP BY customer_type
)

SELECT bsc.customer_type, twelve_weeks_before_sales, twelve_weeks_after_sales, CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as BIGINT) as variance,
	   ROUND(100 * CAST((twelve_weeks_after_sales - twelve_weeks_before_sales) as DECIMAL(18,2)) / twelve_weeks_before_sales , 2) as perc
FROM before_sum_cte bsc
JOIN after_sum_cte asct
On bsc.customer_type = asct.customer_type
ORDER BY perc;