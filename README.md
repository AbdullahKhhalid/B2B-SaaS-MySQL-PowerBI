# B2B SaaS Marketing & Sales Analytics

End-to-end analytics project on a synthetic B2B SaaS dataset (11 tables, ~255K rows). It follows the full pipeline: raw CSV import, data cleaning and transformation in MySQL, then a 4-page interactive Power BI report. After NorthCart (e-commerce), this project shows my skills in a different industry, with a focus on marketing, sales and subscription metrics, and especially on Power BI work (data modelling, DAX and Power Query).

> **Note on the data:** the dataset is AI-generated and skewed in places. Some figures are extreme (for example, an 82.97% churn rate) and date coverage differs between tables, running from January 2023 into late 2026. The aim of this project is to show my technical skills, not to draw real business conclusions from the numbers.

## Overview
- **Stack:** MySQL 8, DBeaver, Power BI Desktop
- **Dataset:** 11 tables covering accounts, leads and opportunities, subscriptions and billing, churn, ad spend, user sessions and web/app events
- **Approach:** all MySQL work lives in three scripts (Data Import, Data Cleaning, Data Transformation). The cleaned data is loaded into Power BI using SQL statements in Power Query.

## MySQL
- **Import:** `LOAD DATA LOCAL INFILE` from CSV, idempotent table creation (`CREATE TABLE IF NOT EXISTS` + `TRUNCATE`), row-count verification across all tables
- **Cleaning:** trimming and standardising text, empty values to `NULL`, mixed date formats (ISO, US, Unix epoch) converted to `DATETIME` using `REGEXP`, `STR_TO_DATE` and `FROM_UNIXTIME`
- **Transformation:** JSON tracking parameters extracted into columns (`JSON_EXTRACT`, `JSON_UNQUOTE`), duplicate removal, subqueries, date functions
- **Integrity and safety:** primary and foreign keys (after resolving orphan records), `ALTER TABLE ... MODIFY` for data types, changes tested inside `START TRANSACTION` with `COMMIT` / `ROLLBACK`

## Power Query
- SQL statements on import, so only the needed data is loaded
- `RangeStart` / `RangeEnd` parameters and date filters for incremental refresh
- Query folding verified with View Native Query
- M language: I know where and how M can be used (Blank Query, Custom Column, Advanced Editor), but I'm a beginner and haven't used it in this project, since the transformation work was done in MySQL

## Power BI Model & DAX
- **Model:** star schema with many-to-one relationships from fact tables to dimensions, a shared date dimension, and a dedicated measures table
- **DAX:** `CALCULATE`, `DISTINCTCOUNT`, `DIVIDE`, `DATEDIFF`, `AVERAGEX`, `IN` filters, and blank handling with `SELECTEDVALUE` / `ISBLANK`
- **Incremental refresh policy:** configured on one table to test it out

## Power BI Report
A 4-page report with page navigation and a clear-filters button. Every visual answers a business question, with data labels, no gridlines and formatted measures.

| Page | What it shows |
|---|---|
| **Overview** | Invoice total, MRR, ARR, churn rate, LTV, CAC and ROAS; quarterly revenue and churn trend; top countries by session hours and account count; plan popularity by billed amount |
| **Sales Analysis** | Closed won and lost deals and values; deals by lead source and loss reason; average onboarding days; win rate by salesperson |
| **Marketing Analysis** | Impressions, clicks, CTR, ad spend and CPL; spend per channel; CPL vs CAC by channel; sales lifecycle funnel (lead → MQL → SQL → opportunity → closed won) |
| **Account Analysis** | Active vs churned accounts and MRR; quarterly revenue from active accounts and lost to churn; top industries; churn reasons and their revenue impact |

## KPIs
| Metric | Definition used |
|---|---|
| MRR / ARR | Recurring revenue from active customers, monthly and annual |
| Churn Rate | Cancelled ÷ (active + cancelled + past due) |
| CAC | Total ad spend ÷ active accounts |
| ROAS | Total billed amount ÷ total ad spend |
| CTR | Clicks ÷ impressions |
| CPL | Total ad spend ÷ leads generated |
| Win Rate | Deals won ÷ total deals, per sales rep |
| LTV | Average monthly revenue per customer ÷ monthly churn rate |

## Repository Structure
- `/MySQL` – Data Import, Data Cleaning and Data Transformation scripts
- `/PowerBI` – .pbix file and PDF export
- `/ProjectDocs` – Database diagram and project blueprint
