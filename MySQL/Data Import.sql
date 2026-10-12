USE saas_analytics_staging;

-- ============================================================================
-- 0. ENSURE MISSING TABLES EXIST IF YOU ONLY CREATED 8 PREVIOUSLY
-- ============================================================================

CREATE TABLE IF NOT EXISTS stg_dim_product_plans (
    plan_id VARCHAR(50),
    plan_name VARCHAR(100),
    billing_frequency VARCHAR(50),
    monthly_price DECIMAL(10,2),
    annual_price DECIMAL(10,2),
    max_seats INT,
    feature_tier VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS stg_dim_sales_reps (
    rep_id VARCHAR(50),
    rep_name VARCHAR(100),
    sales_team VARCHAR(50),
    region VARCHAR(50),
    hire_date VARCHAR(50),
    quota_q1 DECIMAL(12,2),
    status VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS stg_dim_accounts (
    account_id VARCHAR(50),
    company_name VARCHAR(255),
    industry VARCHAR(100),
    company_size VARCHAR(50),
    country VARCHAR(100),
    signup_date VARCHAR(100),
    account_owner_id VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS stg_dim_utm_channel_mapping (
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    marketing_channel VARCHAR(100),
    channel_group VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS stg_dim_ad_groups (
    ad_group_id VARCHAR(50),
    channel VARCHAR(100),
    campaign_name VARCHAR(255),
    ad_group_name VARCHAR(255),
    target_keywords_audience VARCHAR(255),
    status VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS stg_fact_ad_campaign_spend (
    spend_id VARCHAR(50),
    spend_date VARCHAR(50),
    ad_group_id VARCHAR(50),
    channel VARCHAR(100),
    campaign_name VARCHAR(255),
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    impressions INT,
    clicks INT,
    daily_spend DECIMAL(12,2)
);

CREATE TABLE IF NOT EXISTS stg_fact_crm_leads_opportunities (
    lead_id VARCHAR(50),
    account_id VARCHAR(50),
    lead_source VARCHAR(100),
    lead_score INT,
    status VARCHAR(50),
    created_at VARCHAR(100),
    mql_date VARCHAR(100),
    sql_date VARCHAR(100),
    opportunity_date VARCHAR(100),
    closed_date VARCHAR(100),
    deal_value DECIMAL(12,2),
    assigned_rep_id VARCHAR(50),
    loss_reason VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS stg_fact_subscription_billing (
    subscription_id VARCHAR(50),
    account_id VARCHAR(50),
    plan_id VARCHAR(50),
    start_date VARCHAR(100),
    end_date VARCHAR(100),
    mrr_amount DECIMAL(12,2),
    billing_cycle VARCHAR(50),
    subscription_status VARCHAR(50),
    churn_date VARCHAR(100),
    payment_gateway VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS stg_fact_subscription_churn_cancellations (
    churn_id VARCHAR(50),
    subscription_id VARCHAR(50),
    account_id VARCHAR(50),
    plan_id VARCHAR(50),
    cancellation_date VARCHAR(100),
    lost_mrr DECIMAL(12,2),
    churn_reason VARCHAR(255),
    feedback_notes TEXT
);

CREATE TABLE IF NOT EXISTS stg_fact_user_sessions (
    session_id VARCHAR(50),
    lead_id VARCHAR(50),
    account_id VARCHAR(50),
    platform VARCHAR(50),
    device_type VARCHAR(50),
    session_start VARCHAR(100),
    session_duration_sec INT,
    page_views INT,
    country VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS stg_fact_web_app_events (
    event_id VARCHAR(50),
    session_id VARCHAR(50),
    account_id VARCHAR(50),
    event_name VARCHAR(100),
    event_timestamp VARCHAR(100),
    event_params_json TEXT,
    platform VARCHAR(50)
);


-- ============================================================================
-- 1. DIMENSION TABLES (IDEMPOTENT INGESTION)
-- ============================================================================

-- 1.1 Product Plans
TRUNCATE TABLE stg_dim_product_plans;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/dim_product_plans.csv'
INTO TABLE stg_dim_product_plans
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(plan_id, plan_name, billing_frequency, monthly_price, annual_price, max_seats, feature_tier);

-- 1.2 Sales Reps
TRUNCATE TABLE stg_dim_sales_reps;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/dim_sales_reps.csv'
INTO TABLE stg_dim_sales_reps
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(rep_id, rep_name, sales_team, region, hire_date, quota_q1, status);

-- 1.3 Accounts
TRUNCATE TABLE stg_dim_accounts;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/dim_accounts.csv'
INTO TABLE stg_dim_accounts
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(account_id, company_name, industry, company_size, country, signup_date, account_owner_id);

-- 1.4 UTM Channel Mapping
TRUNCATE TABLE stg_dim_utm_channel_mapping;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/dim_utm_channel_mapping.csv'
INTO TABLE stg_dim_utm_channel_mapping
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(utm_source, utm_medium, marketing_channel, channel_group);

-- 1.5 Ad Groups
TRUNCATE TABLE stg_dim_ad_groups;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/dim_ad_groups.csv'
INTO TABLE stg_dim_ad_groups
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(ad_group_id, channel, campaign_name, ad_group_name, target_keywords_audience, status);


-- ============================================================================
-- 2. FACT TABLES (IDEMPOTENT INGESTION)
-- ============================================================================

-- 2.1 Ad Campaign Spend
TRUNCATE TABLE stg_fact_ad_campaign_spend;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/fact_ad_campaign_spend.csv'
INTO TABLE stg_fact_ad_campaign_spend
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(spend_id, spend_date, ad_group_id, channel, campaign_name, utm_source, utm_medium, impressions, clicks, daily_spend);

-- 2.2 CRM Leads & Opportunities
TRUNCATE TABLE stg_fact_crm_leads_opportunities;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/fact_crm_leads_opportunities.csv'
INTO TABLE stg_fact_crm_leads_opportunities
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(lead_id, account_id, lead_source, lead_score, status, created_at, mql_date, sql_date, opportunity_date, closed_date, deal_value, assigned_rep_id, loss_reason);

-- 2.3 Subscription Billing
TRUNCATE TABLE stg_fact_subscription_billing;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/fact_subscription_billing.csv'
INTO TABLE stg_fact_subscription_billing
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(subscription_id, account_id, plan_id, start_date, end_date, mrr_amount, billing_cycle, subscription_status, churn_date, payment_gateway);

-- 2.4 Subscription Churn & Cancellations
TRUNCATE TABLE stg_fact_subscription_churn_cancellations;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/fact_subscription_churn_cancellations.csv'
INTO TABLE stg_fact_subscription_churn_cancellations
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(churn_id, subscription_id, account_id, plan_id, cancellation_date, lost_mrr, churn_reason, feedback_notes);

-- 2.5 User Sessions
TRUNCATE TABLE stg_fact_user_sessions;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/fact_user_sessions.csv'
INTO TABLE stg_fact_user_sessions
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(session_id, lead_id, account_id, platform, device_type, session_start, session_duration_sec, page_views, country);

-- 2.6 Web & App Event Logs
TRUNCATE TABLE stg_fact_web_app_events;
LOAD DATA LOCAL INFILE 'C:/saas marketing project/b2b_saas_dataset_11_tables_complete/fact_web_app_events.csv'
INTO TABLE stg_fact_web_app_events
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(event_id, session_id, account_id, event_name, event_timestamp, event_params_json, platform);


-- ============================================================================
-- 3. INGESTION VERIFICATION
-- ============================================================================

SELECT 'stg_dim_product_plans' AS table_name, COUNT(*) AS row_count FROM stg_dim_product_plans
UNION ALL
SELECT 'stg_dim_sales_reps', COUNT(*) FROM stg_dim_sales_reps
UNION ALL
SELECT 'stg_dim_accounts', COUNT(*) FROM stg_dim_accounts
UNION ALL
SELECT 'stg_dim_utm_channel_mapping', COUNT(*) FROM stg_dim_utm_channel_mapping
UNION ALL
SELECT 'stg_dim_ad_groups', COUNT(*) FROM stg_dim_ad_groups
UNION ALL
SELECT 'stg_fact_ad_campaign_spend', COUNT(*) FROM stg_fact_ad_campaign_spend
UNION ALL
SELECT 'stg_fact_crm_leads_opportunities', COUNT(*) FROM stg_fact_crm_leads_opportunities
UNION ALL
SELECT 'stg_fact_subscription_billing', COUNT(*) FROM stg_fact_subscription_billing
UNION ALL
SELECT 'stg_fact_subscription_churn_cancellations', COUNT(*) FROM stg_fact_subscription_churn_cancellations
UNION ALL
SELECT 'stg_fact_user_sessions', COUNT(*) FROM stg_fact_user_sessions
UNION ALL
SELECT 'stg_fact_web_app_events', COUNT(*) FROM stg_fact_web_app_events;


TRUNCATE TABLE stg_dim_accounts;
truncate table stg_dim_ad_groups;
truncate table stg_dim_sales_reps;
truncate table stg_fact_user_sessions;

