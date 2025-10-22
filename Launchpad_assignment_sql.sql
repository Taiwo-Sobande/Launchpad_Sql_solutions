-- 1) Count the total number of customers who joined in 2023.

SELECT
	COUNT(customer_id)
FROM customers
WHERE DATE_PART('year', join_date)= 2023;


/* 2)For each customer return customer_id, full_name, total_revenue (sum of total_amount from orders).
Sort descending.
*/
SELECT
	c.customer_id,
	full_name,
	SUM(o.total_amount) AS total_revenue
FROM customers c
LEFT JOIN orders o
	ON c.customer_id= o.customer_id
GROUP BY c.customer_id, full_name
ORDER BY total_revenue DESC;


-- 3) Return the top 5 customers by total_revenue with their rank.

WITH cte AS(
SELECT
	c.customer_id,
	full_name,
	SUM(o.total_amount) AS total_revenue,
	RANK() OVER(ORDER BY SUM(o.total_amount) DESC) AS ranking
FROM customers c
LEFT JOIN orders o
	ON c.customer_id= o.customer_id
GROUP BY c.customer_id, full_name
)

SELECT * FROM CTE WHERE ranking < 6;


-- 4)  Produce a table with year, month, monthly_revenue for all months in 2023 ordered chronologically.

SELECT
	DATE_PART('year', join_date),
	TO_CHAR(join_date, 'month'),
	SUM(o.total_amount) AS monthly_revenue
FROM customers c
LEFT JOIN orders o
	ON c.customer_id= o.customer_id
WHERE DATE_PART('year', join_date)= 2023
GROUP BY DATE_PART('year', join_date),TO_CHAR(join_date, 'month'), DATE_PART('month', join_date)
ORDER BY DATE_PART('month', join_date) ASC;


/* 5) Find customers with no orders in the last 60 days relative to 2023-12-31 (i.e., consider last active date up to 2023-12-31).
Return customer_id, full_name, last_order_date.*/

SELECT
	c.customer_id,
	full_name,
	MAX(order_date) AS last_order_date
	--count(order_id) AS number_of_orders
FROM customers c
LEFT JOIN orders o
	ON c.customer_id= o.customer_id
GROUP BY c.customer_id, full_name
HAVING MAX(order_date) < '2023-12-31'::DATE - INTERVAL '60 days'
		OR MAX(order_date) IS NULL;


/* 6) Calculate average order value (AOV) for each customer: return customer_id, full_name, aov (average total_amount of their orders).
Exclude customers with no orders.*/

SELECT
	c.customer_id,
	full_name,
	AVG(o.total_amount) AS average_order_value
FROM customers c
INNER JOIN orders o
	ON c.customer_id= o.customer_id
GROUP BY c.customer_id, full_name
ORDER BY customer_id;


/* 7) For all customers who have at least one order,compute customer_id, full_name, total_revenue, spend_rank
where spend_rank is a dense rank, highest spender = rank 1.*/

SELECT
	c.customer_id,
	full_name,
	SUM(o.total_amount) AS total_revenue,
	DENSE_RANK() OVER(ORDER BY SUM(o.total_amount) DESC) AS spend_rank
FROM customers c
INNER JOIN orders o
	ON c.customer_id= o.customer_id
GROUP BY c.customer_id, full_name;


/* 8) List customers who placed more than 1 order and
show customer_id, full_name, order_count, first_order_date, last_order_date.*/

SELECT
	c.customer_id,
	full_name,
	COUNT(order_id) AS order_count,
	MIN(order_date) first_order_date,
	MAX(order_date) last_order_date,
	SUM(o.total_amount) AS total_revenue
FROM customers c
INNER JOIN orders o
	ON c.customer_id= o.customer_id
GROUP BY c.customer_id, full_name
HAVING COUNT(order_id)>1;


/* 9) Compute total loyalty points per customer. Include customers with 0 points.*/

SELECT
	c.customer_id,
	full_name,
	SUM(points_earned) AS total_loyalty_points
FROM customers c
LEFT JOIN loyalty_points l
	ON c.customer_id= l.customer_id
GROUP BY c.customer_id, full_name
ORDER BY customer_id;


/* 10) 
Assign loyalty tiers based on total points:
Bronze: < 100
Silver: 100–499
Gold: >= 500
Output: tier, tier_count, tier_total_points*/

WITH cte AS(
SELECT
	c.customer_id,
	SUM(points_earned) AS total_loyalty_points,
	CASE WHEN SUM(points_earned) < 100 THEN 'Bronze'
		 WHEN SUM(points_earned) BETWEEN 100 AND 499 THEN 'Silver'
		 WHEN SUM(points_earned) >= 500 THEN 'Gold'
	END AS tier
FROM customers c
LEFT JOIN loyalty_points l
	ON c.customer_id= l.customer_id
GROUP BY c.customer_id, full_name
)

SELECT
	tier,
	COUNT(customer_id) AS tier_count,
	SUM(total_loyalty_points) AS tier_total_points
FROM cte
GROUP BY tier;


/* 11) Identify customers who spent more than ₦50,000 in total but have less than 200 loyalty points.
Return customer_id, full_name, total_spend, total_points.*/

SELECT
	c.customer_id,
	full_name,
	SUM(o.total_amount) AS total_spend,
	SUM(l.points_earned) AS total_points
FROM customers c
INNER JOIN orders o
	ON c.customer_id= o.customer_id
INNER JOIN loyalty_points l
	ON c.customer_id= l.customer_id
GROUP BY c.customer_id, full_name
HAVING SUM(o.total_amount)> 50000 AND SUM(l.points_earned)<200
ORDER BY customer_id;



/* 12) Flag customers as churn_risk if they have no orders in the last 90 days (relative to 2023-12-31)
AND are in the Bronze tier. Return customer_id, full_name, last_order_date, total_points.*/

WITH cte AS(
SELECT
	c.customer_id,
	full_name,
	MAX(order_date) AS last_order_date,
	SUM(points_earned) AS total_points,
	CASE WHEN SUM(points_earned) < 100 THEN 'Bronze'
		 WHEN SUM(points_earned) BETWEEN 100 AND 499 THEN 'Silver'
		 WHEN SUM(points_earned) >= 500 THEN 'Gold'
	END AS tier
FROM customers c
LEFT JOIN orders o
	ON c.customer_id= o.customer_id
LEFT JOIN loyalty_points l
	ON c.customer_id= l.customer_id
GROUP BY c.customer_id, full_name
)

SELECT
	customer_id,
	full_name,
	last_order_date,
	total_points
FROM cte
WHERE (last_order_date < '2023-12-31' :: DATE -  INTERVAL '90 days') AND tier = 'Bronze'
ORDER BY customer_id