
SELECT TOP(3000)*
FROM clean_transactions;

-- Dataset Coverage
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT invoice) AS invoices,
    COUNT(DISTINCT stock_code) AS stock_code,
    COUNT(DISTINCT customer_id) AS customers,
    COUNT(DISTINCT country) AS countries,
    MIN(invoice_date) AS first_transaction,
    MAX(invoice_date) AS last_transaction
FROM clean_transactions;

-- ========================================================
-- Transaction Behaviour
-- ========================================================

-- cancelled vs non_cacelled transactions
SELECT 
    is_cancelled,
    COUNT(DISTINCT invoice) AS  invoice_count
FROM clean_transactions
GROUP BY is_cancelled

-- Negative vs positive quantities
SELECT 
    CASE 
        WHEN quantity < 0 THEN 'negative_quantity'
        WHEN quantity > 0 THEN 'positive_quantity'
        ELSE 'zero'
    END AS quantity_sign,
    COUNT(*) AS transactions
FROM clean_transactions
GROUP BY  
    CASE 
        WHEN quantity < 0 THEN 'negative_quantity'
        WHEN quantity > 0 THEN 'positive_quantity'
        ELSE 'zero' 
    END


-- cancelled invoices with positive quantities
SELECT *
FROM clean_transactions
WHERE invoice LIKE 'C%' AND quantity > 0


-- Non-cancellation invoices with negative quantities
SELECT COUNT(*) AS non_cancelled_positive_qty
FROM clean_transactions
WHERE invoice NOT LIKE 'C%' AND quantity < 0 


-- Zero price transactions
SELECT
    product_description,
    COUNT(*) AS zero_prized_transaction_lines,
    SUM(COUNT(*)) OVER() AS total_rows
FROM clean_transactions
WHERE price = 0
GROUP BY product_description 
ORDER BY zero_prized_transaction_lines DESC

-- zero priced transactions with positive quantity
SELECT 
    product_description,
    stock_code,
    COUNT(*) transactions,
    SUM(COUNT(*)) OVER() AS total_rows
FROM clean_transactions
WHERE price = 0 AND quantity > 0 AND INVOICE NOT LIKE 'C%'
GROUP BY product_description, stock_code
ORDER BY transactions DESC;

-- Extreme quantities and prices
 SELECT 
    is_cancelled,
    MAX(quantity) AS maximum_quantity,
    MIN(quantity) AS minimium_quantity,
    MAX(price) AS max_price,
    MIN(price) min_price
 FROM clean_transactions
GROUP BY is_cancelled


SELECT TOP(30)*
FROM clean_transactions
ORDER by quantity ASC

-- ========================================================================
-- Product Structure
-- =========================================================================

-- Stock Codes with multiple Descriptions
SELECT
    stock_code,
    COUNT(DISTINCT product_description) AS description_count
FROM clean_transactions
GROUP BY stock_code
HAVING COUNT(DISTINCT product_description) > 1
ORDER BY description_count DESC;


-- compare with previous
SELECT 
    stock_code,
    product_description,
    Count(*) as stock_code_count
FROM clean_transactions
GROUP BY stock_code,product_description
ORDER BY stock_code_count DESC;

-- ==================================================================
-- Time Structure
-- ==================================================================

SELECT 
    YEAR(invoice_date) AS invoice_year,
    MONTH(invoice_date) AS invoice_month,
    COUNT (DISTINCT CAST(invoice_date AS DATE)) AS days_in_month,
    MIN(CAST(invoice_date AS DATE)) AS earliest_transaction,
    MAX(CAST(invoice_date AS DATE)) AS latest_transaction
FROM clean_transactions
GROUP BY YEAR(invoice_date), MONTH(invoice_date)
ORDER BY invoice_year, invoice_month;


-- ==================================================================
-- Geographic Structure
-- ==================================================================

SELECT 
    country,
    COUNT(*) AS country_count
FROM clean_transactions
GROUP BY country
ORDER BY country_count DESC;

-- Create an analytics schema
IF SCHEMA_ID('analytics') IS NULL
BEGIN
    EXEC('CREATE SCHEMA analytics');
END;
GO

-- Sales lines view
CREATE OR ALTER VIEW analytics.vw_sales_lines AS
SELECT
    transaction_line_id,
    invoice,
    stock_code,
    product_description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country,
    quantity * price AS signed_line_value,
    CASE 
        WHEN stock_code = 'B'
        THEN 'bad debt adjustment'
        
        WHEN invoice LIKE 'C%'
        THEN 'cancellation'

        WHEN invoice NOT LIKE 'C%' AND
        PRICE > 0 AND
        quantity > 0 
        THEN 'completed sale'
        
        WHEN price = 0
        THEN 'zero priced product'
        ELSE 'other' 
    END AS transaction_type,

    CASE
        WHEN customer_id IS NULL THEN 0 ELSE 1
    END AS is_customer_known,

    CASE 
        WHEN invoice LIKE 'C%' THEN 1 ELSE 0
    END AS is_cancellation
FROM clean_transactions;
GO

SELECT *
FROM analytics.vw_sales_lines
