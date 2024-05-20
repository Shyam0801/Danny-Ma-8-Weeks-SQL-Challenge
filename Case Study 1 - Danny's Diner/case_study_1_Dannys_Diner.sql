/*-----------------------------------------------
	
	Case Study #1: Danny's Diner - SOLUTION

-------------------------------------------------*/



-- What is the total amount each customer spent at the restaurant?

SELECT s.customer_id, SUM(m.price) as total_spent
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id;


-- How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT(order_date)) as visited_count
FROM sales
GROUP BY customer_id;

-- What was the first item from the menu purchased by each customer?

SELECT x.customer_id, x.product_name
FROM(
SELECT s.customer_id, 
	DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) as rnk, m.product_name
FROM sales s
JOIN menu m
ON s.product_id = m.product_id) x
WHERE x.rnk = 1
GROUP BY customer_id, product_name;


-- What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT Top 1 m.product_name, count(s.product_id) as purchase_count
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY purchase_count DESC;


-- Which item was the most popular for each customer?

SELECT customer_id, product_name
FROM
(
	SELECT s.customer_id, s.product_id, count(s.product_id) as purchase_count, m.product_name, 
	DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY count(s.product_id) DESC) as rnk
	FROM sales s
	JOIN menu m
	ON s.product_id = m.product_id
	GROUP BY s.customer_id, s.product_id, m.product_name
)x
WHERE x.rnk = 1;

-- Which item was purchased first by the customer after they became a member?

SELECT customer_id, product_name
FROM (
		SELECT s.customer_id, s.product_id, s.order_date, m.product_name,
			   DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) as rnk
		FROM sales s
		JOIN menu m
		ON s.product_id = m.product_id
		JOIN members mm
		ON s.customer_id = mm.customer_id
		WHERE s.order_date > mm.join_date
) x
WHERE x.rnk = 1
GROUP BY customer_id, product_name;

-- Which item was purchased just before the customer became a member?

SELECT customer_id, product_name
FROM(
	SELECT s.customer_id, s.product_id, s.order_date, m.product_name,
		   ROW_NUMBER() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC) as rnk
	FROM sales s
	JOIN menu m
	ON s.product_id = m.product_id
	JOIN members mm
	ON s.customer_id = mm.customer_id
	WHERE s.order_date < mm.join_date
) x
WHERE x.rnk = 1

-- What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, COUNT(s.product_id) as product_count, SUM(m.price) as total_spent
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
JOIN members mm
ON s.customer_id = mm.customer_id
WHERE s.order_date < mm.join_date
GROUP BY s.customer_id

-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT s.customer_id,
	   SUM(CASE WHEN m.product_name = 'sushi' then m.price * 20 else m.price * 10 end ) as points
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
	-- not just sushi - how many points do customer A and B have at the end of January?

SELECT s.customer_id,
	   SUM(CASE WHEN s.order_date BETWEEN mm.join_date and DATEADD(day, 6, mm.join_date) THEN m.price * 2 * 10
				WHEN m.product_name = 'sushi' THEN m.price * 10 * 2
				ELSE m.price * 10 END) as points
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
JOIN members mm
ON s.customer_id = mm.customer_id
WHERE MONTH(s.order_date) = 1
      AND YEAR(s.order_date) = 2021
GROUP BY s.customer_id;

/*
Bonus Questions

Recreate the following table output using the available data:

customer_id	order_date	product_name	price	member*/

SELECT  s.customer_id, s.order_date, m.product_name, m.price,
		CASE WHEN s.order_date >= mm.join_date THEN 'Y' ELSE 'N' END as member
FROM sales s
JOIN menu m
ON m.product_id = s.product_id
LEFT JOIN members mm
ON mm.customer_id = s.customer_id;

/* 

Danny also requires further information about the ranking of customer products,
but he purposely does not need the ranking for non-member purchases 
so he expects null ranking values for the records when customers 
are not yet part of the loyalty program.

customer_id	order_date	product_name	price	member	ranking

*/
SELECT x.*, CASE WHEN member_status = 'N' THEN NULL 
		    ELSE DENSE_RANK() OVER(PARTITION BY customer_id, product_name ORDER BY order_date) end as ranking
FROM
(
SELECT  s.customer_id, s.order_date, m.product_name, m.price,
		CASE WHEN s.order_date >= mm.join_date THEN 'Y' ELSE 'N' END as member_status
FROM sales s
JOIN menu m
ON m.product_id = s.product_id
LEFT JOIN members mm
ON mm.customer_id = s.customer_id) x;