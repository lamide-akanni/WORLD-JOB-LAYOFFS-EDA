-- World (Job) Layoffs

-- Obejectives:
-- 1. Data Cleaning
-- 1.0. Create a staging table
-- 1.1. Remove duplicates
-- 1.2. Standardize the data 
-- 1.3. Null and blank values
-- 1.4. Remove unusable rows and columns
-- 2. Exploratory Data Analysis(EDA)
-- 2.1. Get a feel for the scale
-- 2.2. Totals by group (GROUP BY)
-- 2.3. Rolling total by month CTE + window function
-- 2.4. Top 5 companies per year DENSE_RANK

CREATE DATABASE world_layoffs;
USE world_layoffs;
-- table layoffs
SELECT * FROM layoffs;

-- create a stagging table 

CREATE TABLE layoffs_staging 
LIKE layoffs;

INSERT INTO layoffs_staging 
SELECT * FROM layoffs;

SELECT * FROM layoffs_staging; -- expect 2,361 rows

-- Remove duplicates
-- no unique ID column. Number every row within groups of identical rows. 
-- Partition by all columns

SELECT *, ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, 
stage, country, funds_raised_millions) AS row_num 
FROM layoffs_staging;

-- view posible duplicate with CTE

WITH duplicate_cte AS (
SELECT *, ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, 
stage, country, funds_raised_millions) AS row_num 
FROM layoffs_staging
)
SELECT * FROM duplicate_cte
WHERE row_num > 1;

-- 5 rows found
-- cant delete in row in CTE
-- create another staging(2) table with (real) row_num

CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL, 
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO layoffs_staging2
SELECT *, ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, 
stage, country, funds_raised_millions) AS row_num 
FROM layoffs_staging;

SELECT * 
FROM layoffs_staging2;

-- Delete the duplicates.

DELETE FROM layoffs_staging2
WHERE row_num > 1;

SELECT COUNT(*) FROM layoffs_staging2; -- confirm delete.  2,356 row  expect

-- Standardise the data
-- SELECT DISTINCT (columns) FROM layoffs_staging2 ORDER BY 1; -- standardise

-- Trim
SELECT company, TRIM(company) FROM layoffs_staging2; -- inspect first
UPDATE layoffs_staging2
SET company = TRIM(company);

-- Merge industry variants
SELECT DISTINCT industry FROM layoffs_staging2 ORDER BY 1;
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Fix typo error
SELECT DISTINCT country FROM layoffs_staging2 ORDER BY 1;
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Change Date data type 
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- Null and blank values

UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

SELECT DISTINCT industry FROM layoffs_staging2 ORDER BY 1;

SELECT * 
FROM layoffs_staging2
WHERE industry IS NULL; -- 4 rows expected wth null

-- self join
 
SELECT t1.industry, t2.industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
ON t1.company = t2.company
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;  -- epected is Travel, Tranportaion, Consumer 

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- Remove unusable rows and columns
-- total_laid_off & percentage_laid_off nulls, there is nothing to compute or clean

DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- drop the helper column(row_num)
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

SELECT * FROM layoffs_staging2; -- final clean table (~1,995 rows) 

-- EDA
-- Random Queries

SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_staging2;

SELECT company, total_laid_off
FROM layoffs_staging2
WHERE total_laid_off = (SELECT MAX(total_laid_off) FROM layoffs_staging2);

SELECT company, total_laid_off, percentage_laid_off
FROM layoffs_staging2
ORDER BY total_laid_off DESC
LIMIT 3;

-- comapanies that shot down = 100% laid_off = 1 -- 116 Companies 

SELECT * 
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC;

SELECT * FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;

-- Totals by group (GROUP BY)
-- swapping the grouping column each time — company, industry, country, year, stage

SELECT company, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company
ORDER BY 2 DESC;

SELECT industry, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY industry
ORDER BY 2 DESC;

SELECT country, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY country
ORDER BY 2 DESC;

SELECT YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY 1 DESC;

SELECT stage, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY stage
ORDER BY 2 DESC;

SELECT MIN(`date`), MAX(`date`)
FROM layoffs_staging2;

-- Rolling Total

WITH Rolling_Total AS (
SELECT SUBSTRING(`date`,1,7) AS `MONTH`,
SUM(total_laid_off) AS total_off
FROM layoffs_staging2
WHERE SUBSTRING(`date`,1,7) IS NOT NULL
GROUP BY `MONTH`
ORDER BY 1 ASC
)
SELECT `MONTH`, total_off,
SUM(total_off) OVER(ORDER BY `MONTH`) AS rolling_total
FROM Rolling_Total;

WITH Company_Year (company, years, total_laid_off) AS (
SELECT company, YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
),
Company_Year_Rank AS (
SELECT *,
DENSE_RANK() OVER(
PARTITION BY years ORDER BY total_laid_off DESC
) AS ranking
FROM Company_Year
WHERE years IS NOT NULL
)
SELECT *
FROM Company_Year_Rank
WHERE ranking <= 5;





