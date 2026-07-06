USE port;
DROP TABLE nash;
DELETE FROM nash;
CREATE TABLE nash(
unique_id INT,
parcel_id VARCHAR(100),
land_use VARCHAR(100),
property_address VARCHAR(100),
sale_date VARCHAR(80),
sale_price VARCHAR(80),
legal_reference VARCHAR(100),
sold_as_vacant VARCHAR(10),
owner_name VARCHAR(100),
owner_address VARCHAR(100),
acreage VARCHAR(80),
tax_district VARCHAR(80),
land_value VARCHAR(80),
building_value VARCHAR(80),
total_value VARCHAR(80),
year_built VARCHAR(80),
bedrooms VARCHAR(80),
full_bath VARCHAR(80),
half_bath VARCHAR(80)
);

-- EXPLORATION
SELECT * 
FROM nash
WHERE owner_name = TRIM(" ")
LIMIT 500;

SELECT *
FROM nash
LIMIT 500;

DESC nash;

SELECT COUNT(DISTINCT unique_id)
FROM nash;

SELECT COUNT(*) AS missing_address
FROM nash
WHERE property_address = TRIM(" ") ;  

SELECT MIN(sale_price),
       MAX(sale_price),
       AVG(sale_price)
FROM nash;

SELECT MIN(total_value),
       MAX(total_value),
       AVG(total_value)
FROM nash;

SELECT MIN(acreage),
       MAX(acreage),
       AVG(acreage)
FROM nash;

SELECT MIN(year_built),
       MAX(year_built)
FROM nash;

SELECT land_use,
       COUNT(*) AS count
FROM nash
GROUP BY land_use
ORDER BY count DESC;

SELECT sold_as_vacant,
       COUNT(*) AS count
FROM nash
GROUP BY sold_as_vacant
ORDER BY count DESC;  


SELECT
    YEAR(sale_date) AS sale_year,
    COUNT(*) AS num_sales
FROM nash
GROUP BY sale_year
ORDER BY sale_year;

SELECT unique_id,
       COUNT(*) AS count
FROM nash
GROUP BY unique_id
HAVING count > 1
ORDER BY count DESC; 

SELECT
    parcel_id,
    property_address,
    sale_date,
    sale_price,
    legal_reference,
    COUNT(*) AS count
FROM nash
GROUP BY parcel_id, property_address, sale_date, sale_price, legal_reference
HAVING count > 1
ORDER BY count DESC; 

SELECT parcel_id,
       COUNT(DISTINCT property_address) AS duplicate_addresses
FROM nash
GROUP BY parcel_id
HAVING duplicate_addresses > 1; 


-- DATA CLEANING

UPDATE nash
SET sale_date = STR_TO_DATE(sale_date, '%M %d, %Y');

SELECT sale_price
FROM nash
LIMIT 187,1;

UPDATE nash
SET sold_as_vacant = REPLACE(sold_as_vacant,'Yeses','Yes'),
    sold_as_vacant = REPLACE(sold_as_vacant,'Noo','No');

UPDATE nash
SET sale_price = REPLACE(sale_price,' ', TRIM('')),
	 sale_price = REPLACE(sale_price,'$', TRIM(''));

ALTER TABLE nash
MODIFY sale_price INT;

SELECT DISTINCT acreage
FROM nash
WHERE acreage IS NOT NULL
  AND TRIM(acreage) <> ''
  AND acreage NOT REGEXP '^-?[0-9]+(\\.[0-9]+)?$';

UPDATE nash
SET acreage = NULL
WHERE TRIM(acreage) = '';

UPDATE nash
SET owner_name = NULL
WHERE TRIM(owner_name) = '';

ALTER TABLE nash
MODIFY year_built INT,
MODIFY half_bath INT,
MODIFY building_value INT,
MODIFY land_value INT,
MODIFY acreage FLOAT;

SELECT * 
FROM nash
WHERE property_address = " ";

WITH grouped AS
(SELECT *,
        ROW_NUMBER() OVER(PARTITION BY parcel_id, property_address, sale_date, sale_price, legal_reference ORDER BY unique_id) AS row_num
FROM nash)
SELECT *
FROM grouped
WHERE row_num> 1; -- 103 duplicates

DELETE 
FROM nash
WHERE unique_id IN
(SELECT unique_id
FROM
(SELECT unique_id,
       ROW_NUMBER() OVER(PARTITION BY parcel_id, property_address, sale_date, sale_price, legal_reference ORDER BY unique_id) AS row_num
FROM nash) AS base
WHERE base.row_num > 1); -- duplicates deleted

UPDATE nash
SET property_address = NULL
WHERE property_address = '';


-- DATA MANIPULATION

SELECT property_address,
       SUBSTRING(property_address, 1, LOCATE(',', property_address) -1) AS property_street,
       SUBSTRING(property_address, LOCATE(',',property_address) +1) AS property_city
FROM nash;

ALTER TABLE nash
ADD COLUMN property_street VARCHAR(100) AFTER property_address,
ADD COLUMN property_city VARCHAR(100) AFTER property_street
;

UPDATE nash
SET property_street = SUBSTRING(property_address,1,LOCATE(',',property_address) -1),
    property_city   = SUBSTRING(property_address,LOCATE(',', property_address) +1)
;

-- total number or properties  
SELECT COUNT(unique_id) AS total_properties
FROM nash;                                          -- this query brings us to a total of 56,477 properties


ALTER TABLE nash
ADD COLUMN value_gap INT AFTER total_value,
ADD COLUMN value_gap_flag VARCHAR(20) AFTER value_gap
;
   
SELECT * 
FROM nash
LIMIT 3;

UPDATE nash
SET value_gap = sale_price - total_value,
    value_gap_flag =
         CASE 
             WHEN sale_price > total_value THEN 'over_assessed'
             WHEN sale_price < total_value THEN 'under_assessed'
             ELSE 'properly assessed'
		 END;

SELECT *
FROM nash
LIMIT 5;

SELECT * from nash
WHERE value_gap_flag = 'properly assessed'
AND value_gap IS NOT NULL;  -- there are only 55 properties that have been properly assessed based on their total value 

SELECT unique_id,
       property_address,
       sale_date,
       owner_name,
       acreage,
       total_value,
       sale_price,
       value_gap,
       value_gap_flag
FROM nash
WHERE value_gap_flag = 'over_assessed'       -- 19502 properties were over_assessed
;

SELECT unique_id,
       property_address,
       sale_date,
       owner_name,
       acreage,
       total_value,
       sale_price,
       value_gap,
       value_gap_flag
FROM nash
WHERE value_gap_flag = 'under_assessed'       -- 6413 properties were under_assessed
;
       
ALTER TABLE nash
ADD COLUMN price_per_acre INT AFTER acreage;

UPDATE nash
SET price_per_acre = 
                    CASE
                        WHEN acreage = 0 OR acreage IS NULL THEN NULL
                        ELSE ROUND(sale_price/acreage,1)
					END
;
SELECT * FROM nash
WHERE price_per_acre IS NOT NULL;

ALTER TABLE nash
ADD COLUMN property_age INT AFTER year_built;

ALTER TABLE nash
ADD COLUMN sale_year INT AFTER sale_date;

UPDATE nash
SET sale_year =
               CASE
                   WHEN sale_date IS NULL THEN NULL
                   ELSE YEAR(sale_date)
			   END;

UPDATE nash
SET property_age =
                 CASE
                     WHEN year_built IS NULL THEN NULL
                     ELSE sale_year - year_built
				 END
;
SELECT property_age,
       COUNT(*)
FROM nash
GROUP BY property_age
HAVING property_age < 0    -- a couple of negative years here
ORDER BY property_age;

UPDATE nash
SET property_age = 0,
    property_age_grp = 'new_property(under 10 yrs)'
WHERE property_age < 0
;

ALTER TABLE nash
ADD COLUMN sale_tier INT AFTER sale_price;

ALTER TABLE nash
MODIFY sale_tier VARCHAR(30);

UPDATE nash
SET sale_tier =
               CASE
                   WHEN sale_price < 50000 THEN '1- below 50k'
                   WHEN sale_price BETWEEN 50000 AND 99000 THEN '2- 50k - 100k'
				   WHEN sale_price BETWEEN 100000 AND 249000 THEN '3- 100k - 250k'
                   WHEN sale_price BETWEEN 250000 AND 399000 THEN '4- 250k - 400k'
				   WHEN sale_price > 400000 THEN '5- over 400k'
                   ELSE NULL
				END;

ALTER TABLE nash
ADD COLUMN bedroom_label VARCHAR(50) AFTER bedrooms;

UPDATE nash
SET bedroom_label = 
                   CASE
                       WHEN bedrooms IS NULL THEN NULL
                       WHEN bedrooms = 0 THEN 'studio'
                       WHEN bedrooms = 1 THEN 'compact 1-bed'
                       WHEN bedrooms = 2 OR bedrooms = 3 THEN 'standard 2-3 beds'
                       WHEN bedrooms = 4 OR bedrooms = 5 THEN 'spacious 4-5 beds'
                       ELSE 'expansive 6+ beds'
					END;

ALTER TABLE nash
ADD COLUMN sale_month DATE AFTER sale_year;

UPDATE nash
SET sale_month = MONTHNAME(sale_date);

ALTER TABLE nash
ADD COLUMN property_age_grp VARCHAR(50) AFTER property_age;

UPDATE nash
SET property_age_grp =
                      CASE
                          WHEN property_age < 10 THEN 'new_property(under 10 yrs)'
                          WHEN property_age BETWEEN 10 AND 29 THEN 'modern_property(10-29 yrs)'
                          WHEN property_age BETWEEN 30 AND 59 THEN 'established_property(30-59 yrs)'
                          WHEN property_age BETWEEN 60 AND 99 THEN 'old_property(60-99 yrs)'
                          WHEN property_age > 100 THEN  'historic(100+)'
                          ELSE NULL
					   END;

ALTER TABLE nash
ADD COLUMN total_baths FLOAT AFTER half_bath;

UPDATE nash
SET total_baths = COALESCE(full_bath,0) + COALESCE(half_bath,0) * 0.5
;
                 
-- DATA ANALYSIS
 
 ## revenue by year
SELECT sale_year,
	   SUM(sale_price) AS total_revenue,
       COUNT(*) AS total_sales
FROM nash
GROUP BY sale_year
ORDER BY total_revenue DESC;

## average price growth over the years
SELECT sale_year,
       ROUND(AVG(sale_price), 1) AS avg_price
FROM nash 
GROUP BY sale_year;

WITH avg_ppy AS
              (SELECT sale_year,
                      ROUND(AVG(sale_price), 1) AS avg_price
               FROM nash 
               GROUP BY sale_year)
SELECT sale_year,
       avg_price,
       LAG(avg_price) OVER(ORDER BY sale_year) AS prev_year_price,
       ROUND((avg_price - LAG(avg_price) OVER(ORDER BY sale_year))/ LAG(avg_price) OVER(ORDER BY sale_year) * 100, 2) AS percentage_incr
FROM avg_ppy;

## SALES VOLUME PER MONTH OVER THE YEARS
SELECT sale_month,
       COUNT(*) AS total_sales,
       ROUND(AVG(sale_price), 2) AS avg_price
FROM nash
GROUP BY sale_month
ORDER BY avg_price DESC
;

## BEST SELLING PROPERTIES PER TIER IN EVERY YEAR

with gen_tier AS (SELECT sale_year,
                         sale_tier,
                         COUNT(*) AS total_sales,
                         ROUND(AVG(sale_price),1) AS avg_revenue
                  FROM nash
                  GROUP BY sale_year, sale_tier)

SELECT *,
       RANK() OVER(PARTITION BY sale_year ORDER BY avg_revenue DESC) AS rnk
FROM gen_tier;

## THE CITY GENERATING THE HIGHEST REVENUE AND MOST TRANSACTIONS

SELECT property_city,
       SUM(sale_price) AS revenue
FROM nash
WHERE property_city IS NOT NULL
GROUP BY property_city
ORDER BY revenue DESC;

SELECT property_city,
       COUNT(*) AS transactions
FROM nash
WHERE property_city IS NOT NULL
GROUP BY property_city
ORDER BY transactions DESC;


## BEST SELLING PROPERTIES IN EACH CITY BASED ON BEDROOM

SELECT property_city,
       bedroom_label,
       COUNT(*) AS total_purchases,
       SUM(sale_price) AS price
FROM nash
WHERE bedroom_label IS NOT NULL AND property_city IS NOT NULL
GROUP BY property_city,bedroom_label
ORDER BY property_city;

## AVERAGE COST OF PROPERTIES BASED ON THE BEDROOMS AND BATHROOMS AVAILABLE

SELECT bedroom_label,
       ROUND(AVG(sale_price),1) AS average_price,
       ROUND(AVG(total_baths),1) AS avg_total_baths
FROM nash
WHERE bedroom_label IS NOT NULL
GROUP BY bedroom_label
ORDER BY average_price DESC;  -- studio second due to the fact that most of them are not residential apartments

## BEST VALUE CITY per acre

SELECT property_city,
       ROUND(AVG(price_per_acre), 1) AS avg_ppa
FROM nash
WHERE property_city IS NOT NULL
GROUP BY property_city
ORDER BY avg_ppa DESC; 

## PRICE PER PROPERTY AGE

SELECT property_age_grp,
	   ROUND(AVG(sale_price),1) AS avg_price,
       COUNT(*) AS sales,
       ROUND(AVG(price_per_acre),1) AS avg_ppa,
       ROUND(AVG(total_baths),1) AS avg_total_baths
FROM nash
WHERE property_age_grp IS NOT NULL
GROUP BY property_age_grp
ORDER BY avg_price DESC;

## SALES BY LAND USE
SELECT land_use,
       SUM(sale_price) AS total_price,
       COUNT(*) AS total_transactions,
       ROUND(AVG(price_per_acre),1) AS avg_ppa
FROM nash
GROUP BY land_use
ORDER BY total_transactions DESC;

## AVERAGE PRICE TIER DISTRIBUTION
SELECT sale_tier,
       ROUND(AVG(sale_price),1) AS avg_price,
       COUNT(*) AS total_sales,
       ROUND(COUNT(*) * 100/ SUM(COUNT(*)) OVER(),1) AS percentage_total
FROM nash
WHERE sale_tier IS NOT NULL
GROUP BY sale_tier
ORDER BY percentage_total DESC;

## RUNNING TOTAL OF SALES REVENUE BY YEAR

WITH yearly_rev AS
                 (SELECT sale_year,
                         SUM(sale_price) AS total_revenue,
                         COUNT(*) AS total_sales
                  FROM nash
				  GROUP BY sale_year
				  ORDER BY sale_year)
SELECT *,
       SUM(total_revenue) OVER(ORDER BY sale_year) AS cummulative_revenue
FROM yearly_rev;

## VALUE ACCURACY

SELECT value_gap_flag,
       ROUND(AVG(value_gap),1) AS avg_value_gap,
       COUNT(*) AS total_properties,
       ROUND(AVG(sale_price),1) AS avg_sale_price,
       ROUND(AVG(total_value),1) AS avg_assessed_value
FROM nash
WHERE value_gap_flag IS NOT NULL
GROUP BY value_gap_flag;
       