-- ## Delete only the clean table
/*
IF OBJECT_ID('dbo.clean_transactions', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.clean_transactions;
    PRINT 'dbo.clean_transactions deleted!'
END
ELSE 
BEGIN
    PRINT 'dbo.clean_transations does not exist!';
END;
GO
*/

-- 
SELECT COUNT(*) AS total_rows
FROM raw_transactions

-- Inspect the columns and data types
EXEC sp_help 'raw_transactions';

-- =======================================================================
-- PROFILING RAW DATA
-- ========================================================================
SELECT TOP(3000)*
FROM raw_transactions;

-- Missing value summary
SELECT COUNT(*) AS total_rows,
    SUM(
        CASE WHEN Invoice IS NULL THEN 1 ELSE 0 END
       ) AS missing_invoice,
    SUM(
        CASE WHEN Stockcode IS NULL THEN 1 ELSE 0 END
        ) AS missing_stockcode,
    SUM(
        CASE WHEN Description IS NULL THEN 1 ELSE 0 END
        ) AS missing_Description,
    SUM(
        CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END
        ) AS missing_Quantity,
    SUM(
        CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END
        ) AS missing_InvoiceDate,
    SUM(
        CASE WHEN Price IS NULL THEN 1 ELSE 0 END
        ) AS missing_Price,
    SUM(
        CASE WHEN Customer_ID IS NULL THEN 1 ELSE 0 END
        ) AS missing_customerID,
    SUM(
        CASE WHEN Country IS NULL THEN 1 ELSE 0 END
        ) AS missing_Country
FROM raw_transactions


-- Max text-columns lengths
SELECT
    MAX(LEN(CONVERT(NVARCHAR(4000), Invoice))) AS invoice_length,
    MAX(LEN(CONVERT(NVARCHAR(4000), StockCode))) AS StockCode_length,
    MAX(LEN(CONVERT(NVARCHAR(4000), Description))) AS Description_length,
    MAX(LEN(CONVERT(NVARCHAR(4000), Country))) AS Country_length,
    MAX(LEN(CONVERT(NVARCHAR(4000), Customer_ID))) AS CustomerID_length
FROM raw_transactions


-- Check for conversion failures
SELECT
    SUM(
        CASE 
            WHEN Quantity IS NOT NULL AND TRY_CONVERT(INT, QUANTITY) IS NULL
            THEN 1 ELSE 0
        END
       ) AS qty_conversion_failures,
    SUM( 
        CASE 
            WHEN Price IS NOT NULL AND TRY_CONVERT(DECIMAL(18,4), Price) IS NULL
            THEN 1 ELSE 0
        END
       ) AS price_conversion_failures,
    SUM(
        CASE 
            WHEN Customer_ID IS NOT NULL AND TRY_CONVERT(NVARCHAR(20), Customer_ID) IS NULL
            THEN 1 ELSE 0
        END
        ) AS customerID_conversion_failures
FROM raw_transactions

-- =======================================================
-- Create the clean table
-- =======================================================
IF OBJECT_ID('clean_transactions', 'U') IS NOT NULL
BEGIN
    DROP TABLE clean_transactions;
END;
GO

CREATE TABLE clean_transactions
(
    transaction_line_id  INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    invoice NVARCHAR(20) NULL,
    stock_code NVARCHAR(20) NULL,
    product_description NVARCHAR(255) NULL,
    quantity INT NULL,
    invoice_date DATETIME2(0) NULL,
    price DECIMAL(18,4) NULL,
    customer_id NVARCHAR(20) NULL,
    country VARCHAR(100) NULL
)
GO


-- Load the clean table
INSERT INTO clean_transactions 
    (
        invoice,
        stock_code,
        product_description,
        quantity,
        invoice_date,
        price,
        customer_id,
        country
    )
SELECT
    Invoice AS invoice,
    StockCode AS stock_code,
    Description AS product_description,
    CONVERT(INT, Quantity) AS quantity,
    InvoiceDate AS invoice_date,
   CONVERT(DECIMAL(18,4), Price)  AS price,
   CONVERT(NVARCHAR(20), Customer_ID) AS customer_id,
   Country AS country
FROM raw_transactions
GO

exec sp_help 'clean_transactions'

SELECT 'raw_table' AS table_name,
    COUNT(*) AS total_rows
FROM raw_transactions

UNION ALL

SELECT 'clean_table' AS table_name,
    COUNT(*) AS total_rows
FROM clean_transactions



-- ===============================================
-- Post Quality checks
-- ===============================================


-- Empty values
SELECT 
    COUNT(*) AS total_rows,
    SUM(
        CASE WHEN invoice = '' THEN 1 ELSE 0 END
    ) AS empty_invoice,
    SUM(
        CASE WHEN stock_code = '' THEN 1 ELSE 0 END
    ) AS empty_stockcode,
    SUM(
        CASE WHEN product_description  = '' THEN 1 ELSE 0 END
    ) AS empty_product_description,
    SUM(
        CASE WHEN invoice_date  = '' THEN 1 ELSE 0 END
    ) AS empty_invoice_date,
    SUM(
        CASE WHEN customer_id  = '' THEN 1 ELSE 0 END
    ) AS empty_customer_id,
    SUM(
        CASE WHEN country  = '' THEN 1 ELSE 0 END
    ) AS empty_country
FROM clean_transactions

-- check for whitespace
SELECT 
    SUM(
        CASE WHEN invoice <> TRIM(invoice) THEN 1 ELSE 0 END
    ) AS invoice_space,
    SUM(
        CASE WHEN stock_code <> TRIM(stock_code) THEN 1 ELSE 0 END
    ) AS stockcode_space,
    SUM(
        CASE WHEN product_description  <> TRIM(product_description) THEN 1 ELSE 0 END
    ) AS product_description_space,
    SUM(
        CASE WHEN customer_id <> TRIM(customer_id) THEN 1 ELSE 0 END
    ) AS customer_id_space,
    SUM(
        CASE WHEN country  <> TRIM(country) THEN 1 ELSE 0 END
    ) AS country_space
FROM clean_transactions


-- Missing value summary
SELECT 
    COUNT(*) AS total_rows,
    SUM(
        CASE WHEN invoice IS NULL THEN 1 ELSE 0 END
    ) AS missing_invoice,
    SUM(
        CASE WHEN stock_code IS NULL THEN 1 ELSE 0 END
    ) AS missing_stockcode,
    SUM(
        CASE WHEN product_description IS NULL THEN 1 ELSE 0 END
    ) AS missing_product_description,
    SUM(
        CASE WHEN quantity IS NULL THEN 1 ELSE 0 END
    ) AS missing_quantity,
    SUM(
        CASE WHEN invoice_date IS NULL THEN 1 ELSE 0 END
    ) AS missing_invoice_date,
    SUM(
        CASE WHEN price IS NULL THEN 1 ELSE 0 END
    ) AS missing_price,
    SUM(
        CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END
    ) AS missing_customer_id,
    SUM(
        CASE WHEN country IS NULL THEN 1 ELSE 0 END
    ) AS missing_country
FROM clean_transactions


-- Product description missing values: Stock code with distinct description

SELECT 
    stock_code,
    MAX(product_description) AS valid_description,
    COUNT(DISTINCT product_description) AS distinct_descriptions,
    COUNT(product_description) AS description_count,
    SUM(CASE 
            WHEN product_description IS NULL THEN 1 ELSE 0
         END
       ) AS null_count
FROM clean_transactions
GROUP BY stock_code
HAVING  COUNT(DISTINCT product_description) = 1
AND 
    SUM( CASE 
                WHEN product_description IS NULL THEN 1 ELSE 0
            END
        ) > 0
ORDER BY null_count DESC


-- Update the clean_transactions table
UPDATE c
SET c.product_description = j.valid_description

FROM clean_transactions AS c
JOIN(
    SELECT 
        stock_code,
        MAX(product_description) AS valid_description
    FROM clean_transactions
    GROUP BY stock_code
    HAVING  COUNT(DISTINCT product_description) = 1
    AND 
        SUM( CASE 
                    WHEN product_description IS NULL THEN 1 ELSE 0
                END
            ) > 0
) AS j
    ON c.stock_code = j.stock_code
WHERE c.product_description IS NULL


-- 
SELECT * 
FROM clean_transactions
WHERE customer_id IS NULL


/*
-- Update EIRE to Ireland
SELECT DISTINCT country
FROM clean_transactions

UPDATE clean_transactions
SET country = 'Ireland'
WHERE country = 'EIRE';

UPDATE clean_transactions
SET country = 'Repuplic of South Africa'
WHERE country = 'RSA';

UPDATE clean_transactions
SET country = 'United States'
WHERE country = 'USA';
*/


-- ====================================================================
-- Check for Unusual Transactions
-- ====================================================================

-- Quantity and Price ranges
SELECT 
    MIN(quantity) AS min_quantity,
    MAX(quantity) AS max_quantity,
    MIN(price) AS min_price,
    MAX(price) AS max_price
FROM clean_transactions

-- Negative prices
SELECT *
FROM clean_transactions
WHERE price < 0
ORDER BY price

-- Zero prices
SELECT 
    stock_code,
    product_description,
    COUNT(*) AS transactions
FROM clean_transactions
WHERE price = 0
GROUP BY stock_code, product_description
ORDER BY transactions DESC

-- cancellations and quantity
SELECT 
    CASE WHEN invoice LIKE 'C%' THEN 1 ELSE 0 
    END AS invoice_cancellation,
    CASE WHEN quantity < 0 THEN 1 ELSE 0
    END AS negative_quantity,
    COUNT(*) AS transactions
FROM clean_transactions
GROUP BY  
    CASE WHEN invoice LIKE 'C%' THEN 1 ELSE 0 
    END,
    CASE WHEN quantity < 0 THEN 1 ELSE 0
    END
ORDER BY transactions DESC

-- Create a column for cancelled invoices
/*
ALTER TABLE clean_transactions
ADD is_cancelled BIT NULL

UPDATE clean_transactions
SET is_cancelled = 
    CASE WHEN invoice LIKE 'C%' THEN 1 ELSE 0 END;
*/



-- ====================================================
-- Duplicates
-- ====================================================

/*
Since the source dataset does not provide a unique invoice line identifier, we cannot confidently conclude
similar rows as duplicates. Rather, we investigate suspected duplicates further.
*/

WITH duplicate_rows AS( 
    SELECT 
        invoice,stock_code,product_description,quantity,invoice_date,price,customer_id,country,
        COUNT(*) AS occurrence_count
    FROM clean_transactions
    GROUP BY
        invoice,stock_code,product_description,quantity,invoice_date,price,customer_id,country
    HAVING COUNT(*) > 1
)
SELECT 
    COUNT(*) AS duplicate_groups,
    SUM(occurrence_count - 1) AS possible_additional_rows
FROM duplicate_rows


-- Preview the duplicate groups
SELECT TOP(30)
    invoice,stock_code,product_description,quantity,invoice_date,price,customer_id,country,
    COUNT(*) AS occurrence_count
FROM clean_transactions
GROUP BY
    invoice,stock_code,product_description,quantity,invoice_date,price,customer_id,country
    HAVING COUNT(*) > 1

-- Quality check: Distinct rows in each column
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT invoice) AS distinct_invoices,
    COUNT(DISTINCT stock_code) AS distinct_stock_code,
    COUNT(DISTINCT product_description) AS distinct_product_description,
    COUNT(DISTINCT quantity) AS distinct_quantity,
    COUNT(DISTINCT invoice_date) AS distinct_invoice_date,
    MIN(invoice_date) AS earliest_date,
    MAX(invoice_date) AS latest_date
FROM clean_transactions

------------------------------------------------------------------------
SELECT
    stock_code,
    COUNT(DISTINCT product_description) AS description_count
FROM clean_transactions
WHERE product_description IS NOT NULL
GROUP BY stock_code
HAVING COUNT(DISTINCT product_description) = 1;

SELECT
    stock_code,
    COUNT(DISTINCT product_description) AS distinct_descriptions,
    SUM(CASE 
        WHEN product_description IS NULL THEN 1 
        ELSE 0 
    END) AS null_count
FROM clean_transactions
GROUP BY stock_code
HAVING COUNT(DISTINCT product_description) = 1
   AND SUM(CASE 
        WHEN product_description IS NULL THEN 1 
        ELSE 0 
   END) > 0
ORDER BY null_count DESC;



SELECT
    stock_code,
    MAX(product_description) AS valid_description,
    COUNT(DISTINCT product_description) AS distinct_descriptions,
    COUNT(product_description) AS description_count,
    SUM(CASE 
        WHEN product_description IS NULL THEN 1 
        ELSE 0 
    END) AS null_count,
    SUM(SUM(CASE 
        WHEN product_description IS NULL THEN 1 
        ELSE 0 
    END)) OVER() AS null_sum
FROM clean_transactions
GROUP BY stock_code
HAVING COUNT(DISTINCT product_description) = 1
   AND SUM(CASE 
        WHEN product_description IS NULL THEN 1 
        ELSE 0 
   END) > 0
ORDER BY null_count DESC;






