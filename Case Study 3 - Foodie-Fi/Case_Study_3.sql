---------------------------------------------------------

		------ Case Study 3 Solutions ------

----------------------------------------------------------

SELECT * FROM plans;

SELECT * FROM subscriptions;

/*
Based off the 8 sample customers provided in the sample from the subscriptions table, 
write a brief description about each customer’s onboarding journey.

Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!
*/

SELECT s.customer_id, s.plan_id, p.plan_name, s.start_date
FROM subscriptions s
JOIN plans p
ON s.plan_id = p.plan_id
WHERE s.customer_id IN (1, 2, 11, 13, 15, 16, 18, 19);

/*

As it is seen from the above query results:
	customer_id - 1 : Started the Free Trial on Aug 1, 2020 and then downgraded to take the basic monthly plan.

	customer_id - 2 : Started the Free Trial on Sep 20, 2020 and then upgraded with the pro annual plan.

	customer_id - 11 : Started the Free Trial on Nov 19, 2020 and then churned it once the free trial ended.

	customer_id - 13 : Strarted the Free Trial on Dec 15, 2020 and then downgraded to the basic montly plan 
					   and upgraded to the pro monthly after 3 months on 29 march.

	customer_id - 15 : Started the Free Trial on Mar 17, 2020, then continued with the pro monthly (default) once the free trial ended,
					   But later went on to churn it little over the next month on Apr 29, 2020.

	customer_id - 16 : Started the Free Trial on May 31, 2020 and then downgraded to basic montly plan, and upgraded to the pro annual
					   after 4 months later on 2020,10,21

	customer_id - 18 : Started the Free Trial on Jul 6, 2020 and then continued with the pro monthly plan once the free trial ended.

	customer_id - 19 : Started the Free Trial on Jun 22, 20202 and then continued with the pro monthly plan and
					   later one month the customer the took the pro annual plan on Aug, 29, 2020 */

	-- PART 1 - DATA ANALYSIS QUESTIONS

-- How many customers has Foodie-Fi ever had?

SELECT COUNT(DISTINCT(customer_id)) as unique_customer_count
FROM subscriptions;

-- What is the monthly distribution of trial plan start_date values for our dataset - 
-- use the start of the month as the group by value

SELECT DATEPART(month, start_date) as month, DATENAME(month, start_date) as month_name, count(start_date) as free_trial_start_month
FROM subscriptions
WHERE plan_id = 0
GROUP BY DATEPART(month, start_date), DATENAME(month, start_date)
ORDER BY month;

-- What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

SELECT s.plan_id, p.plan_name, count(s.plan_id) as plan_used_counts
FROM subscriptions s
JOIN plans p
ON p.plan_id = s.plan_id
WHERE DATEPART(YEAR, start_date) > '2020'
GROUP BY s.plan_id, p.plan_name
ORDER BY plan_used_counts;

SELECT * FROM plans;
-- What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

SELECT count(CASE WHEN p.plan_name = 'churn' THEN 1 END) as customers_churned, 
												  CAST(ROUND(count(CASE WHEN p.plan_name = 'churn' THEN 1 END) * 1.0 / 
												  count(distinct s.customer_id) * 100, 1) AS DECIMAL (3,1)) as perc_churned
FROM subscriptions s
JOIn plans p
ON s.plan_id = p.plan_id;

-- How many customers have churned straight after their initial free trial - 
-- what percentage is this rounded to the nearest whole number?

WITH ranking as(
SELECT s.customer_id, s.plan_id, s.start_date, RANK() OVER(PARTITION BY s.customer_id ORDER BY s.start_date) as rnk
FROM subscriptions s)

SELECT count(CASE WHEN p.plan_id = 4 and r.rnk = 2 THEN 1 END) as customers_churned_after_free_trial,
	   count(CASE WHEN p.plan_id = 4 THEN 1 END) as total_churn,
	   count(distinct(r.customer_id)) as total_customers,
	   CAST(count(CASE WHEN p.plan_id = 4 and r.rnk = 2 THEN 1 END) * 1.0 /
	   count(distinct r.customer_id) * 100 AS DECIMAL(3, 1)) as churn_perc
FROM ranking r
JOIN plans p
ON r.plan_id = p.plan_id;

-- What is the number and percentage of customer plans after their initial free trial?
WITH ranking as(
SELECT *,
	   RANK() OVER(PARTITION BY customer_id ORDER BY start_date) as rnk
FROM subscriptions)

SELECT r.plan_id, 
	   p.plan_name, 
	   count(CASE WHEN r.rnk =2 THEN 1 END) as count_by_plans,
	   (SELECT COUNT(*) FROM ranking r2 WHERE r2.rnk = 2) as total_customers,
	   CAST(count(CASE WHEN r.rnk =2 THEN 1 END) * 1.0 / 
		(SELECT COUNT(*) FROM ranking r2 WHERE r2.rnk = 2) * 100 AS DECIMAL(3, 1)) as perc
FROM ranking r
JOIN plans p 
ON r.plan_id = p.plan_id
WHERE r.rnk = 2
GROUP BY r.plan_id, p.plan_name


-- What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH cte as (
    SELECT 
        s.customer_id, 
        p.plan_name, 
        p.plan_id, 
        s.start_date, 
        RANK() OVER(PARTITION BY s.customer_id ORDER BY s.start_date DESC) as rnk
    FROM plans p
    JOIN subscriptions s
    ON p.plan_id = s.plan_id
    WHERE s.start_date <= '2020-12-31'
)

SELECT cte.plan_name, 
	   count(cte.plan_id) as customer_count, 
	   (SELECT COUNT(*) FROM cte cte1 WHERE cte1.rnk = 1) as total_count,
	   CAST(count(cte.plan_id) * 1.0 / (SELECT COUNT(*) FROM cte cte1 WHERE cte1.rnk = 1) * 100 AS DECIMAL(3,1)) as perc
FROM cte
WHERE cte.rnk = 1
GROUP BY plan_name
ORDER BY customer_count DESC


-- How many customers have upgraded to an annual plan in 2020?

SELECT p.plan_name, count(s.customer_id) as pro_annual_customers
FROM subscriptions s
JOIN plans p
ON s.plan_id = p.plan_id
WHERE DATEPART(YEAR, start_date) = '2020' and  p.plan_name = 'pro annual'
GROUP BY p.plan_name;

-- How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH cte_1 as(
SELECT customer_id, MIN(start_date) as starting_date
FROM subscriptions
GROUP BY customer_id),

cte_2 as(
SELECT customer_id, MIN(start_date) as pro_annual_starting_date
FROM subscriptions
WHERE plan_id = 3
GROUP BY customer_id
)

SELECT AVG(DATEDIFF(DAY, starting_date, pro_annual_starting_date)) as date_diff
FROM cte_1
JOIN cte_2
ON cte_1.customer_id = cte_2.customer_id

-- Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

WITH cte_1 as(
	SELECT customer_id, MIN(start_date) as starting_date
	FROM subscriptions
	GROUP BY customer_id
),

cte_2 as(
	SELECT customer_id, MIN(start_date) as pro_annual_starting_date
	FROM subscriptions
	WHERE plan_id = 3
	GROUP BY customer_id
)

SELECT  
CASE WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 30 THEN '0-30'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 60 THEN '31-60'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 90 THEN '61-90'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 120 THEN '91-120'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 150 THEN '121-150'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 180 THEN '151-180'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 210 THEN '181-210'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 240 THEN '211-240'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 270 THEN '241-270'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 300 THEN '271-300'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 330 THEN '301-330'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 360 THEN '331-360'
	 END as date_diff,
	 count(cte_1.customer_id) as count_of_customers
FROM cte_1
JOIN cte_2
ON cte_1.customer_id = cte_2.customer_id
GROUP BY CASE WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 30 THEN '0-30'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 60 THEN '31-60'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 90 THEN '61-90'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 120 THEN '91-120'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 150 THEN '121-150'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 180 THEN '151-180'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 210 THEN '181-210'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 240 THEN '211-240'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 270 THEN '241-270'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 300 THEN '271-300'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 330 THEN '301-330'
	 WHEN DATEDIFF(day, cte_1.starting_date, cte_2.pro_annual_starting_date) <= 360 THEN '331-360'
	 END
ORDER BY date_diff;

-- How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

SELECT count(customer_id) as customer_count
FROM(
SELECT s1.customer_id, s1.start_date as pro_monthly_start_date, s2.start_date as basic_monthly_start_date
FROM subscriptions s1
JOIN subscriptions s2
ON s1.customer_id = s2.customer_id AND s1.plan_id - 1 = s2.plan_id
WHERE s2.plan_id = 1)x
WHERE x.pro_monthly_start_date < x.basic_monthly_start_date AND DATEPART(YEAR, x.basic_monthly_start_date) = '2020';


/*

C. Challenge Payment Question

The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer 
in the subscriptions table with the following requirements:

- monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
- upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
- upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts 
  at the end of the month period
- once a customer churns they will no longer make payments
*/

/*with first_condition as(
SELECT s.customer_id, s.plan_id, p.plan_name, s.start_date, 
	   ROW_NUMBER() OVER(PARTITION BY s.customer_id ORDER BY start_date DESC) as last_payment_date
FROM subscriptions s
JOIN plans p
ON s.plan_id = p.plan_id
WHERE s.plan_id != 0 and DATEPART(YEAR, s.start_date) = '2020')

SELECT *, 
	   CASE WHEN (plan_id != 4 and plan_id != 3) and DATEPART(MONTH, start_date) != 12 THEN 
FROM first_condition;*/

WITH churn_data as(
SELECT s.customer_id, s.plan_id, p.plan_name, s.start_date, p.price as amount,
	   LEAD(start_date) OVER(PARTITION BY s.customer_id ORDER BY s.start_date, s.plan_id) as cutoff_date
FROM subscriptions s
JOIN plans p
ON s.plan_id = p.plan_id
WHERE s.plan_id != 0 and DATEPART(YEAR, s.start_date) = '2020'),

churn_data_sorted as(
SELECT customer_id, plan_id, plan_name, start_date, 
	   COALESCE(cutoff_date, CASE WHEN plan_id = 4 THEN start_date ELSE '2020-12-31' END) as new_cutoff, amount
FROM churn_data
),

sorted_cte as(
SELECT customer_id, plan_id, plan_name, start_date, new_cutoff, amount FROM churn_data_sorted
WHERE plan_id ! = 4
UNION ALL
SELECT customer_id, plan_id, plan_name, DATEADD(MONTH, 1, start_date) as start_date, new_cutoff, amount 
FROM sorted_cte
WHERE new_cutoff > DATEADD(MONTH, 1, start_date) AND plan_id != 3),
 
last_cte as(
SELECT customer_id, plan_id, plan_name, start_date, amount, 
	   LAG(plan_id) OVER(PARTITION BY customer_id ORDER BY start_date) as last_payment_plan,
	   LAG(amount) OVER(PARTITION BY customer_id ORDER BY start_date) as last_amount_paid,
	   RANK() OVER(PARTITION BY customer_id ORDER BY start_date) as payment_order
FROM sorted_cte
)

SELECT customer_id, plan_id, plan_name, start_date,
(CASE WHEN plan_id IN (2,3) and last_payment_plan = 1 THEN amount - last_amount_paid ELSE amount END) as amount, payment_order
FROM last_cte;

--------------------------------------------------------------------------------
with churn_data as( 
SELECT s.customer_id, 
	   s.plan_id, 
	   p.plan_name, 
	   s.start_date, 
	   LEAD(s.start_date) OVER(PARTITION BY customer_id ORDER BY s.start_date, s.plan_id) as cutoff_date,
	   p.price as amount
FROM subscriptions s
JOIN plans p
ON s.plan_id = p.plan_id
WHERE s.plan_id != 0 and DATEPART(YEAR, start_date) = '2020'),

churn_data_sorted as(
SELECT customer_id, plan_id, plan_name, start_date,
	   COALESCE(cutoff_date, CASE WHEN plan_id = 4 THEN start_date ELSE '2020-12-31' END) as new_cutoff, amount
FROM churn_data
),

sorted_cte as(
SELECT customer_id, plan_id, plan_name, start_date, new_cutoff, amount
FROM churn_data_sorted
WHERE plan_id != 4
UNION ALL
SELECT customer_id, plan_id, plan_name, DATEADD(MONTH, 1, start_date) as start_date, new_cutoff, amount
FROM sorted_cte
WHERE new_cutoff > DATEADD(MONTH, 1, start_date) and plan_id != 3
),
last_cte as(
SELECT customer_id, plan_id, plan_name, 
	   LAG(plan_id) OVER(PARTITION BY customer_id ORDER BY start_date) as last_payment_plan,
	   LAG(amount) OVER(PARTITION BY customer_id ORDER BY start_date) as last_paid_amount,
	   RANK() OVER(PARTITION BY customer_id ORDER BY start_date) as payment_orders,
	   start_date, new_cutoff, amount 
FROM sorted_cte
)

SELECT customer_id, plan_id, plan_name, start_date,
	   CASE WHEN plan_id IN (2, 3) and last_payment_plan = 1 THEN amount - last_paid_amount ELSE amount END as amount,
	   payment_orders
FROM last_cte;