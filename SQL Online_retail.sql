DROP DATABASE super_onine_retail;
CREATE DATABASE super_onine_retail;
USE super_onine_retail;

CREATE TABLE retail (
    Invoice_no VARCHAR(20),
    Stock_code VARCHAR(20),
    Description VARCHAR(500),
    Quantity INT,
    Invoice_date_raw VARCHAR(40),
    Unit_price DECIMAL(10,2),
    Customer_ID VARCHAR(20),
    Country VARCHAR(100)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Online Retail.xlsx - Online Retail.csv'
INTO TABLE retail
CHARACTER SET latin1
FIELDS
    TERMINATED BY ','
    ENCLOSED BY '"'
    ESCAPED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    Invoice_no,
    Stock_code,
    Description,
    Quantity,
    @Invoice_date_raw,
    @Unit_price,
    Customer_ID,
    Country
)
SET
    Invoice_date_raw = NULLIF(@Invoice_date_raw, ''),
    Unit_price       = NULLIF(@Unit_price, '');

ALTER TABLE retail MODIFY Unit_price VARCHAR(20);

SET SQL_SAFE_UPDATES = 0;
UPDATE retail
SET Unit_price = NULL
WHERE Unit_price NOT REGEXP '^[0-9]+(\\.[0-9]+)?$';
SET SQL_SAFE_UPDATES = 1;

ALTER TABLE retail MODIFY Unit_price DECIMAL(10,2);

ALTER TABLE retail ADD Invoice_date DATETIME;

SET SQL_SAFE_UPDATES = 0;
SET SQL_SAFE_UPDATES = 0;

UPDATE retail
SET Invoice_date =
CASE
    WHEN Invoice_date_raw REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{1,2}:[0-9]{2}$'
        THEN STR_TO_DATE(Invoice_date_raw, '%m/%d/%Y %H:%i')

    WHEN Invoice_date_raw REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2} [0-9]{1,2}:[0-9]{2}$'
        THEN STR_TO_DATE(Invoice_date_raw, '%m/%d/%y %H:%i')

    WHEN Invoice_date_raw REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(Invoice_date_raw, '%Y-%m-%d')

    ELSE NULL
END
WHERE Invoice_date_raw IS NOT NULL;

SET SQL_SAFE_UPDATES = 1;
ALTER TABLE retail ADD id INT AUTO_INCREMENT PRIMARY KEY;
SELECT * FROM retail;

/* Display all top 20 stock codes ordered by invoice date, starting from the latest date */
SELECT stock_code, invoice_date
FROM retail
ORDER BY invoice_date DESC
LIMIT 20;

/* Show total revenue per customer sorted by highest revenue first */
SELECT customer_id, SUM(quantity*unit_price) AS total_revenue 
FROM retail 
WHERE customer_id IS NOT NULL
AND customer_id <> '0'
AND TRIM(customer_id) <> '' 
GROUP BY customer_id 
ORDER BY SUM(quantity*unit_price) DESC;

/* Retrieve distinct customer_id and country for invoices between 2010-01-01 and 2011-12-31 */
SELECT DISTINCT customer_id, country
FROM retail 
WHERE customer_id IS NOT NULL
AND customer_id <> '0' 
AND TRIM(customer_id) <> ''
AND invoice_date >= '2010-01-01'
AND invoice_date <'2011-12-31';

/* Show country whose total revenue is more than 5000 */
SELECT country, SUM(quantity*unit_price) AS total_revenue 
FROM retail
WHERE customer_id IS NOT NULL AND customer_id <> '0'
GROUP BY country 
HAVING SUM(quantity*unit_price) > 5000;

/* Show each customer's id, their total revenue and assign a customer category based on total revenue:*/
SELECT customer_id, SUM(quantity*unit_price) AS total_revenue,
CASE
WHEN SUM(quantity*unit_price) >= 10000 THEN 'HIGH VALUE'
WHEN SUM(quantity*unit_price) BETWEEN 5000 AND 9999 THEN 'MEDIUM VALUE'
ELSE 'LOW VALUE'
END AS customer_category 
FROM retail 
WHERE customer_id IS NOT NULL AND customer_id <> '0' AND customer_id <> '' 
GROUP BY customer_id;

/* List distinct stockcodes and their total quantities sold ranked from highest to lowest */
SELECT stock_code, SUM(quantity) AS total_quantity 
FROM retail 
GROUP BY stock_code 
ORDER BY  SUM(quantity) DESC;

/* For each country fetch the top 5 highest priced products based on unitprice */
SELECT country, stock_code,
dense_rank() OVER (partition by country ORDER BY unit_price DESC) AS highest_priced 
FROM retail;

/* Divide customerid into four revenue buckets per country based on total revenue */
SELECT customer_id, country, SUM(quantity*unit_price) AS total_revenue, 
NTILE(4) OVER (PARTITION BY country ORDER BY SUM(quantity*unit_price) DESC)AS revenue_bucket 
FROM retail 
WHERE customer_id IS NOT NULL AND customer_id <> '0' AND customer_id <> ''
GROUP BY customer_id, country;

/* Show StockCodes whose total revenue is above the overall average StockCode revenue.*/
SELECT stock_code, SUM(quantity*unit_price) AS total_revenue 
FROM retail 
GROUP BY stock_code 
HAVING SUM(quantity*unit_price) > ( SELECT AVG(total_revenue) FROM 
(SELECT stock_code, SUM(quantity*unit_price) AS total_revenue FROM retail GROUP BY stock_code)t);

/* Show the top-selling StockCodes per country per month based on total quantity sold.*/
SELECT * FROM (SELECT stock_code, country, date_format(invoice_date,'%y-%m') AS format_date, SUM(quantity) AS total_quantity,
rank() over (partition by country, date_format(invoice_date, '%y-%m') ORDER BY SUM(quantity) desc) AS highest_rank
FROM retail 
GROUP BY stock_code, country, date_format(invoice_date, '%y-%m')) t WHERE highest_rank = 1
ORDER BY country;

/* What was the total revenue per quarter in the year 2010 */
SELECT QUARTER(invoice_date) AS quarter, SUM(quantity*unit_price) AS total_revenue 
FROM retail
WHERE YEAR(invoice_date) = 2010
GROUP BY QUARTER(invoice_date)
ORDER BY QUARTER(invoice_date);

/* Which customer purchased the product with the highest unit price, and in which country */
SELECT customer_id, unit_price, country
FROM retail
ORDER BY country ASC, unit_price DESC
LIMIT 1;	

/* Create a CTE that filters all StockCodes where the country name starts with the letter ‘B’ */
WITH stock_country AS (SELECT stock_code, country FROM retail WHERE country like 'B%')
SELECT * FROM stock_country;

/* For the year 2011, show each stock_code and invoice date, their total revenue, and assign a country category based on revenue:
Superior → total revenue ≥ 15,000
Medium → total revenue between 6,000 and 14,999
Poor → total revenue < 6,000 */
SELECT stock_code, country, SUM(quantity*unit_price) AS total_revenue, 
CASE WHEN SUM(quantity*unit_price) >= 15000 THEN 'SUPERIOR' 
WHEN SUM(quantity*unit_price) BETWEEN 6000 AND 14999 THEN 'MEDIUM'
ELSE 'POOR'
END AS country_category 
FROM retail 
WHERE year(invoice_date) = 2011
GROUP BY stock_code, country
ORDER BY SUM(quantity*unit_price) DESC;

/* Create a CTE to list countries having more than 3 customer IDs */
WITH customer_country AS (SELECT country, count(distinct customer_id) AS num_customers FROM retail
GROUP BY country HAVING count(distinct customer_id) > 3) SELECT * FROM customer_country;


