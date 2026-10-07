
-- ===================================================================
--  SECTION A: Executive Performance & Demand
-- ===================================================================


-- What is the overall scale of completed sales in terms of revenue, orders, and units sold?
SELECT 
	CAST(ROUND(SUM(signed_line_value), 2) AS DECIMAL(18, 2)) AS Total_Revenue,
	COUNT(DISTINCT invoice) AS Total_Orders,
	SUM(quantity) AS Total_Units_Sold
FROM analytics.vw_sales_lines
WHERE transaction_type = 'completed sale'


-- How does completed sales performance change over time?
SELECT 
	d.calendar_year,
	d.month_name,
	CAST(ROUND(SUM(sl.signed_line_value), 2) AS DECIMAL(18, 2)) AS Total_Revenue,
    COUNT(DISTINCT sl.invoice) AS Total_Orders,
	SUM(sl.quantity) AS Total_Units_Sold

FROM analytics.vw_sales_lines AS  sl

JOIN analytics.dim_date AS d
ON sl.invoice_calendar_date = d.calendar_date

WHERE sl.transaction_type = 'completed sale'

GROUP BY d.calendar_year,d.month_number, d.month_name
ORDER BY d.calendar_year, d.month_number
	

-- How does completed sales vary by day of week?
SELECT 
	d.day_name AS Weekdays,
	CAST(ROUND(SUM(sl.signed_line_value), 2) AS DECIMAL(18, 2)) AS Total_Revenue,
    COUNT(DISTINCT sl.invoice) AS Total_Orders,
	SUM(sl.quantity) AS Total_Units_Sold

FROM analytics.vw_sales_lines AS  sl

JOIN analytics.dim_date AS d
ON sl.invoice_calendar_date = d.calendar_date

WHERE sl.transaction_type = 'completed sale'

GROUP BY d.day_name
ORDER BY 2 DESC, 3 DESC, 4 DESC


-- -- How does completed sales vary by Hour of Day?
SELECT 
	DATEPART(HOUR, invoice_date) AS Hour_of_Day,
	CAST(ROUND(SUM(signed_line_value), 2) AS DECIMAL(18, 2)) AS Total_Revenue,
    COUNT(DISTINCT invoice) AS Total_Orders,
	SUM(quantity) AS Total_Units_Sold
FROM analytics.vw_sales_lines 
WHERE transaction_type = 'completed sale'
GROUP BY DATEPART(HOUR, invoice_date)
ORDER BY 1, 2 DESC

-- Is business growth based on comparable periods? 

WITH period_KPIs AS(
	SELECT 
		d.calendar_year,
		SUM(signed_line_value) AS Total_Revenue,
		CAST(COUNT(DISTINCT invoice) AS DECIMAL(18,2)) AS Total_Orders,
		CAST(SUM(quantity) AS DECIMAL(18,2)) AS Total_Units_Sold,
        SUM(sl.signed_line_value) / COUNT(DISTINCT sl.invoice) AS Avg_Order_Value
	FROM analytics.vw_sales_lines sl
	JOIN analytics.dim_date d
		ON SL.invoice_calendar_date = d.calendar_date
	WHERE sl.transaction_type = 'completed sale' 
		AND 
			( d.calendar_date BETWEEN '2010-01-01' AND '2010-12-09'
				OR
			 d.calendar_date BETWEEN '2011-01-01' AND '2011-12-09'
			)
	GROUP by d.calendar_year
)
-- Percentage growth in the KPIs Comparing from  2010-01-01 to 2010-12-09 AND 2011-01-01 to 2011-12-09
SELECT *,
    CAST(100 * (
			Avg_Order_Value - LAG(Avg_Order_Value) OVER(ORDER BY calendar_year)
		  ) / LAG(Avg_Order_Value) OVER(ORDER BY calendar_year) AS DECIMAL(18,2)) AS Pct_Change_AOV,
	CAST(100 * (
			Total_Revenue - LAG(Total_Revenue) OVER(ORDER BY calendar_year)
		  ) / LAG(Total_Revenue) OVER(ORDER BY calendar_year) AS DECIMAL(18,2)) AS Pct_Change_Revenue,

	CAST(100 * (Total_Orders - LAG(Total_Orders) OVER(ORDER BY calendar_year)
		) / LAG(Total_Orders) OVER(ORDER BY calendar_year) AS DECIMAL(18,2)) AS Pct_Change_Orders, 

	CAST(100 * (Total_Units_Sold - LAG(Total_Units_Sold) OVER(ORDER BY calendar_year)
	) / LAG(Total_Units_Sold) OVER(ORDER BY calendar_year) AS DECIMAL(18,2)) AS Pct_Change_Units
FROM period_KPIs;

/*
For the comparable periods of January 1 to December 9, 2010 and 2011, completed-sales revenue 
declined by only 0.88%, despite larger declines in orders and units sold of approximately 
4.5% and 6.4%, respectively. Average order value increased by approximately 3.8%, meaning that 
the average order generated more revenue in 2011. This higher average order value helped offset the
decline in order volume, resulting in a relatively small overall decline in revenue.
*/

-- ================================================================================================
-- SECTION B: Product Demand and  Baskets
-- ================================================================================================
-- Which product generate the most completed sales revenue?

SELECT
	stock_code,
	product_description AS Product,
	CAST(SUM(signed_line_value) AS DECIMAL(18,2)) AS Revenue,
	SUM(quantity) AS Units_Sold,
	COUNT(DISTINCT invoice) AS Orders,
	CAST(SUM(signed_line_value) / SUM(quantity) AS DECIMAL(18,2)) AS Avg_Revenue_per_Unit
FROM analytics.vw_sales_lines
WHERE transaction_type = 'completed sale'
GROUP BY 
	stock_code, 
	product_description
ORDER BY  Revenue DESC;


--Which products drive volume rather than value?
SELECT 
	stock_code,
	product_description AS Product,
	CAST(SUM(signed_line_value) AS DECIMAL(18,2)) AS Revenue,
	DENSE_RANK() OVER(ORDER BY SUM(signed_line_value) DESC) AS Revenue_rank,
	SUM(quantity) AS Units_Sold,
	DENSE_RANK() OVER(ORDER BY SUM(quantity) DESC) AS Units_Sold_rank,
	COUNT(DISTINCT invoice) AS Orders,
	DENSE_RANK() OVER(ORDER BY COUNT(DISTINCT invoice) DESC) AS Orders_rank
FROM analytics.vw_sales_lines
WHERE transaction_type = 'completed sale'
GROUP BY 
	stock_code, 
	product_description
ORDER BY  Revenue DESC;


-- What does a typical completed order look like?
WITH Order_groups AS(
SELECT
	invoice AS Orders_id,
	SUM(signed_line_value) AS Order_value,
	SUM(quantity) AS Order_units,
	COUNT(DISTINCT stock_code) AS Distinct_products
FROM analytics.vw_sales_lines
WHERE transaction_type = 'completed sale'
GROUP BY invoice
),
Order_Stats AS(
	SELECT 
		*,
		PERCENTILE_CONT(0.5) WITHIN GROUP(
		ORDER BY order_value) OVER() AS median_order_value
	FROM Order_groups
)
SELECT 
    CAST(AVG(order_value) AS DECIMAL(18,2)) AS Average_order_value,
    CAST(MAX(median_order_value) AS DECIMAL(18,2)) AS Median_order_value,
    CAST(AVG(order_units * 1.0) AS DECIMAL(18,2)) AS Average_units_per_order,
    CAST(AVG(distinct_products * 1.0) AS DECIMAL(18,2)) AS Average_products_per_rder,
    CAST(MAX(order_value) AS DECIMAL(18,2)) AS largest_order_value
FROM Order_stats;


-- To what extent is completed-sales revenue concentrated in a small number of large orders?

-- What percentage of total completed-sales revenue comes from the largest 1% of completed orders?
WITH base AS(
	SELECT
		invoice AS order_id,
		SUM(signed_line_value) AS revenue
	FROM analytics.vw_sales_lines
	WHERE transaction_type = 'completed sale'
	GROUP BY invoice
),
revenue_level AS(
	SELECT 
		order_id,
		revenue,
		NTILE(100) OVER(ORDER BY revenue DESC) AS revenue_tile
	FROM base
)
SELECT
	CAST(
		SUM(revenue) AS DECIMAL(18,2)
		) AS top_1_pct_revenue,
	CAST(
		100.0 * SUM(revenue) / (SELECT SUM(revenue) FROM base)
		AS DECIMAL(18, 2)) AS top_1_pct_revenue_share
FROM revenue_level
WHERE revenue_tile = 1;


-- ======================================================================================
-- SECTION C: Markets and operational risk
-- ======================================================================================

-- Revenue generated  by each country and their percentage contibution to toal revenue
SELECT
	country,
	CAST(
		SUM(signed_line_value) 
		AS DECIMAL(18,2)) AS total_revenue,
	100.0 * SUM(signed_line_value) / SUM(SUM(signed_line_value)) OVER() AS revenue_share_pct
FROM analytics.vw_sales_lines
WHERE transaction_type = 'completed sale'
GROUP BY country
ORDER BY revenue_share_pct DESC;


-- Non UK markets that are commercially important
WITH country_metrics AS(
SELECT 
	country,
	COUNT(DISTINCT invoice) AS orders,
	SUM(quantity) AS units_sold,
	SUM(signed_line_value) AS revenue,
	SUM(signed_line_value) / COUNT(DISTINCT invoice) AS average_order_value,
	100.0 * 
		SUM(signed_line_value) / SUM(SUM(signed_line_value)) OVER () AS revenue_share_pct,
	SUM(CASE 
			WHEN invoice_date >= '2010-01-01' 
			AND invoice_date <= '2010-12-09'
			THEN signed_line_value
			ELSE 0
		END
	) AS revenue_2010,
	SUM(CASE 
			WHEN invoice_date >= '2011-01-01' 
			AND invoice_date <= '2011-12-09'
			THEN signed_line_value
			ELSE 0
		END
	)AS revenue_2011
FROM analytics.vw_sales_lines
WHERE transaction_type = 'completed sale'
	AND country <> 'United Kingdom'
GROUP BY country
)
SELECT
	country,
	orders,
	CAST(revenue AS DECIMAL(18,2)) AS revenue,
	CAST(average_order_value AS DECIMAL(18,2)) AS average_order_value,
	CAST(revenue_share_pct AS DECIMAL(18,2)) AS revenue_share_pct,
	CAST(
		100.0 * (revenue_2011 - revenue_2010) / NULLIF(revenue_2010, 0)
		AS DECIMAL(18,2)) AS like_for_like_growth
FROM country_metrics
ORDER BY revenue_share_pct DESC;


-- What is the sale of cancellation activity
WITH completed_sales AS (
    SELECT
        SUM(signed_line_value) AS completed_sales_revenue
    FROM analytics.vw_sales_lines
    WHERE transaction_type = 'completed sale'
)
SELECT
    COUNT(*) AS cancellation_lines,
    COUNT(DISTINCT invoice) AS cancelled_invoices,
    SUM(v.quantity) AS cancelled_quantity,
    SUM(v.signed_line_value) AS cancellation_value,
    CAST(
        100.0 * SUM(v.signed_line_value)
        / NULLIF(MAX(cs.completed_sales_revenue), 0)
        AS DECIMAL(18,2)
    ) AS cancellation_vs_revenue_value_pct
FROM analytics.vw_sales_lines AS v
CROSS JOIN completed_sales AS cs
WHERE v.transaction_type = 'cancellation';


-- Which products have the highest cancellation exposure?
WITH Product_lookup AS(
SELECT
	stock_code,
	CASE 
		WHEN COUNT(DISTINCT product_description) = 1 
			THEN MAX(product_description)
		WHEN COUNT(DISTINCT product_description) > 1 
			THEN 'MULTIPLE DESCRIPTIONS'
		ELSE NULL
	END AS product_description
FROM analytics.vw_sales_lines
GROUP BY stock_code
), 
complete_metrics AS (
    SELECT
        stock_code,
        COUNT(DISTINCT invoice) AS completed_invoices,
        SUM(quantity) AS completed_units,
        SUM(signed_line_value) AS completed_sales_value
    FROM analytics.vw_sales_lines
    WHERE transaction_type = 'completed sale'
    GROUP BY stock_code
),
cancel_metrics AS (
    SELECT
        stock_code,
        COUNT(DISTINCT invoice) AS cancellation_invoices,
        SUM(quantity) AS cancelled_units,
        SUM(signed_line_value) AS cancellation_value
    FROM analytics.vw_sales_lines
    WHERE transaction_type = 'cancellation'
    GROUP BY stock_code
)
SELECT
    COALESCE(cm.stock_code, cx.stock_code) AS stock_code,
	pl.product_description,
    COALESCE(cm.completed_invoices, 0) AS completed_invoices,
    COALESCE(cm.completed_units, 0) AS completed_units,
    COALESCE(cm.completed_sales_value, 0) AS completed_sales_value,
    COALESCE(cx.cancellation_invoices, 0) AS cancellation_invoices,
    COALESCE(cx.cancelled_units, 0) AS cancelled_units,
    COALESCE(cx.cancellation_value, 0) AS cancellation_value
FROM complete_metrics AS cm
FULL OUTER JOIN cancel_metrics AS cx
    ON cm.stock_code = cx.stock_code
LEFT JOIN product_lookup AS pl
    ON pl.stock_code = COALESCE(cm.stock_code, cx.stock_code)
ORDER BY ABS(COALESCE(cx.cancellation_value, 0)) DESC;


-- Which countries have the highest cancellation exposure?
WITH cancel_metrics AS (
    SELECT
        country,
        COUNT(DISTINCT invoice) AS cancellation_invoices,
        SUM(quantity) AS cancelled_units,
        SUM(signed_line_value) AS cancellation_value
    FROM analytics.vw_sales_lines
    WHERE transaction_type = 'cancellation'
    GROUP BY country
),
complete_metrics AS (
    SELECT
        country,
        COUNT(DISTINCT invoice) AS completed_invoices,
        SUM(signed_line_value) AS completed_sales_revenue
    FROM analytics.vw_sales_lines
    WHERE transaction_type = 'completed sale'
    GROUP BY country
)
SELECT
    cx.country,
    cx.cancellation_value,
    cx.cancelled_units,
    cx.cancellation_invoices,
    COALESCE(cm.completed_sales_revenue, 0) AS completed_sales_revenue,
    COALESCE(cm.completed_invoices, 0) AS completed_invoices
FROM cancel_metrics AS cx
LEFT JOIN complete_metrics AS cm
    ON cx.country = cm.country
ORDER BY ABS(cx.cancellation_value) DESC;


-- What is the scale and timing of bad-debt adjustments?
SELECT 
	YEAR(invoice_date) AS bad_debt_period,
	COUNT(*) AS bad_debt_count,
	CAST(SUM(signed_line_value) AS DECIMAL(18,2)) AS signed_adjustment_value
FROM analytics.vw_sales_lines
WHERE transaction_type = 'bad debt adjustment'
GROUP BY YEAR(invoice_date)

