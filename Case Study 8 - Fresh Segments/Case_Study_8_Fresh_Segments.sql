/*----------------------------------------------------------

		       CASE STUDY 8 Fresh Segment SOLUTION

------------------------------------------------------------*/



-- update NULL values
UPDATE interest_metrics
SET _month = CASE WHEN _month = 'NULL' THEN NULL ELSE CAST(_month AS INTEGER) END;

UPDATE interest_metrics
SET _year = CASE WHEN _year = 'NULL' THEN NULL ELSE CAST(_year AS INTEGER) END;

UPDATE interest_metrics
SET month_year = NULL
WHERE month_year = 'NULL';

UPDATE interest_metrics
SET interest_id = NULL
WHERE interest_id = 'NULL';


-- only a tiny sample of the dataset is inserted here as it breaks the DB Fiddle system if I put in all the data!
INSERT INTO json_data (raw_data)
VALUES
  ('{"month": 7, "year": 2018, "month_year": "07-2018", "a.attribute_interest_id": 32486, "average_composition": 11.89, "average_index": 6.19, "rank": 1, "percentile_rank": 99.86}'::JSON),
  ('{"month": 7, "year": 2018, "month_year": "07-2018", "a.attribute_interest_id": 32486, "average_composition": 11.89, "average_index": 6.19, "rank": 1, "percentile_rank": 99.86}'),
('{"month": 7, "year": 2018, "month_year": "07-2018", "a.attribute_interest_id": 6106, "average_composition": 9.93, "average_index": 5.31, "rank": 2, "percentile_rank": 99.73}'),
('{"month": 7, "year": 2018, "month_year": "07-2018", "a.attribute_interest_id": 18923, "average_composition": 10.85, "average_index": 5.29, "rank": 3, "percentile_rank": 99.59}')
;


-- Data Exploration and Cleansing
-- Update the fresh_segments.interest_metrics table by modifying the month_year column to be a date data type with the start of the month

EXEC sp_columns interest_metrics; --Executed to know about the column infos - dtypes and so on

-- Found that month_year can only store varchar(7), with which we can't store it with the start of the month, month and year, so we need to change it to varchar(10)

ALTER TABLE interest_metrics
ALTER COLUMN month_year VARCHAR(10);

UPDATE interest_metrics
SET month_year = CONVERT(DATE, '01-'+month_year, 105)

ALTER TABLE interest_metrics
ALTER COLUMN month_year DATE;

SELECT * FROM interest_metrics;


-- What is count of records in the fresh_segments.interest_metrics for each month_year value sorted in chronological order (earliest to latest) 
-- with the null values appearing first?

SELECT month_year, COUNT(*) as count_of_values
FROM interest_metrics
GROUP BY month_year
ORDER BY month_year ASC;

SELECT month_year, count_of_values, SUM(count_of_values) OVER() as sum_of_all
FROM(
SELECT month_year, COUNT(*) as count_of_values
FROM interest_metrics
GROUP BY month_year)x
ORDER BY month_year ASC;

-- How many interest_id values exist in the fresh_segments.interest_metrics table but not in the fresh_segments.interest_map table? 
-- What about the other way around?

SELECT COUNT(DISTINCT ime.interest_id) as metrics_count,
	   COUNT(DISTINCT ima.id) as map_count,
	   SUM(CASE WHEN ime.interest_id IS NULL AND ima.id IS NOT NULL THEN 1 END) as metrics_null_count,
	   SUM(CASE WHEN ima.id IS NULL AND ime.interest_id IS NOT NULL THEN 1 END) as map_null_count
FROM interest_metrics ime
FULL JOIN interest_map ima
ON ime.interest_id = ima.id

-- Summarise the id values in the fresh_segments.interest_map by its total record count in this table

SELECT COUNT(id) as total_ids
FROM interest_map;

-- What sort of table join should we perform for our analysis and why? Check your logic by checking the rows where interest_id = 21246 in your 
-- joined output and include all columns from fresh_segments.interest_metrics and all columns from fresh_segments.interest_map except from the id column.

SELECT *
FROM interest_metrics ime
JOIN interest_map ima
ON ime.interest_id = ima.id
WHERE ime.interest_id = 21246;


-- Are there any records in your joined table where the month_year value is before the created_at value from the fresh_segments.interest_map table? 
-- Do you think these values are valid and why?

SELECT COUNT(*) as count_of_rows
FROM interest_metrics ime
JOIN interest_map ima
ON ime.interest_id = ima.id
WHERE CAST(ima.created_at as DATE) > ime.month_year; 

SELECT COUNT(*) AS cnt
FROM interest_metrics ime
JOIN interest_map ima
  ON ima.id = ime.interest_id
WHERE ime.month_year < CAST(DATEADD(DAY, -DAY(ima.created_at)+1, ima.created_at) AS DATE);

-- Interest Analysis
-- Which interests have been present in all month_year dates in our dataset?

SELECT interest_id, COUNT(DISTINCT month_year) as count_of_month_year
FROM interest_metrics
GROUP BY interest_id
HAVING COUNT(DISTINCT month_year) = (SELECT COUNT(DISTINCT month_year) as total_month_year FROM interest_metrics);

-- Using this same total_months measure - calculate the cumulative percentage of all records starting at 14 months - 
-- which total_months value passes the 90% cumulative percentage value?

WITH total_month_count as(
SELECT interest_id, COUNT(month_year) as total_month
FROM interest_metrics
WHERE interest_id IS NOT NULL
GROUP BY interest_id),

interest_count as (
SELECT total_month, COUNT(interest_id) as count_of_interest
FROM total_month_count
GROUP BY total_month)

SELECT total_month, count_of_interest, 
	   CAST((100.0 * SUM(count_of_interest) OVER(ORDER BY total_month DESC) / SUM(count_of_interest) OVER()) AS DECIMAL(18,2)) as cumulative_pct
FROM interest_count
ORDER BY total_month DESC;

-- If we were to remove all interest_id values which are lower than the total_months value we found in the previous question - 
-- how many total data points would we be removing?

WITH interest_months AS (
  SELECT
    interest_id,
    COUNT(DISTINCT month_year) AS total_months
  FROM interest_metrics
  WHERE interest_id IS NOT NULL
  GROUP BY interest_id
)

SELECT 
  COUNT(interest_id) AS interests,
  COUNT(DISTINCT interest_id) AS unique_interests
FROM interest_metrics
WHERE interest_id IN (
  SELECT interest_id 
  FROM interest_months
  WHERE total_months < 6);



-- Does this decision make sense to remove these data points from a business perspective? 
-- Use an example where there are all 14 months present to a removed interest example for your arguments - 
-- think about what it means to have less months present from a segment perspective.

/* Before removing the datas, we need to look at some other things, Whether this data contains info only about one year, 
or maybe even if we have other year datas, we need to see if the pattern is being followed in other years, in that case we need to see why it is less or is it seasonal
Or if it is the beginning of the dataset then it is not good delete, because as it is the beginning of the business it will grow steadily only */

-- After removing these interests - how many unique interests are there for each month?

WITH interest_excluded as(
SELECT *
FROM interest_metrics
WHERE interest_id NOT IN(
SELECT interest_id
FROM interest_metrics
WHERE interest_id IS NOT NULL
GROUP BY interest_id
HAVING COUNT(DISTINCT month_year) < 6))

SELECT month_year, COUNT(DISTINCT interest_id) as unique_total_interest_count
FROM interest_excluded
WHERE month_year IS NOT NULL
GROUP BY month_year
ORDER BY month_year;

-- Segment_analysis

-- Using our filtered dataset by removing the interests with less than 6 months worth of data,
-- which are the top 10 and bottom 10 interests which have the largest composition values in any month_year? 
-- Only use the maximum composition value for each interest but you must keep the corresponding month_year

WITH interest_excluded as(
SELECT *
FROM interest_metrics
WHERE interest_id NOT IN(
SELECT interest_id
FROM interest_metrics
WHERE interest_id IS NOT NULL
GROUP BY interest_id
HAVING COUNT(DISTINCT month_year) < 6)),

composition_max as(
SELECT interest_id, month_year,
	   MAX(composition) OVER(PARTITION BY interest_id) as max_composition
FROM interest_excluded
WHERE month_year IS NOT NULL),

ranked as(
SELECT interest_id, month_year,DENSE_RANK() OVER(ORDER BY max_composition DESC) as rnk
FROM composition_max)

SELECT interest_id, rnk
FROM ranked
WHERE rnk <=10
GROUP BY interest_id, rnk
ORDER BY rnk;
----------------------------------------------------------------------- Bottom 10 downside
WITH interest_excluded as(
SELECT *
FROM interest_metrics
WHERE interest_id NOT IN(
SELECT interest_id
FROM interest_metrics
WHERE interest_id IS NOT NULL
GROUP BY interest_id
HAVING COUNT(DISTINCT month_year) < 6)),

composition_max as(
SELECT interest_id, month_year,
	   MAX(composition) OVER(PARTITION BY interest_id) as max_composition
FROM interest_excluded
WHERE month_year IS NOT NULL),

ranked as(
SELECT interest_id, month_year,DENSE_RANK() OVER(ORDER BY max_composition DESC) as rnk
FROM composition_max)

SELECT TOP 10 interest_id, rnk
FROM ranked
GROUP BY interest_id, rnk
ORDER BY rnk DESC;


-- Which 5 interests had the lowest average ranking value?
WITH interest_excluded as(
SELECT *
FROM interest_metrics
WHERE interest_id NOT IN(
SELECT interest_id
FROM interest_metrics
WHERE interest_id IS NOT NULL
GROUP BY interest_id
HAVING COUNT(DISTINCT month_year) < 6))

SELECT TOP 5 interest_id, CAST(AVG(1.0 * ranking) AS DECIMAL(10,2)) as avg_rank
FROM interest_excluded
GROUP BY interest_id
ORDER BY avg_rank;

EXEC sp_columns interest_metrics;

-- Which 5 interests had the largest standard deviation in their percentile_ranking value?

WITH interest_excluded as(
SELECT *
FROM interest_metrics
WHERE interest_id NOT IN(
SELECT interest_id
FROM interest_metrics
WHERE interest_id IS NOT NULL
GROUP BY interest_id
HAVING COUNT(DISTINCT month_year) < 6))

SELECT TOP 5 interest_id, ROUND(STDEV(percentile_ranking), 2) as stnd_dev
FROM interest_excluded
GROUP BY interest_id
ORDER BY stnd_dev DESC;

-- For the 5 interests found in the previous question - what was minimum and maximum percentile_ranking values for each interest and 
-- its corresponding year_month value? Can you describe what is happening for these 5 interests?

WITH interest_excluded as(
SELECT *
FROM interest_metrics
WHERE interest_id NOT IN(
SELECT interest_id
FROM interest_metrics
WHERE interest_id IS NOT NULL
GROUP BY interest_id
HAVING COUNT(DISTINCT month_year) < 6)),

perc_ranking as(
SELECT TOP 5 interest_id, ROUND(STDEV(percentile_ranking), 2) as stnd_dev
FROM interest_excluded
GROUP BY interest_id
ORDER BY stnd_dev DESC),

sorted_cte as(
SELECT pr.interest_id, ie.month_year,ie.percentile_ranking, 
	   MAX(ie.percentile_ranking) OVER(PARTITION BY pr.interest_id)as max_pct_ranking,
	   MIN(ie.percentile_ranking) OVER(PARTITION BY pr.interest_id) as min_pct_ranking
FROM perc_ranking pr
JOIN interest_excluded ie
ON pr.interest_id = ie.interest_id
GROUP BY pr.interest_id, ie.month_year, ie.percentile_ranking)

SELECT interest_id,
	   MAX(CASE WHEN percentile_ranking = max_pct_ranking THEN month_year END ) as max_month_year,
	   MAX(CASE WHEN percentile_ranking = max_pct_ranking THEN percentile_ranking END) as max_pct_ranking,
	   MIN(CASE WHEN percentile_ranking = min_pct_ranking THEN month_year END) as min_month_year,
	   MIN(CASE WHEN percentile_ranking = min_pct_ranking THEN percentile_ranking END) as min_pct_ranking
FROM sorted_cte
GROUP BY interest_id;

-- How would you describe our customers in this segment based off their composition and ranking values? 
-- What sort of products or services should we show to these customers and what should we avoid?

/*This particular customer segment has a strong affinity for both travel experiences and personalized gifts, but they prefer one-time spending. This preference is evident in 
their fluctuating engagement levels, with a high percentile ranking in one month of 2018, contrasting with a lower ranking in a different month in 2019. Additionally, 
these customers are keenly interested in staying updated on the latest developments in the technology and entertainment sectors.*/

/*In light of these preferences, our recommendation is to focus on offering one-time accommodation services and personalized gifts to cater to their 
unique spending habits. We can also encourage them to subscribe to newsletters to receive updates on the latest tech products and emerging trends in the entertainment industry*/

