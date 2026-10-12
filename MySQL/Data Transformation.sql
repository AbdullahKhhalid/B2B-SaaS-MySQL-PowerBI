/* =============================================    DATA TRANSFORMATION    ================================================================================


Business Questions & Portfolio Challenges

UTM Channel Performance: Write an SQL query extracting utm_source from JSON in stg_fact_web_app_events, join with stg_dim_utm_channel_mapping,
and calculate total events per marketing channel.

*/

-- CORRECT ANSWER. Most combinations are not being returned.
create table events_per_marketing_channel as
select stg_dim_utm_channel_mapping.marketing_channel as `Marketing Channel`, count(distinct stg_fact_web_app_events.event_id) as `No. Of Events Per Channel`
from stg_dim_utm_channel_mapping
left join stg_fact_web_app_events
on stg_dim_utm_channel_mapping.utm_source = stg_fact_web_app_events.utm_source
and stg_dim_utm_channel_mapping.utm_medium = stg_fact_web_app_events.utm_medium
group by stg_dim_utm_channel_mapping.marketing_channel


-- TESTING THE RESULTS BELOW. What combinations of source and medium are not being returned because of composite join in upper query.
SELECT 
    e.utm_source,
    e.utm_medium,
    COUNT(DISTINCT e.event_id) AS event_count
FROM stg_fact_web_app_events e
LEFT JOIN stg_dim_utm_channel_mapping m
    ON e.utm_source = m.utm_source 
   AND e.utm_medium = m.utm_medium
WHERE m.marketing_channel IS NULL
GROUP BY 1, 2
ORDER BY event_count DESC;

SELECT 
    c.utm_source,
    c.utm_medium,
    COUNT(e.utm_source) AS event_count
FROM stg_dim_utm_channel_mapping c
LEFT JOIN stg_fact_web_app_events e 
    ON c.utm_source = e.utm_source
GROUP BY 1, 2;

-- TESTING CONTINUED FOR QUESTION 1. Does bing even exist in event_params_json col. confirmed that it doesnt exist.
SELECT 
    event_params_json,
    utm_source -- should be NULL based on your cleanup
FROM stg_fact_web_app_events
WHERE event_params_json LIKE '%bing%' 
   OR event_params_json LIKE '%Bing%';


-- Lead Velocity & Bottlenecks: Calculate average time (in days) a lead spends between stages (Lead → MQL → SQL →
-- Opportunity → Closed Won) using SQL window functions (DATEDIFF, LEAD).

-- WRONG ANSWER.
select status, count(status),
avg(datediff(mql_date, created_at)) as `LEAD to MQL days`,
avg(datediff(sql_date, mql_date)) as `MQL to SQL days`,
avg(datediff(opportunity_date, sql_date)) as `SQL to Opportunity days`,
avg(datediff(closed_date,opportunity_date)) as `Opportunity to Close days`
from stg_fact_crm_leads_opportunities
group by status

-- CHECKING THE DATEDIFF AGAINST NULL
select datediff(mql_date, created_at) as `difference between lead and mql`, datediff(sql_date, mql_date) as `difference between mql and sql`
from stg_fact_crm_leads_opportunities
where lead_id = 'LD-000001'



SELECT
    DATE_FORMAT(created_at, '%Y-%m-01') AS lead_month,
    COUNT(*)                            AS leads,
    COUNT(mql_date)                     AS mqls,
    COUNT(sql_date)                     AS sqls,
    COUNT(opportunity_date)             AS opps,
    SUM(status = 'Closed Won')          AS won,
    ROUND(AVG(DATEDIFF(mql_date, created_at)), 1)         AS lead_to_mql_days,
    ROUND(AVG(DATEDIFF(sql_date, mql_date)), 1)           AS mql_to_sql_days,
    ROUND(AVG(DATEDIFF(opportunity_date, sql_date)), 1)   AS sql_to_opp_days,
    ROUND(AVG(CASE WHEN status = 'Closed Won'
                   THEN DATEDIFF(closed_date, opportunity_date) END), 1) AS opp_to_won_days
FROM stg_fact_crm_leads_opportunities
GROUP BY lead_month
ORDER BY lead_month;


-- CORRECT ANSWER
create table Lead_Velocity as
WITH stages AS (
    SELECT lead_id, 'Lead' AS stage, 1 AS stage_order, created_at AS stage_date
    FROM stg_fact_crm_leads_opportunities
    UNION ALL
    SELECT lead_id, 'MQL', 2, mql_date
    FROM stg_fact_crm_leads_opportunities WHERE mql_date IS NOT NULL
    UNION ALL
    SELECT lead_id, 'SQL', 3, sql_date
    FROM stg_fact_crm_leads_opportunities WHERE sql_date IS NOT NULL
    UNION ALL
    SELECT lead_id, 'Opportunity', 4, opportunity_date
    FROM stg_fact_crm_leads_opportunities WHERE opportunity_date IS NOT NULL
    UNION ALL
    SELECT lead_id, 'Closed Won', 5, closed_date
    FROM stg_fact_crm_leads_opportunities WHERE closed_date IS NOT null AND status = 'Closed Won'
),
transitions AS (
    SELECT
        stage,
        stage_order,
        stage_date,
        FIRST_VALUE(stage_date) OVER (PARTITION BY lead_id ORDER BY stage_order) AS lead_created,
        LEAD(stage)      OVER (PARTITION BY lead_id ORDER BY stage_order) AS next_stage,
        LEAD(stage_date) OVER (PARTITION BY lead_id ORDER BY stage_order) AS next_date
    FROM stages
)
SELECT
    DATE_FORMAT(lead_created, '%Y-%m-01')          AS lead_month,
    CONCAT(stage, ' → ', next_stage)               AS transition,
    COUNT(*)                                       AS leads,
    ROUND(AVG(DATEDIFF(next_date, stage_date)), 1) AS avg_days
FROM transitions
WHERE next_stage IS NOT NULL
GROUP BY lead_month, stage, next_stage, stage_order
ORDER BY lead_month, stage_order;


-- Subscription Cohort Churn: Group subscribers by signup month and calculate 30-day, 60-day, and 90-day subscription
-- churn rates in SQL.

-- WRONG ANSWER
select monthname(signup_date), count(cancellation_date),
case
	when datediff(cancellation_date, signup_date) <= 30 then count(stg_dim_accounts.account_id)
end as '30 day churn'
from stg_dim_accounts
join stg_fact_subscription_churn_cancellations
on stg_dim_accounts.account_id = stg_fact_subscription_churn_cancellations.account_id
group by monthname(signup_date)

-- CORRECT ANSWER.
create table subscription_cohort_churn as
SELECT
    DATE_FORMAT(s.signup_date, '%Y-%m') AS signup_month,
    COUNT(*) AS subscribers,
    ROUND(100 * SUM(DATEDIFF(c.cancellation_date, s.signup_date) <= 30) / COUNT(*), 2) AS churn_30d_pct,
    ROUND(100 * SUM(DATEDIFF(c.cancellation_date, s.signup_date) <= 60) / COUNT(*), 2) AS churn_60d_pct,
    ROUND(100 * SUM(DATEDIFF(c.cancellation_date, s.signup_date) <= 90) / COUNT(*), 2) AS churn_90d_pct
FROM (
    SELECT account_id, MIN(signup_date) AS signup_date
    FROM stg_dim_accounts
    GROUP BY account_id
) s
LEFT JOIN (
    SELECT account_id, MIN(cancellation_date) AS cancellation_date
    FROM stg_fact_subscription_churn_cancellations
    GROUP BY account_id
) c ON s.account_id = c.account_id
WHERE s.signup_date <= DATE_SUB(
    (SELECT MAX(signup_date) FROM stg_dim_accounts), INTERVAL 90 DAY)
GROUP BY DATE_FORMAT(s.signup_date, '%Y-%m')
ORDER BY signup_month;

-- WRONG ANSWER
SELECT
    DATE_FORMAT(a.signup_date, '%Y-%m') AS signup_month,
    COUNT(*) AS subscribers,
    ROUND(100 * SUM(DATEDIFF(c.cancellation_date, a.signup_date) <= 30) / COUNT(*), 2) AS churn_30d_pct,
    ROUND(100 * SUM(DATEDIFF(c.cancellation_date, a.signup_date) <= 60) / COUNT(*), 2) AS churn_60d_pct,
    ROUND(100 * SUM(DATEDIFF(c.cancellation_date, a.signup_date) <= 90) / COUNT(*), 2) AS churn_90d_pct
FROM stg_dim_accounts a
LEFT JOIN stg_fact_subscription_churn_cancellations c
    ON a.account_id = c.account_id
GROUP BY DATE_FORMAT(a.signup_date, '%Y-%m')
ORDER BY signup_month;

-- CHECKING IF RESULTS ARE FAN OUT
SELECT account_id, COUNT(*) FROM stg_fact_subscription_churn_cancellations
GROUP BY account_id HAVING COUNT(*) > 1;

-- Sales Rep Quota Attainment Stored Procedure: Write a MySQL stored procedure accepting Quarter and Year
-- parameters that returns each sales rep's closed-won deal volume, quota target, and attainment %.

-- PARTIALLY TRUE BUT WRONG ANSWER.
create table sales_rep_total_revenue as
with valid_sales_reps as (
	select rep_id, rep_name, quota_q1
	from stg_dim_sales_reps
	where status = 'Active'
),
attainment_table as (
	select assigned_rep_id as `Sales Representative`, rep_name as `Sales Rep Full Name`, quota_q1 as `Quota Target For Each Quarter`, sum(deal_value) as `Total Revenue Generated`
	from valid_sales_reps
	inner join stg_fact_crm_leads_opportunities on valid_sales_reps.rep_id = stg_fact_crm_leads_opportunities.assigned_rep_id
	where stg_fact_crm_leads_opportunities.status = 'Closed Won'
	group by assigned_rep_id
)
select *
from attainment_table


-- CORRECT ANSWER
DELIMITER //

DROP PROCEDURE IF EXISTS GetRepQuotaAttainment //

CREATE PROCEDURE GetRepQuotaAttainment(
    IN p_quarter INT,
    IN p_year INT
)
BEGIN
    WITH valid_sales_reps AS (
        SELECT 
            stg_dim_sales_reps.rep_id, 
            stg_dim_sales_reps.rep_name, 
            stg_dim_sales_reps.quota_q1
        FROM stg_dim_sales_reps
        WHERE stg_dim_sales_reps.status = 'Active'
    )
    SELECT 
        stg_fact_crm_leads_opportunities.assigned_rep_id, 
        valid_sales_reps.rep_name, 
        valid_sales_reps.quota_q1, 
        SUM(stg_fact_crm_leads_opportunities.deal_value) AS `Closed Won Deal Volume`, 
        ROUND((SUM(stg_fact_crm_leads_opportunities.deal_value) / valid_sales_reps.quota_q1) * 100, 2) AS `Attainment %`
    FROM valid_sales_reps
    INNER JOIN stg_fact_crm_leads_opportunities 
        ON valid_sales_reps.rep_id = stg_fact_crm_leads_opportunities.assigned_rep_id
    WHERE stg_fact_crm_leads_opportunities.status = 'Closed Won'
      AND QUARTER(stg_fact_crm_leads_opportunities.closed_date) = p_quarter
      AND YEAR(stg_fact_crm_leads_opportunities.closed_date) = p_year
    GROUP BY 
        stg_fact_crm_leads_opportunities.assigned_rep_id,
        valid_sales_reps.rep_name,
        valid_sales_reps.quota_q1;
END //

DELIMITER ;

-- CALLING THE STORED PROCEDURE
CALL GetRepQuotaAttainment(4, 2025);



-- CORRECT ANSWER FOR POWER BI
CREATE TABLE sales_rep_quota_attainment AS
WITH valid_sales_reps AS (
    SELECT
        stg_dim_sales_reps.rep_id,
        stg_dim_sales_reps.rep_name,
        stg_dim_sales_reps.quota_q1
    FROM stg_dim_sales_reps
    WHERE stg_dim_sales_reps.status = 'Active'
)
SELECT
    YEAR(stg_fact_crm_leads_opportunities.closed_date)    AS closed_year,
    QUARTER(stg_fact_crm_leads_opportunities.closed_date) AS closed_quarter,
    stg_fact_crm_leads_opportunities.assigned_rep_id      AS rep_id,
    valid_sales_reps.rep_name,
    valid_sales_reps.quota_q1                             AS quota_target,
    SUM(stg_fact_crm_leads_opportunities.deal_value)      AS closed_won_deal_volume,
    ROUND((SUM(stg_fact_crm_leads_opportunities.deal_value) / valid_sales_reps.quota_q1) * 100, 2) AS attainment_pct
FROM valid_sales_reps
INNER JOIN stg_fact_crm_leads_opportunities
    ON valid_sales_reps.rep_id = stg_fact_crm_leads_opportunities.assigned_rep_id
WHERE stg_fact_crm_leads_opportunities.status = 'Closed Won'
GROUP BY
    YEAR(stg_fact_crm_leads_opportunities.closed_date),
    QUARTER(stg_fact_crm_leads_opportunities.closed_date),
    stg_fact_crm_leads_opportunities.assigned_rep_id,
    valid_sales_reps.rep_name,
    valid_sales_reps.quota_q1;


-- TESTING THE RESULTS
SELECT 
    assigned_rep_id,
    COUNT(lead_id) AS total_deals_counted,
    COUNT(DISTINCT lead_id) AS unique_deals,
    SUM(deal_value) AS total_revenue
FROM stg_fact_crm_leads_opportunities
WHERE status = 'Closed Won'
  AND QUARTER(closed_date) = 1
  AND YEAR(closed_date) = 2024
GROUP BY assigned_rep_id;

SELECT 
    assigned_rep_id,
    closed_date,
    QUARTER(closed_date) AS parsed_quarter,
    YEAR(closed_date) AS parsed_year,
    deal_value
FROM stg_fact_crm_leads_opportunities
WHERE status = 'Closed Won'
  AND assigned_rep_id = 'REP-001';

SELECT 
    assigned_rep_id,
    COUNT(lead_id) AS total_deals_counted,
    COUNT(DISTINCT lead_id) AS unique_deals,
    SUM(deal_value) AS total_revenue
FROM stg_fact_crm_leads_opportunities
WHERE status = 'Closed Won'
  AND assigned_rep_id = 'REP-004'
  AND QUARTER(closed_date) = 3
  AND YEAR(closed_date) = 2025
GROUP BY assigned_rep_id;

SELECT 
    assigned_rep_id,
    closed_date,
    QUARTER(closed_date) AS parsed_quarter,
    YEAR(closed_date) AS parsed_year,
    deal_value
FROM stg_fact_crm_leads_opportunities
WHERE status = 'Closed Won'
  AND assigned_rep_id = 'REP-004'
  AND QUARTER(closed_date) = 3
  AND YEAR(closed_date) = 2025;



-- Creating other tables that answer or help in answering business questions. Need this for importing to power bi

-- Paid CAC
create table paid_cac_over_time as
SELECT 
  spend_summary.year,
  spend_summary.quarter,
  round(spend_summary.total_spend / account_summary.total_customers, 2) AS paid_cac
FROM (
  SELECT 
    YEAR(spend_date) AS year,
    QUARTER(spend_date) AS quarter,
    SUM(daily_spend) AS total_spend
  FROM stg_fact_ad_campaign_spend
  GROUP BY YEAR(spend_date), QUARTER(spend_date)
) AS spend_summary
INNER JOIN (
  SELECT 
    YEAR(signup_date) AS year,
    QUARTER(signup_date) AS quarter,
    COUNT(DISTINCT account_id) AS total_customers
  FROM stg_dim_accounts
  WHERE signup_date IS NOT NULL
  GROUP BY YEAR(signup_date), QUARTER(signup_date)
) AS account_summary
  ON spend_summary.year = account_summary.year
 AND spend_summary.quarter = account_summary.quarter
ORDER BY year, quarter;


/*

Win Rate = deals_won ÷ deals_resolved
Avg Deal Value = total_won_value ÷ deals_won
Avg Days to Close = total_days_to_close ÷ deals_won
Sales Velocity = deals × Avg Deal Value × Win Rate ÷ Avg Days to Close

*/

create table agg_sales_velocity as
select year(opportunity_date) as `year`, quarter(opportunity_date) as `quarter`, count(*) as `deals`, sum(status = 'Closed Won') as `deals_won`,
sum(status in ('Closed Won', 'Closed Lost')) as `deals_resolved`, sum(case when status = 'Closed Won' then deal_value end) as `total_won_value`,
sum(case when status = 'Closed Won' then datediff(closed_date, opportunity_date) end) as `total_days_to_close`
from stg_fact_crm_leads_opportunities
where opportunity_date is not null
group by year(opportunity_date), quarter(opportunity_date);

/*

ROAS (Return on Ad Spend) - Formula: Revenue Made From Ads / Total Ad Spend
Tells you how many dollars in revenue you get back for every single dollar spent on online advertising.
since we dont have revenue from ads so i'll do total revenue / ad spend and call it blended roas
*/

create table billed_revenue_over_time as
select quarter(start_date) as `Quarter`, year(start_date) as `Year`, sum(mrr_amount) as `Total Revenue`
from stg_fact_subscription_billing
where subscription_status not in ('Cancelled')
group by quarter(start_date), year(start_date)

create table ad_spend_over_time as
select quarter(spend_date) as `Quarter`, year(spend_date) as `Year`, sum(daily_spend) as `Ad Spend`
from stg_fact_ad_campaign_spend
group by quarter(spend_date), year(spend_date)


-- Active Customers over time.
create table active_accounts_over_time as
select quarter(start_date) as `Quarter`, year(start_date) as `Year`, count(account_id) as `Active Accounts`
from stg_fact_subscription_billing
where subscription_status = 'Active'
group by quarter(start_date), year(start_date)


-- MRR over time
create table mrr_over_time as
select quarter(start_date) as `Quarter`, year(start_date) as `Year`, sum(mrr_amount) as `MRR`
from stg_fact_subscription_billing
where subscription_status = 'Active' and billing_cycle = 'Monthly'
group by quarter(start_date), year(start_date)


-- ARR over time
create table arr_over_time as
select quarter(start_date) as `Quarter`, year(start_date) as `Year`, sum(mrr_amount) as `ARR`
from stg_fact_subscription_billing
where subscription_status = 'Active' and billing_cycle = 'Annual'
group by quarter(start_date), year(start_date)


-- Biggest reason for Churn Cancellations
create table churn_over_time as

insert into churn_over_time
select quarter(cancellation_date), year(cancellation_date), churn_reason as `Reason`, count(distinct stg_fact_subscription_churn_cancellations.account_id) as `No. Of Customers`
from stg_fact_subscription_churn_cancellations
inner join stg_fact_subscription_billing on stg_fact_subscription_churn_cancellations.account_id = stg_fact_subscription_billing.account_id
where churn_date is not null
group by churn_reason, quarter(cancellation_date), year(cancellation_date)

truncate table churn_over_time

select churn_reason as `Reason`, count(distinct account_id) as `No. Of Customers`
from stg_fact_subscription_churn_cancellations
group by churn_reason


/* Churn and Gross MRR Churn % table

Churn Rate % = cancelled ÷ active_start × 100
Gross MRR Churn % = mrr_lost ÷ mrr_start × 100

*/

create table churn_gross_percent as
select year(start_date) as `Year`, quarter(start_date) as `Quarter`,
count(distinct case when subscription_status = 'Active' then account_id end) as active_start,
sum(case when subscription_status = 'Active' then mrr_amount end) as mrr_start,
count(distinct case when subscription_status = 'Cancelled' then account_id end) as cancelled,
sum(case when subscription_status = 'Cancelled' then mrr_amount end) as mrr_lost
from stg_fact_subscription_billing
group by year(start_date), quarter(start_date);




-- Dropping all newly created tables

drop table active_accounts_over_time, ad_spend_over_time, agg_sales_velocity, arr_over_time, billed_revenue_over_time,
churn_gross_percent, churn_over_time, events_per_marketing_channel, lead_velocity, mrr_over_time, paid_cac_over_time, sales_rep_quota_attainment,
sales_rep_total_revenue, subscription_cohort_churn



select count(*)
from stg_fact_crm_leads_opportunities
inner join stg_fact_user_sessions on stg_fact_crm_leads_opportunities.lead_id = stg_fact_user_sessions.lead_id

select count(*)
from stg_fact_user_sessions

select count(*)
from stg_fact_web_app_events 

select count(distinct event_id)
from stg_fact_user_sessions
inner join stg_fact_web_app_events on stg_fact_user_sessions.session_id = stg_fact_web_app_events.session_id

select distinct(event_name)
from stg_fact_web_app_events

select sum(deal_value)
from stg_fact_crm_leads_opportunities
where status = 'Closed Lost'


select status, count(status)
from stg_fact_crm_leads_opportunities
group by status


select count(distinct account_id)
from stg_fact_subscription_churn_cancellations


select count(distinct account_id)
from stg_fact_subscription_billing
where subscription_status = 'Active'


select count(distinct account_id)
from stg_fact_subscription_billing
where subscription_status = 'Cancelled'

select avg(DATEDIFF(closed_date, opportunity_date))
from stg_fact_crm_leads_opportunities

select sum(mrr_amount)
from stg_fact_subscription_billing


with testing as (
	select (select count(distinct account_id) from stg_fact_subscription_billing where subscription_status = 'Cancelled') as `cancelled count`,
	(select count(distinct account_id) from stg_fact_subscription_billing where subscription_status in ('Active', 'Cancelled', 'Past Due')) as `total count`
)
select `cancelled count` / `total count` * 100 as `churn rate`
from testing 

select count(*)
from stg_fact_crm_leads_opportunities


select 'cancelled count', count(subscription_id)
from stg_fact_subscription_billing
where subscription_status = 'Cancelled'
union all
select 'all customers', count(subscription_id)
from stg_fact_subscription_billing
where subscription_status in ('Active', 'Cancelled', 'Past Due')


select count(*)
from stg_fact_subscription_billing sfsb 
where sfsb.subscription_status = 'Trial'












WITH stages AS (
    SELECT lead_id, 'Lead' AS stage, 1 AS stage_order, created_at AS stage_date
    FROM stg_fact_crm_leads_opportunities
    UNION ALL
    SELECT lead_id, 'MQL', 2, mql_date
    FROM stg_fact_crm_leads_opportunities WHERE mql_date IS NOT NULL
    UNION ALL
    SELECT lead_id, 'SQL', 3, sql_date
    FROM stg_fact_crm_leads_opportunities WHERE sql_date IS NOT NULL
    UNION ALL
    SELECT lead_id, 'Opportunity', 4, opportunity_date
    FROM stg_fact_crm_leads_opportunities WHERE opportunity_date IS NOT NULL
    UNION ALL
    SELECT lead_id, 'Closed Won', 5, closed_date
    FROM stg_fact_crm_leads_opportunities WHERE closed_date IS NOT null AND status = 'Closed Won'
),
transitions AS (
    SELECT
        stage,
        stage_order,
        stage_date,
        FIRST_VALUE(stage_date) OVER (PARTITION BY lead_id ORDER BY stage_order) AS lead_created,
        LEAD(stage)      OVER (PARTITION BY lead_id ORDER BY stage_order) AS next_stage,
        LEAD(stage_date) OVER (PARTITION BY lead_id ORDER BY stage_order) AS next_date
    FROM stages
)
SELECT
    DATE_FORMAT(lead_created, '%Y-%m-01')          AS lead_month,
    CONCAT(stage, ' → ', next_stage)               AS transition,
    COUNT(*)                                       AS leads,
    ROUND(AVG(DATEDIFF(next_date, stage_date)), 1) AS avg_days
FROM transitions
WHERE next_stage IS NOT NULL
GROUP BY lead_month, stage, next_stage, stage_order
ORDER BY lead_month, stage_order;





CREATE TABLE test_orders (
    customer_id INT,
    order_date DATE,
    amount INT
);

INSERT INTO test_orders VALUES
(1, '2026-01-05', 100),
(1, '2026-01-20', 150),
(1, '2026-02-10', 80),
(2, '2026-01-08', 200),
(2, '2026-03-01', 50),
(3, '2026-02-01', 75);


with customerrrr as (
select customer_id, first_value(order_date) over (partition by customer_id order by order_date) as `first_order_date`,
lead(order_date) over (partition by customer_id order by order_date) as `next_order_date`, order_date
from test_orders
)
select customer_id, first_order_date, avg(datediff(next_order_date, order_date)) as `avg_days`
from customerrrr
where next_order_date is not null
group by customer_id, first_order_date





WITH customerrrr AS (
    SELECT
        customer_id,
        order_date,
        FIRST_VALUE(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS first_order_date,
        LEAD(order_date)        OVER (PARTITION BY customer_id ORDER BY order_date) AS next_order_date
    FROM test_orders
)
SELECT
    customer_id,
    first_order_date,
    AVG(DATEDIFF(next_order_date, order_date)) AS avg_days
FROM customerrrr
WHERE next_order_date IS NOT NULL
GROUP BY customer_id, first_order_date;





select sum(daily_spend)
from stg_fact_ad_campaign_spend




