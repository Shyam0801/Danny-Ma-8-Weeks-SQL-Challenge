SELECT * FROM clique_bait.users_c;

SELECT * FROM clique_bait.event_identifier;

SELECT * FROM clique_bait.events;

SELECT * FROM clique_bait.campaign_identifier;

SELECT * FROM clique_bait.page_hierarchy;

SELECT 
    event_time AS OriginalValue,
    SUBSTRING(FORMAT(event_time, 'yyyy-MM-dd HH:mm:ss.fffffff'), 21, 7) AS Milliseconds
FROM clique_bait.events;


SELECT *
FROM clique_bait.events;


SELECT *,
    SUBSTRING(event_time, 1, CHARINDEX('.', event_time) - 1) AS datetime_without_ms,
    SUBSTRING(event_time, CHARINDEX('.', event_time) + 1, LEN(event_time)) AS ms
FROM clique_bait.events

ALTER TABLE clique_bait.events
ADD event_time_corrected VARCHAR(max)

UPDATE clique_bait.events
SET event_time_corrected = SUBSTRING(event_time, 1, CHARINDEX('.', event_time) -1);

ALTER TABLE clique_bait.events
DROP COLUMN event_time_corrected;

UPDATE clique_bait.events
SET event_time_corrected = CONVERT(DATETIME2, event_time_corrected);

/* 
2. Digital Analysis
Using the available datasets - answer the following questions using a single query for each one:

How many users are there?
How many cookies does each user have on average?
What is the unique number of visits by all users per month?
What is the number of events for each event type?
What is the percentage of visits which have a purchase event?
What is the percentage of visits which view the checkout page but do not have a purchase event?
What are the top 3 pages by number of views?
What is the number of views and cart adds for each product category?
What are the top 3 products by purchases?

*/

-- How many users are there?

SELECT COUNT(DISTINCT(user_id)) as total_users
FROM clique_bait.users_c;

-- How many cookies does each user have on average?

SELECT AVG(cookies_count) as avg_cookies_per_user
FROM(
SELECT user_id, 1.0 * COUNT(cookie_id) as cookies_count
FROM clique_bait.users_c
GROUP BY user_id) x;

-- What is the unique number of visits by all users per month?

SELECT * FROM clique_bait.users_c

SELECT * FROM clique_bait.events

SELECT DATEPART(MONTH, e.event_time_corrected) as mnth, COUNT(DISTINCT(e.visit_id)) as total_visits
FROM clique_bait.users_c u
JOIN clique_bait.events e
ON u.cookie_id = e.cookie_id
GROUP BY DATEPART(MONTH, e.event_time_corrected)
ORDER BY mnth;

-- What is the number of events for each event type?

SELECT ev.event_type, ei.event_name, COUNT(*) as no_of_events
FROM clique_bait.events ev
JOIN clique_bait.event_identifier ei
ON ev.event_type = ei.event_type
GROUP BY ev.event_type, ei.event_name
ORDER BY ev.event_type;

-- What is the percentage of visits which have a purchase event?

SELECT COUNT(DISTINCT ev.visit_id) * 100.0 / (SELECT COUNT(DISTINCT visit_id) FROM clique_bait.events) as purchase_event_perc
FROM clique_bait.events ev
JOIN clique_bait.event_identifier ei
ON ev.event_type = ei.event_type
WHERE ei.event_name = 'purchase'

SELECT (100.0 * COUNT(DISTINCT CASE WHEN event_type = 3 THEN visit_id END) / COUNT(DISTINCT visit_id)) as purchase_event_perc
FROM clique_bait.events;


-- What is the percentage of visits which view the checkout page but do not have a purchase event?

WITH view_checkout AS (
  SELECT COUNT(ev.visit_id) AS cnt
  FROM clique_bait.events ev
  JOIN clique_bait.event_identifier ei ON ev.event_type = ei.event_type
  JOIN clique_bait.page_hierarchy ep ON ev.page_id = ep.page_id
  WHERE ei.event_name = 'Page View'
    AND ep.page_name = 'Checkout'
)

SELECT CAST(100 - (100.0 * COUNT(DISTINCT ev.visit_id) 
		/ (SELECT cnt FROM view_checkout)) AS decimal(10, 2)) AS pct_view_checkout_not_purchase
FROM clique_bait.events ev
JOIN clique_bait.event_identifier ei ON ev.event_type = ei.event_type
WHERE ei.event_name = 'Purchase';


-- What are the top 3 pages by number of views?

SELECT ep.page_id, ep.page_name, COUNT(ev.event_type) as total_views
FROM clique_bait.page_hierarchy ep
JOIN clique_bait.events ev
ON ep.page_id = ev.page_id
WHERE ev.event_type = 1
GROUP BY ep.page_id, ep.page_name
ORDER BY total_views DESC

-- What is the number of views and cart adds for each product category?

SELECT ep.product_category,
 	   SUM(CASE WHEN ev.event_type = 1 THEN 1 ELSE 0 END) as views_count,
	   SUM(CASE WHEN ev.event_type = 2 THEN 1 ELSE 0 END) as added_to_cart
FROM clique_bait.page_hierarchy ep
JOIN clique_bait.events ev
ON ep.page_id = ev.page_id
WHERE ep.product_category IS NOT NULL
GROUP BY ep.product_category;

-- What are the top 3 products by purchases?

SELECT  TOP 3 ep.product_id, ep.page_name, ep.product_category, COUNT(*) as purchases_count
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
JOIN clique_bait.event_identifier ei
ON ev.event_type = ei.event_type
WHERE ei.event_name = 'Add to cart'
AND ev.visit_id IN(
SELECT ev.visit_id 
FROM clique_bait.events ev
JOIN clique_bait.event_identifier ei
ON ev.event_type = ei.event_type
WHERE ei.event_name = 'Purchase')
GROUP BY ep.product_id, ep.page_name, ep.product_category
ORDER BY purchases_count DESC;

/* 

3. Product Funnel Analysis
Using a single SQL query - create a new output table which has the following details:

How many times was each product viewed?
How many times was each product added to cart?
How many times was each product added to a cart but not purchased (abandoned)?
How many times was each product purchased?
Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.

Use your 2 new output tables - answer the following questions:

Which product had the most views, cart adds and purchases?
Which product was most likely to be abandoned?
Which product had the highest view to purchase percentage?
What is the average conversion rate from view to cart add?
What is the average conversion rate from cart add to purchase?

*/

-- How many times was each product viewed?

SELECT ep.product_id, ep.page_name, COUNT(*) as views_count
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
WHERE ev.event_type = 1 AND product_id IS NOT NULL
GROUP BY ep.product_id, ep.page_name
ORDER BY ep.product_id;


-- How many times was each product added to cart?

SELECT ep.product_id, ep.page_name, COUNT(*) as added_to_cart
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
WHERE ev.event_type = 2 AND product_id IS NOT NULL
GROUP BY ep.product_id, ep.page_name
ORDER BY ep.product_id;

-- How many times was each product added to a cart but not purchased (abandoned)?

SELECT ep.product_id, ep.page_name, COUNT(*) as abandoned
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
WHERE ev.event_type = 2 AND product_id IS NOT NULL AND ev.visit_id NOT IN 
(SELECT ev.visit_id
FROM clique_bait.events ev
JOIN clique_bait.event_identifier ei
ON ev.event_type = ei.event_type
WHERE ei.event_name = 'Purchase')
GROUP BY ep.product_id, ep.page_name
ORDER BY ep.product_id;


-- How many times was each product purchased?

SELECT ep.product_id, ep.page_name, COUNT(*) as purchased
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
WHERE ev.event_type = 2 AND product_id IS NOT NULL AND ev.visit_id IN 
(SELECT ev.visit_id
FROM clique_bait.events ev
JOIN clique_bait.event_identifier ei
ON ev.event_type = ei.event_type
WHERE ei.event_name = 'Purchase')
GROUP BY ep.product_id, ep.page_name
ORDER BY ep.product_id;

-- Putting everything in one table

WITH views_added_to_cart as(
SELECT ep.product_id, ep.page_name, ep.product_category,
	   SUM(CASE WHEN ev.event_type = 1 THEN 1 END) as views_count,
	   SUM(CASE WHEN ev.event_type = 2 THEN 1 END) as added_to_cart
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
WHERE ep.product_id IS NOT NULL
GROUP BY ep.product_id, ep.page_name, ep.product_category
),

products_abandoned as(
SELECT ep.product_id, ep.page_name, ep.product_category, COUNT(*) as abandoned
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
WHERE ev.event_type = 2 AND product_id IS NOT NULL AND ev.visit_id NOT IN 
(SELECT ev.visit_id
FROM clique_bait.events ev
JOIN clique_bait.event_identifier ei
ON ev.event_type = ei.event_type
WHERE ei.event_name = 'Purchase')
GROUP BY ep.product_id, ep.page_name, ep.product_category
),

products_purchased as(
SELECT ep.product_id, ep.page_name, ep.product_category, COUNT(*) as purchased
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
WHERE ev.event_type = 2 AND product_id IS NOT NULL AND ev.visit_id IN 
(SELECT ev.visit_id
FROM clique_bait.events ev
JOIN clique_bait.event_identifier ei
ON ev.event_type = ei.event_type
WHERE ei.event_name = 'Purchase')
GROUP BY ep.product_id, ep.page_name, ep.product_category
)

SELECT vac.*,
       pa.abandoned,
	   pp.purchased
INTO first_table
FROM views_added_to_cart vac
JOIN products_abandoned pa ON vac.product_id = pa.product_id
JOIN products_purchased pp ON vac.product_id = pp.product_id

DROP TABLE IF EXISTS first_table
SELECT * FROM first_table;


-- Additionally, create another table which further aggregates the data for the above points 
-- but this time for each product category instead of individual products.

WITH views_added_to_cart as(
SELECT ep.product_category, 
	   SUM(CASE WHEN ev.event_type = 1 THEN 1 END) as views_count,
	   SUM(CASE WHEN ev.event_type = 2 THEN 1 END) as added_to_cart
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
WHERE ep.product_id IS NOT NULL
GROUP BY ep.product_category
),

products_abandoned as(
SELECT ep.product_category, COUNT(*) as abandoned
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
WHERE ev.event_type = 2 AND product_id IS NOT NULL AND ev.visit_id NOT IN 
(SELECT ev.visit_id
FROM clique_bait.events ev
JOIN clique_bait.event_identifier ei
ON ev.event_type = ei.event_type
WHERE ei.event_name = 'Purchase')
GROUP BY ep.product_category
),

products_purchased as(
SELECT ep.product_category, COUNT(*) as purchased
FROM clique_bait.events ev
JOIN clique_bait.page_hierarchy ep
ON ev.page_id = ep.page_id
WHERE ev.event_type = 2 AND product_id IS NOT NULL AND ev.visit_id IN 
(SELECT ev.visit_id
FROM clique_bait.events ev
JOIN clique_bait.event_identifier ei
ON ev.event_type = ei.event_type
WHERE ei.event_name = 'Purchase')
GROUP BY ep.product_category
)

SELECT vac.*,
       pa.abandoned,
	   pp.purchased
INTO second_table
FROM views_added_to_cart vac
JOIN products_abandoned pa ON vac.product_category = pa.product_category
JOIN products_purchased pp ON vac.product_category = pp.product_category


SELECT * FROM second_table;

-- Use your 2 new output tables - answer the following questions:

-- Which product had the most views, cart adds and purchases?

SELECT TOP 1 *
FROM first_table
ORDER BY views_count DESC;

SELECT TOP 1 *
FROM first_table
ORDER BY added_to_cart DESC;

SELECT TOP 1 *
FROM first_table
ORDER BY purchased DESC;

-- Which product was most likely to be abandoned?

SELECT TOP 1 *
FROM first_table
ORDER BY abandoned DESC;

-- Which product had the highest view to purchase percentage?

SELECT TOP 1 page_name, product_category, CAST((100.0 * purchased / views_count) AS DECIMAL(10, 2))as perc
FROM first_table
ORDER BY perc DESC;


-- What is the average conversion rate from view to cart add?

SELECT CAST(AVG(100.0 * added_to_cart / views_count) AS DECIMAL(10, 2))as avg_view
FROM first_table;

-- What is the average conversion rate from cart add to purchase?

SELECT CAST(AVG(100.0 * purchased / added_to_cart) AS DECIMAL(10, 2))as avg_purchases
FROM first_table;

/* 

Generate a table that has 1 single row for every unique visit_id record and has the following columns:

user_id
visit_id
visit_start_time: the earliest event_time for each visit
page_views: count of page views for each visit
cart_adds: count of product cart add events for each visit
purchase: 1/0 flag if a purchase event exists for each visit
campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
impression: count of ad impressions for each visit
click: count of ad clicks for each visit
(Optional column) cart_products: a comma separated text value with products added to the cart sorted by the order they were added to the cart 
(hint: use the sequence_number)
Use the subsequent dataset to generate at least 5 insights for the Clique Bait team - 
bonus: prepare a single A4 infographic that the team can use for their management reporting sessions, be sure to emphasise 
the most important points from your findings.

*/

SELECT * FROM clique_bait.event_identifier;

SELECT u.user_id,
	   e.visit_id,
	   MIN(e.event_time) as event_start_time_visit,
	   SUM(CASE WHEN ei.event_name = 'Page View' THEN 1 ELSE 0 END) as page_views,
	   SUM(CASE WHEN ei.event_name = 'Add to Cart' THEN 1 ELSE 0 END) as cart_adds,
	   SUM(CASE WHEN ei.event_name = 'Purchase' THEN 1 ELSE 0 END),
	   c.campaign_name,
	   SUM(CASE WHEN ei.event_name = 'Ad Impression' THEN 1 ELSE 0 END) as impressions,
	   SUM(CASE WHEN ei.event_name = 'Ad Click' THEN 1 ELSE 0 END) as click,
	   STRING_AGG(CASE WHEN ei.event_name = 'Add to Cart' THEN ep.page_name END, ', ')
		WITHIN GROUP (ORDER BY e.sequence_number) as cart_products
FROM clique_bait.users_c u
JOIN clique_bait.events e ON u.cookie_id = e.cookie_id
JOIN clique_bait.event_identifier ei ON ei.event_type = e.event_type
JOIN clique_bait.page_hierarchy ep ON ep.page_id = e.page_id
LEFT JOIN clique_bait.campaign_identifier c ON e.event_time BETWEEN c.start_date AND c.end_date
GROUP BY u.user_id, e.visit_id, c.campaign_name;