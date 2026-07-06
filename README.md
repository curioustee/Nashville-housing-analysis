# Nashville-housing-analysis
A complete end-to-end SQL project covering data exploration, cleaning, manipulation, and analysis on the Nashville Housing dataset. The dataset contains residential property sales records from Nashville, Tennessee, and is widely used for practicing real-world data cleaning scenarios.

Tools Used

- MySQL
- Dataset: Nashville Housing Data (56,000+ property sales records)
- Skills demonstrated: Data exploration, data cleaning, feature engineering, aggregation, window functions, CTEs


Project Structure

nashville-housing-sql
 1_exploration.sql       -- Initial profiling: nulls, ranges, distributions
 2_cleaning.sql          -- Standardization, address splitting, deduplication
 3_manipulation.sql      -- Derived columns, bins, flags
 4_analysis.sql          -- Business questions answered with SQL
 README

## Dataset Overview

Source - Nashville, Tennessee property sales 
Rows - ~56,000 records
Year range -2013 – 2019
Key columns - ParcelID, PropertyAddress, SaleDate, SalePrice, LandUse, YearBuilt, Bedrooms, FullBath, HalfBath, TotalValue |


Phase 1 — Data Exploration

Before writing a single UPDATE or ALTER, the dataset was first explored to understand its quality:

- Checked all column data types with `DESCRIBE`
- Counted NULL values across every column — `PropertyAddress` and `OwnerAddress` had the most missing values
- Inspected categorical columns: `LandUse`, `SoldAsVacant`, and `TaxDistrict` for inconsistencies
- Confirmed `SaleDate` was stored as text rather than a DATE type, requiring conversion
- Identified duplicate rows using `GROUP BY` on key business fields before any cleaning began


Phase 2 — Data Cleaning

1. Standardized SaleDate
Converted the `SaleDate` column from a text format (`"April 9, 2013"`) to a proper MySQL `DATE` type using `STR_TO_DATE()` and `ALTER TABLE`.


2. Fixed SoldAsVacant inconsistency
The column contained four distinct values: `Yes`, `No`, `Y`, `N`. Standardised to `Yes` and `No` using a `CASE` statement.


3. Removed duplicate rows
Identified and removed duplicate rows using `ROW_NUMBER()` partitioned by `ParcelID`, `PropertyAddress`, `SaleDate`, `SalePrice`, and `LegalReference`. A staged cleaning table was created first to preserve the raw data.

4. Dropped redundant columns
After splitting, the original `PropertyAddress`, `OwnerAddress`, and `TaxDistrict` columns were dropped as their information was now stored in cleaner, purpose-built columns.


Phase 3 — Data Manipulation
new columns were created to support analysis:

Split address columns
- `PropertyAddress` (`"1808 FOX CHASE DR, GOODLETTSVILLE"`) was split into `PropertySplitStreet` and `PropertySplitCity` using `SUBSTRING` and `LOCATE`.
- `OwnerAddress` (`"1808 FOX CHASE DR, GOODLETTSVILLE, TN"`) was split into `OwnerSplitStreet`, `OwnerSplitCity`, and `OwnerSplitState` using `SUBSTRING_INDEX`.

- `ValueGap` : Difference between the property SalePrice and TotalValue 
- `ValueGapFlag` : To label the value of the properties if they were Over assessed, Under assessed or At assessed value 
- `PricePerAcre` : SalePrice divided by Acreage 
- `PropertyAge` : Age of property at time of sale
- `PriceTier` : Price range: Below 50k / 50k–100k / 100k–250k / 250k–400k / 400k+
- `AgeGroup` : PropertyAge label: New / Modern / Established / Older / Historic 
- `TotalBaths` : FullBath + (HalfBath × 0.5) 
- `PropertySize` : Size label based on bedroom count
- `SaleYear` 
- `SaleMonth` 

Negative property ages (-1 to -4): A small number of properties had a YearBuilt value 1–4 years after their SaleDate. Rather than treating these as errors, investigation showed they were consistent with new construction sales — properties sold at contract stage before the build completed. These were floored to PropertyAge = 0 and assigned to the New (under 10 yrs) age group rather than being nulled out, preserving them in age-based analysis.

Phase 4 — Analysis & Key Findings

Sales volume and pricing over time
Sales activity peaked in the mid-2010s. Average sale prices showed a consistent upward trend across the dataset's date range, with year-over-year growth visible in most years, reflecting the broader Nashville housing boom during this period.

 Seasonal patterns
Sales volume was highest in the spring and early summer months (April through July), consistent with typical real estate market behaviour. The slowest months were January and February. This seasonal pattern held across multiple years in the dataset.

Assessed value accuracy
The majority of properties in the dataset sold above their assessed (TotalValue) figure, meaning buyers paid more than the valuation in most cases. A smaller proportion sold below assessed value, which may reflect distressed sales, motivated sellers, or assessment lag in rapidly appreciating areas. Very few properties sold at exactly their assessed value.

Impact of property age on price
Newer properties (under 10 years old at time of sale) commanded the highest average sale prices, as expected. Interestingly, historic properties (100+ years old) often outperformed middle-aged properties in average price, likely reflecting premium locations, unique architecture, and renovated character homes rather than age alone driving value.

Price tier distribution
The majority of sales fell in the mid-range price tiers. The sub-50k tier, while present, represented a small share of total transactions and likely includes land-only sales, distressed properties, or non-arm's-length transfers rather than standard residential sales.

Bedroom and bathroom profile by price tier
Higher price tiers were associated with more bedrooms, more bathrooms, and larger acreage on average.

 SQL Concepts Demonstrated

- `DESCRIBE`, `COUNT`, `SUM(CASE WHEN ...)` 
- `SUBSTRING`, `LOCATE`, `SUBSTRING_INDEX` 
- `CASE WHEN` 
- `ROW_NUMBER() OVER (PARTITION BY ...)` 
- `ALTER TABLE`, `UPDATE` 
- `COALESCE`
- `LAG() OVER (ORDER BY ...)` 
- `RANK() OVER (PARTITION BY ...)`
- `SUM() OVER (...)` 
- CTEs (`WITH ... AS`) 
- `GROUP BY`, `HAVING`, `ORDER BY` 

 How to Run

1. Import the raw CSV into MySQL as `nashville_housing`
2. Run scripts in order: `1_exploration.sql` → `2_cleaning.sql` → `3_manipulation.sql` → `4_analysis.sql`
3. Each script is self-contained and includes comments explaining every step


Data Source

Nashville Housing Data — publicly available dataset widely used for SQL data cleaning practice. Original data covers Davidson County, Tennessee property assessor and sales records.
