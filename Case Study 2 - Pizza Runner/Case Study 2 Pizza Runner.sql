-- There are inconsistency in the data like duplicates, wrong data type, null values in string, non-standardized values, so we need to fix it first

-- DELETING THE DUPLICATES IN THE customer_orders table

SELECT * FROM customer_orders;

WITH CTE AS(
SELECT  *,
		ROW_NUMBER() OVER(PARTITION BY order_id, customer_id, pizza_id, exclusions, extras, order_time ORDER BY (SELECT NULL)) as row_num
FROM customer_orders)

DELETE FROM CTE 
WHERE row_num > 1;

-- INSERTING AGAIN AS IT IS NOT DUPLICATE,a dn ordered the quantity as 2,so it is in two different rows

INSERT INTO customer_orders
  ("order_id", "customer_id", "pizza_id", "exclusions", "extras", "order_time")
VALUES ('4', '103', '1', '4', '', '2020-01-04 13:23:46');

-- The exclusions and extras columns contains the NULL valies in string format, so we need to make it as real null values

UPDATE customer_orders
SET exclusions = CASE WHEN exclusions = 'null' THEN NULL ELSE exclusions END,
	extras = CASE WHEN extras = 'null' THEN NULL ELSE extras END;

-- Null Values problem in - pickup_time, distance, duration, cancellation
-- km probelem in distance
-- Minutes, mins, minute problem in duration

SELECT * FROM runner_orders;

UPDATE runner_orders
SET distance = CASE WHEN distance LIKE '%km%' THEN REPLACE(distance, 'km', '') ELSE distance END,
	duration = CASE WHEN duration LIKE '%minutes%' THEN REPLACE(duration, 'minutes', '')
					WHEN duration LIKE '%mins%' THEN REPLACE(duration, 'mins', '')
					WHEN duration LIKE '%minute%' THEN REPLACE(duration, 'minute', '')
					ELSE duration END;

UPDATE runner_orders
SET pickup_time = CASE WHEN pickup_time = 'null' THEN NULL ELSE pickup_time END,
	distance = CASE WHEN distance = 'null' THEN NULL ELSE distance END,
	duration = CASE WHEN duration = 'null' THEN NULL ELSE duration END,
	cancellation = CASE WHEN cancellation = 'null' THEN NULL ELSE cancellation END;

--Changing the data type of the runner_orders table's columns - pickup_time, distance, duration


ALTER TABLE runner_orders
ALTER COLUMN pickup_time DATETIME;

ALTER TABLE runner_orders
ALTER COLUMN distance DECIMAL(5, 1);

ALTER TABLE runner_orders
ALTER COLUMN duration INT;
---------------------------------------------------------------------------
SELECT * FROM runner_orders;

SELECT * FROM customer_orders;

SELECT * FROM pizza_names;

SELECT * FROM pizza_recipes;

SELECT * FROM pizza_toppings;

SELECT * FROM runners;

-- How many pizzas were ordered?

SELECT COUNT(*) as pizza_orders 
FROM customer_orders;

-- How many unique customer orders were made?

SELECT COUNT(DISTINCT order_id) as unique_customer_orders
FROM customer_orders;

-- How many successful orders were delivered by each runner?

SELECT runner_id, (order_count - cancelled_orders) as sucessful_orders
FROM (
	SELECT runner_id, COUNT(order_id) as order_count, 
	SUM(CASE WHEN cancellation IN ('Restaurant Cancellation', 'Customer Cancellation') THEN 1 ELSE 0 END) as cancelled_orders
	FROM runner_orders
	GROUP BY runner_id
) x;

SELECT * FROM runner_orders;

-- How many of each type of pizza was delivered?

SELECT * FROM customer_orders;

-- In MS SQL there are some limitations with the TEXT data type, we can't group or sort, 
-- so we need to cast it to varchar(max) to get the result needed.

SELECT co.pizza_id, CAST(pn.pizza_name AS VARCHAR(MAX)) as pizza_name, count(co.order_id) as total_pizza_delivered
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
JOIN pizza_names pn
ON co.pizza_id = pn.pizza_id
WHERE ro.distance IS NOT NULL
GROUP BY co.pizza_id, CAST(pn.pizza_name AS VARCHAR(MAX));

-- How many Vegetarian and Meatlovers were ordered by each customer?

SELECT co.customer_id, CAST(pn.pizza_name AS VARCHAR(MAX)) as pizza_name, count(co.order_id) as pizza_ordered
FROM customer_orders co
JOIN pizza_names pn
ON co.pizza_id = pn.pizza_id
GROUP BY co.customer_id, CAST(pn.pizza_name AS VARCHAR(MAX))
ORDER BY co.customer_id;

-- What was the maximum number of pizzas delivered in a single order?

SELECT * FROM customer_orders;

SELECT * FROM runner_orders;

SELECT order_id, customer_id, order_count
FROM (
SELECT co.order_id, co.customer_id, COUNT(co.order_id) as order_count, 
DENSE_RANK() OVER(ORDER BY COUNT(co.order_id) DESC) as rnk
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.distance IS NOT NULL
GROUP BY co.order_id, co.customer_id) x
WHERE x.rnk = 1
ORDER BY order_id, customer_id;

-- For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

SELECT * FROM customer_orders;

SELECT co.customer_id,
		SUM(CASE WHEN co.exclusions != '' or co.extras != '' THEN 1 ELSE 0 END) as atleast_one_change,
		SUM(CASE WHEN (co.exclusions = '' or co.exclusions IS NULL) AND (co.extras = '' or co.extras IS NULL)THEN 1 ELSE 0 END) as no_change
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.distance IS NOT NULL
GROUP BY co.customer_id;

SELECT co.customer_id,
	   COUNT(CASE WHEN co.exclusions != '' or co.extras != '' THEN 1 END) as atleast_once_change,
	   COUNT(CASE WHEN (co.exclusions = '' or co.exclusions IS NULL) AND (co.extras = '' or co.extras IS NULL) THEN 1 END) as no_change
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.distance IS NOT NULL
GROUP BY co.customer_id;

-- How many pizzas were delivered that had both exclusions and extras?

SELECT COUNT(co.order_id) as exc_ext_change
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.distance IS NOT NULL AND (co.exclusions != '' AND co.extras != '');

-- What was the total volume of pizzas ordered for each hour of the day?

SELECT DATEPART(HOUR, order_time) AS hour_of_day, 
   count(pizza_id) AS pizza_count
FROM customer_orders
GROUP BY DATEPART(HOUR, order_time)
ORDER BY hour_of_day;

-- What was the volume of orders for each day of the week?

SELECT DATENAME(WEEKDAY, order_time) as day_of_week,
	   COUNT(pizza_id) as order_count
FROM customer_orders
GROUP BY DATENAME(WEEKDAY, order_time)
ORDER BY order_count DESC;

/* PART 2*/

-- How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

SELECT DATEPART(WEEK, DATEADD(DAY, 3, registration_date)) AS week_of_year,
       COUNT(runner_id) AS runner_count
FROM runners
GROUP BY DATEPART(WEEK, DATEADD(DAY, 3, registration_date))
ORDER BY week_of_year;

SELECT * FROM runners;

-- What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT * FROM customer_orders;

SELECT * FROM runner_orders;

SELECT ro.runner_id, AVG(DATEDIFF(MINUTE, co.order_time, ro.pickup_time)) as time_to_pick
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.distance IS NOT NULL
GROUP BY ro.runner_id;


-- Is there any relationship between the number of pizzas and how long the order takes to prepare

SELECT * FROM customer_orders;

SELECT * FROM runner_orders;

SELECT count_of_items, AVG(time_to_make) as time_to_make
FROM (
SELECT co.order_id, co.customer_id, co.order_time, COUNT(co.order_id) as count_of_items,
		DATEDIFF(MINUTE, co.order_time, ro.pickup_time) as time_to_make
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.distance IS NOT NULL
GROUP BY co.order_id, co.customer_id, co.order_time, DATEDIFF(MINUTE, co.order_time, ro.pickup_time)) x
GROUP BY count_of_items;


-- What was the average distance travelled for each customer?

SELECT co.customer_id, round(CAST(AVG(ro.distance) AS DECIMAL(5,1)), 1) as avg_distance
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.distance IS NOT NULL
GROUP BY co.customer_id;

-- What was the difference between the longest and shortest delivery times for all orders?

SELECT MAX(duration) - MIN(duration) as time_diffe
FROM runner_orders;

-- What was the average speed for each runner for each delivery and do you notice any trend for these values?

SELECT * FROM runner_orders;

SELECT runner_id, order_id, round(distance / (duration::numeric/60), 2) as delivery_time
FROM runner_orders
WHERE distance IS NOT NULL
GROUP BY runner_id, round(distance / (duration::numeric/60), 2);

SELECT runner_id, order_id, 
       ROUND((distance / (CAST(duration AS numeric) / 60)), 2) as delivery_time
FROM runner_orders
WHERE distance IS NOT NULL AND duration IS NOT NULL
GROUP BY runner_id, order_id, ROUND((distance / (CAST(duration AS numeric) / 60)), 2);


-- What is the successful delivery percentage for each runner?

SELECT runner_id, round((successful_delivery / total_order) * 100, 2) as successful_delivery_percentage
FROM (
SELECT runner_id,
		CAST(SUM(CASE WHEN distance IS NOT NULL THEN 1 ELSE 0 END) as DECIMAL(5, 1)) as successful_delivery,
		COUNT(order_id) as total_order
FROM runner_orders
GROUP BY runner_id)x;


SELECT * FROM runner_orders;

-- What are the standard ingredients for each pizza?

SELECT * FROM pizza_recipes;

SELECT * FROM pizza_toppings;

ALTER TABLE pizza_recipes
ALTER COLUMN toppings NVARCHAR(MAX);

UPDATE pizza_recipes
SET toppings = REPLACE(toppings, ', ', ',');

WITH CTE AS (
SELECT pizza_id, value as toppings FROM pizza_recipes CROSS APPLY string_split(toppings, ',')),

new_query as(
	SELECT pr.pizza_id, cte.toppings, CAST(pn.pizza_name AS VARCHAR(MAX)) as pizza_name, pt.topping_name
	FROM pizza_recipes pr
	JOIN pizza_names pn
	ON pr.pizza_id = pn.pizza_id
	JOIN CTE
	ON CTE.pizza_id = pr.pizza_id
	JOIN pizza_toppings pt
	ON cte.toppings = pt.topping_id	
)

SELECT pizza_name, 
       STUFF(
           (SELECT ', ' + CAST(topping_name AS NVARCHAR(MAX))
            FROM new_query nq2
            WHERE nq1.pizza_name = nq2.pizza_name
            FOR XML PATH('')), 1, 2, ''
       ) AS concatenated_toppings
FROM new_query nq1
GROUP BY pizza_name;

-- What was the most commonly added extra?

UPDATE customer_orders
SET extras = REPLACE(extras, ', ', ',');

SELECT * FROM customer_orders;

WITH cte as(
SELECT order_id, value as extras FROM customer_orders CROSS APPLY string_split(extras, ','))

SELECT extras, CAST(pt.topping_name AS VARCHAR(MAX)) as topping_name, count(extras) as extras_count
FROM cte
JOIN pizza_toppings pt
On cte.extras = pt.topping_id
WHERE extras != ''
GROUP BY extras, CAST(pt.topping_name AS VARCHAR(MAX))
ORDER BY extras_count DESC;


-- What was the most common exclusion?

UPDATE customer_orders
SET exclusions = REPLACE(exclusions, ', ', ',');

SELECT * FROM customer_orders;

WITH CTE as (
SELECT order_id, value as exclusions FROM customer_orders CROSS APPLY STRING_SPLIT(exclusions, ',') WHERE LEN(exclusions) > 0
)

SELECT exclusions, CAST(pt.topping_name AS VARCHAR(MAX)) as topping_name, count(exclusions) as exclusions_count
FROM cte
JOIN pizza_toppings pt
ON cte.exclusions = pt.topping_id
GROUP BY exclusions, CAST(pt.topping_name AS VARCHAR(MAX))
ORDER BY exclusions_count DESC;

/*

-- Generate an order item for each record in the customers_orders table in the format of one of the following:
-- Meat Lovers
-- Meat Lovers - Exclude Beef
-- Meat Lovers - Extra Bacon
-- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
-- Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
-- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"


WITH cte1 as (
	SELECT order_id, 
	value as exclusions 
	FROM customer_orders 
	CROSS APPLY STRING_SPLIT(exclusions, ',')
	WHERE LEN(value) > 0 AND value IS NOT NULL
	),

cte2 as(
	SELECT co.order_id, co.pizza_id,
	e.value as extras,
	STUFF(
		(SELECT ', ' + CAST(pt.topping_name as NVARCHAR(max))
		FROM pizza_toppings pt
		WHERE pt.topping_id = e.value
		FOR XML PATH('')), 1, 2, ''
	) as concated_query
FROM customer_orders co
CROSS APPLY STRING_SPLIT(co.extras, ',') as e
WHERE LEN(e.value) > 0 AND e.value IS NOT NULL
)

SELECT co.order_id, co.pizza_id,
       STUFF((SELECT DISTINCT ',' + CAST(pt.topping_name as VARCHAR(MAX))
              FROM pizza_toppings pt
              JOIN STRING_SPLIT(co.extras, ',') e ON pt.topping_id = e.value
              WHERE LEN(e.value) > 0 AND e.value IS NOT NULL
              FOR XML PATH('')), 1, 1, '') as added_extras
FROM customer_orders co;



--SElect * from cte1
--join cte2
--on cte1.order_id = cte2.order_id;


-- What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

SELECT co.order_id, co.pizza_id, e.value as extras,
    STUFF(
        (SELECT ', ' + CAST(pt.topping_name as NVARCHAR(max))
         FROM pizza_toppings pt
         WHERE pt.topping_id = e.value
         FOR XML PATH('')), 1, 2, ''
    ) as concated_query
FROM customer_orders co
CROSS APPLY STRING_SPLIT(co.extras, ',') as e
WHERE LEN(e.value) > 0 AND e.value IS NOT NULL;


SELECT 
    co.order_id,
    co.pizza_id,
    (
        SELECT STRING_AGG(e_sub.value, ',')
        FROM STRING_SPLIT(co.extras, ',') as e_sub
        WHERE LEN(e_sub.value) > 0 AND e_sub.value IS NOT NULL
    ) as extras_ids,
    (
        SELECT STRING_AGG(CAST(pt.topping_name AS NVARCHAR(MAX)), ',')
        FROM pizza_toppings pt
        WHERE pt.topping_id IN (
            SELECT e_sub.value
            FROM STRING_SPLIT(co.extras, ',') as e_sub
            WHERE LEN(e_sub.value) > 0 AND e_sub.value IS NOT NULL
        )
    ) as concatenated_toppings
FROM customer_orders co;

*/
------------------------------------------------------------------------------------


-- PART 3

/*
D. Pricing and Ratings
If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
What if there was an additional $1 charge for any pizza extras?
Add cheese is $1 extra
The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
customer_id
order_id
runner_id
rating
order_time
pickup_time
Time between order and pickup
Delivery duration
Average speed
Total number of pizzas
If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
*/

-- If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - 
-- how much money has Pizza Runner made so far if there are no delivery fees?

SELECT 
-- co.order_id, co.pizza_id, CAST(pn.pizza_name as VARCHAR(MAX)) as pizza_name,
CONCAT('$', SUM(CASE WHEN co.pizza_id = 1 THEN 12
	 WHEN co.pizza_id = 2 THEN 10 ELSE 0 END)) as total_price
FROM customer_orders co
JOIN pizza_names pn
ON co.pizza_id = pn.pizza_id
JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.distance IS NOT NULL
-- GROUP BY co.order_id, co.pizza_id, CAST(pn.pizza_name as VARCHAR(MAX));

SELECT * FROM customer_orders;

-- What if there was an additional $1 charge for any pizza extras?
-- Add cheese is $1 extra

WITH extras_cte as(
	SELECT co.order_id, 
		   co.pizza_id,
		   COUNT(value) as extras_count
	FROM customer_orders co
	CROSS APPLY STRING_SPLIT(co.extras, ',')
	WHERE LEN(value) > 0 and value IS NOT NULL
	GROUP BY co.order_id, 
			 co.pizza_id
)

SELECT -- co.order_id, 
	   -- co.pizza_id,
	   -- co.extras,
	   -- CAST(pn.pizza_name as VARCHAR(MAX)) as pizza_name,
	   SUM(CASE WHEN co.pizza_id = 1 and (co.extras IS NULL or co.extras = '') THEN 12
			WHEN co.pizza_id = 1 and co.extras IS NOT NULL THEN 12 + extras_cte.extras_count
			WHEN co.pizza_id = 2 and (co.extras IS NULL or co.extras = '') THEN 10
			WHEN co.pizza_id = 2 and co.extras IS NOT NULL THEN 10 + extras_cte.extras_count
			ELSE 0 END) as price
FROM customer_orders co
JOIN pizza_names pn
ON pn.pizza_id = co.pizza_id
LEFT JOIN extras_cte ON
co.order_id = extras_cte.order_id
JOIN runner_orders ro
ON ro.order_id = co.order_id
WHERE ro.distance IS NOT NULL
-- GROUP BY co.order_id, 
	     -- co.pizza_id,
		 -- co.extras,
	     -- CAST(pn.pizza_name as VARCHAR(MAX));

-- The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
-- how would you design an additional table for this new dataset - generate a schema for this new table and 
-- insert your own data for ratings for each successful customer order between 1 to 5.

DROP TABLE IF EXISTS ratings

CREATE TABLE ratings (
rating_id INTEGER PRIMARY KEY,
order_id INTEGER,
rating INTEGER);

INSERT INTO ratings(rating_id, order_id, rating) 
VALUES  (1, 1, 5),
		(2, 2, 4),
		(3, 3, 5),
		(4, 4, 3),
		(5, 5, 1),
		(6, 7, 1),
		(7, 8, 2),
		(8, 10, 5);

SELECT * FROM ratings



/*Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
customer_id
order_id
runner_id
rating
order_time
pickup_time
Time between order and pickup
Delivery duration
Average speed
Total number of pizzas */

SELECT co.customer_id, 
	   co.order_id, 
	   ro.runner_id, 
	   r.rating, 
	   co.order_time, 
	   ro.pickup_time,
	   DATEDIFF(MINUTE, co.order_time, ro.pickup_time) as time_between_order_and_pickup,
	   ro.duration,
	   AVG(ROUND((distance / (CAST(duration AS numeric) / 60)), 2)) as avg_speed,
	   COUNT(pizza_id) as total_pizza_delivered
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
LEFT JOIN ratings r
ON co.order_id = r.order_id
WHERE ro.distance IS NOT NULL
GROUP BY co.customer_id, 
	   co.order_id, 
	   ro.runner_id, 
	   r.rating, 
	   co.order_time, 
	   ro.pickup_time,
	   DATEDIFF(MINUTE, co.order_time, ro.pickup_time),
	   ro.duration;

SELECT * FROM runner_orders;


-- If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and 
-- each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?

WITH cte1 AS (
SELECT co.order_id,  -- co.customer_id, ro.runner_id, ro.distance, CAST(pn.pizza_name AS VARCHAR(MAX)) as pizza_name,
	   SUM(CASE WHEN co.pizza_id = 1 THEN 12
				WHEN co.pizza_id = 2 THEN 10
				ELSE 0 END) as order_revenue
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
JOIN pizza_names pn
ON pn.pizza_id = co.pizza_id
WHERE ro.distance IS NOT NULL
GROUP BY co.order_id
--co.customer_id, ro.runner_id, ro.distance, CAST(pn.pizza_name AS VARCHAR(MAX));
),

cte2 AS(
SELECT co.order_id, 
	   -- co.customer_id, 
	   -- ro.runner_id, 
	   -- ro.distance,
	   -- CAST(pn.pizza_name AS VARCHAR(MAX)) as pizza_name,
	   -- ROUND(CAST(SUM(CASE WHEN co.pizza_id = 1 AND ro.distance IS NOT NULL THEN 12 + (ro.distance * 0.30)
			-- WHEN co.pizza_id = 2 AND ro.distance IS NOT NULL THEN 10 + (ro.distance * 0.30)
			-- ELSE 0 END) AS FLOAT), 2) as orders_rev_inc_extras,
		SUM(ro.distance * 0.30) as deivery_charge
FROM customer_orders co
JOIN runner_orders ro
ON co.order_id = ro.order_id
JOIN pizza_names pn
ON pn.pizza_id = co.pizza_id
WHERE ro.distance is not null
GROUP BY co.order_id 
	   --  co.customer_id, 
	   -- ro.runner_id, 
	   -- ro.distance,
	   -- CAST(pn.pizza_name AS VARCHAR(MAX));
)
SELECT
    SUM(cte1.order_revenue - cte2.deivery_charge) AS total_revenue_from_extras
FROM cte1
JOIN cte2 ON cte1.order_id = cte2.order_id;

SELECT * FROM runner_orders;