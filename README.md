World Layoffs — SQL Data Cleaning & EDA

SQL project: taking a messy real-world dataset of global tech layoffs (March 2020 – March 2023) from raw CSV to clean, analysis-ready data, then exploring it to surface trends. Built in MySQL with MySQL Workbench.

Picture 

Dataset: ~2,361 records of layoff events — company, location, industry, headcount laid off, % of workforce, funding stage, country, funds raised.




Part 1 — Data Cleaning

All work done on staging copies — the raw table is never modified.

1. Removed duplicates. No unique ID existed, so I generated one with ROW_NUMBER() OVER (PARTITION BY ...) across all nine columns — partitioning on a partial column list falsely flags legitimate rows as duplicates. Since MySQL can't delete from a CTE, flagged rows were materialised into a second staging table and deleted there. 5 true duplicates removed (2,361 → 2,356).

2. Standardized values. Trimmed whitespace from company names; merged industry variants (Crypto, Crypto Currency, CryptoCurrency → Crypto); stripped the trailing period from United States.; converted date from text to a proper DATE column via STR_TO_DATE + ALTER TABLE.

3. Handled nulls and blanks. Converted empty strings to NULL, then recovered missing industries with a self-join — copying the value from another row of the same company (e.g. Airbnb → Travel) instead of discarding data.

4. Removed unusable data. Deleted rows where both layoff metrics were NULL (no analytical value), and dropped the helper row_num column. Final table: 1,995 clean rows.

Part 2 — Exploratory Data Analysis

Techniques: aggregate functions, GROUP BY, subqueries, CTEs, and window functions (SUM() OVER, DENSE_RANK).

Key findings


116 companies laid off 100% of staff — several had raised huge sums, including Britishvolt ($2.4B) and Quibi ($1.8B). Funding didn't guarantee survival.
Largest single layoff event: Google — 12,000 employees (Jan 2023), ahead of Meta (11,000) and Amazon (10,000).
Amazon leads cumulative layoffs (18,150 across multiple rounds), followed by Google and Meta.
The US dominates: 256,559 laid off — over 7× second-place India (35,993).
Consumer (45,182) and Retail (43,613) were the hardest-hit industries.
The rolling monthly total shows a sharp acceleration from late 2022 into early 2023 — the first three months of 2023 alone rival full prior years.
Year-by-year DENSE_RANK top-5: Uber led 2020, Bytedance 2021, Meta 2022, Google 2023 — the downturn shifted from pandemic-hit startups to big tech.


What I learned


Staging-table workflow: destructive operations (INSERT, TRUNCATE, DELETE) are re-runnable hazards — comment them out once executed.
NULL vs empty string are different, and = NULL never matches — use IS NULL.
Window functions vs GROUP BY: when to collapse rows and when to keep them.
Verify everything: every destructive statement followed by a row-count check.


