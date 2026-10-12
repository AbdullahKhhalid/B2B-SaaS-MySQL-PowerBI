-- =====================================    DATA CLEANING ALL THE TABLES   =========================================================================

-- Accounts Table Analysis
select account_id
from stg_dim_accounts


-- didnt work, it inserted because i didnt had primary key
insert into stg_dim_accounts (account_id)
select upper(account_id) as `account_id`
from stg_dim_accounts
on duplicate key update
	account_id = values(account_id);


-- truncating the table to remove the mistake and imported the file again
truncate table stg_dim_accounts;


-- adding primary key
alter table stg_dim_accounts
add primary key (account_id)


-- updating properly now (idempotent way)
update stg_dim_accounts
set
account_id = upper(replace(account_id, '_', '-')),
company_name = trim(company_name)


-- company names fix
select *
from stg_dim_accounts

-- Turn first characters of every word capital
update stg_dim_accounts
set company_name = concat(
    upper(left(substring_index(company_name, ' ', 1), 1)),
    lower(substring(substring_index(company_name, ' ', 1), 2)),
    ' ',
    upper(left(substring_index(substring_index(company_name, ' ', 2), ' ', -1), 1)),
    lower(substring(substring_index(substring_index(company_name, ' ', 2), ' ', -1), 2)),
    ' ',
    upper(left(substring_index(company_name, ' ', -1), 1)),
    lower(substring(substring_index(company_name, ' ', -1), 2))
);


-- Replacing empty industry col values with null
select *
from stg_dim_accounts
where industry = ''

update stg_dim_accounts
set industry =
case
	when industry = '' then null
	else industry
end


-- datetime col getting them all into one format
select distinct signup_date as `signup_date`
from stg_dim_accounts

select *
from stg_dim_accounts
where signup_date is null or signup_date = ''


update stg_dim_accounts
set signup_date = 
case
	when signup_date regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(signup_date, '%Y-%m-%d %H:%i:%s')
	when signup_date regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(signup_date, '%m/%d/%Y %h:%i:%s %p')
	when signup_date regexp '^[0-9]+$' then from_unixtime(signup_date)
	else null
end


-- account_owner issue. false ids above 25
select *
from stg_dim_accounts
where account_owner_id > 'REP-025'

update stg_dim_accounts
set account_owner_id = 
case
	when account_owner_id = 'REP-026' then 'Unassigned'
	when account_owner_id = 'REP-027' then 'Unassigned'
	when account_owner_id = 'REP-028' then 'Unassigned'
	else account_owner_id
end



-- CRM Leads Opportunities table cleaning
update stg_fact_crm_leads_opportunities
set created_at = 
case
	when created_at regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(created_at, '%Y-%m-%d %H:%i:%s')
	when created_at regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(created_at, '%m/%d/%Y %h:%i:%s %p')
	when created_at regexp '^[0-9]+$' then from_unixtime(created_at)
	else null
end,
mql_date = 
case
	when mql_date regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(mql_date, '%Y-%m-%d %H:%i:%s')
	when mql_date regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(mql_date, '%m/%d/%Y %h:%i:%s %p')
	when mql_date regexp '^[0-9]+$' then from_unixtime(mql_date)
	else null
end,
sql_date = 
case
	when sql_date regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(sql_date, '%Y-%m-%d %H:%i:%s')
	when sql_date regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(sql_date, '%m/%d/%Y %h:%i:%s %p')
	when sql_date regexp '^[0-9]+$' then from_unixtime(sql_date)
	else null
end,
opportunity_date = 
case
	when opportunity_date regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(opportunity_date, '%Y-%m-%d %H:%i:%s')
	when opportunity_date regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(opportunity_date, '%m/%d/%Y %h:%i:%s %p')
	when opportunity_date regexp '^[0-9]+$' then from_unixtime(opportunity_date)
	else null
end,
closed_date = 
case
	when closed_date regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(closed_date, '%Y-%m-%d %H:%i:%s')
	when closed_date regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(closed_date, '%m/%d/%Y %h:%i:%s %p')
	when closed_date regexp '^[0-9]+$' then from_unixtime(closed_date)
	else null
end


-- CRM Leads PK and FK
alter table stg_fact_crm_leads_opportunities
add primary key (lead_id),
add constraint fk_account_id
foreign key (account_id) references stg_dim_accounts(account_id);


-- Remove orphaned records (there are extra account_ids in CRM leads table which do not exist in dim_accounts table)
select *
from stg_fact_crm_leads_opportunities
left join stg_dim_accounts
on stg_dim_accounts.account_id = stg_fact_crm_leads_opportunities.account_id
where stg_dim_accounts.account_id is null and stg_fact_crm_leads_opportunities.account_id is not null

-- Adding missing account ids in dim_accounts table so that PK and FK could be setup. Previously it was not working because there were missing records (orphaned)
insert into stg_dim_accounts (account_id, company_name)
select distinct stg_fact_crm_leads_opportunities.account_id, 'Unknown Account'
from stg_fact_crm_leads_opportunities
left join stg_dim_accounts
on stg_dim_accounts.account_id = stg_fact_crm_leads_opportunities.account_id
where stg_dim_accounts.account_id is null and stg_fact_crm_leads_opportunities.account_id is not null


-- Created dates are larger than closed dates. impossible values in CRM Leads table.
select *
from stg_fact_crm_leads_opportunities

start transaction

update stg_fact_crm_leads_opportunities
set
created_at = closed_date,
closed_date = created_at
where created_at > closed_date;

commit;


-- Subscription Billing date fix
update stg_fact_subscription_billing
set start_date = 
case
	when start_date regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(start_date, '%Y-%m-%d %H:%i:%s')
	when start_date regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(start_date, '%m/%d/%Y %h:%i:%s %p')
	when start_date regexp '^[0-9]+$' then from_unixtime(start_date)
	else null
end,
end_date = 
case
	when end_date regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(end_date, '%Y-%m-%d %H:%i:%s')
	when end_date regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(end_date, '%m/%d/%Y %h:%i:%s %p')
	when end_date regexp '^[0-9]+$' then from_unixtime(end_date)
	else null
end,
churn_date = 
case
	when churn_date regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(churn_date, '%Y-%m-%d %H:%i:%s')
	when churn_date regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(churn_date, '%m/%d/%Y %h:%i:%s %p')
	when churn_date regexp '^[0-9]+$' then from_unixtime(churn_date)
	else null
end


-- Fact User Sessions date fix
update stg_fact_user_sessions
set session_start = 
case
	when session_start regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(session_start, '%Y-%m-%d %H:%i:%s')
	when session_start regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(session_start, '%m/%d/%Y %h:%i:%s %p')
	when session_start regexp '^[0-9]+$' then from_unixtime(session_start)
	else null
end


-- Fact Web App Events date fix
update stg_fact_web_app_events
set event_timestamp = 
case
	when event_timestamp regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(event_timestamp, '%Y-%m-%d %H:%i:%s')
	when event_timestamp regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(event_timestamp, '%m/%d/%Y %h:%i:%s %p')
	when event_timestamp regexp '^[0-9]+$' then from_unixtime(event_timestamp)
	else null
end


-- Setting up PK and FK for all remaining tables. Before this, i have only done for dim_accounts and crm leads
alter table stg_dim_ad_groups
add primary key (ad_group_id)

alter table stg_dim_product_plans
add primary key (plan_id)

alter table stg_dim_sales_reps
add primary key (rep_id)

alter table stg_fact_ad_campaign_spend
add primary key (spend_id)

alter table stg_fact_subscription_billing
add primary key (subscription_id)

alter table stg_fact_subscription_churn_cancellations
add primary key (churn_id)

alter table stg_fact_user_sessions
add primary key (session_id)

alter table stg_fact_web_app_events
add primary key (event_id)

alter table stg_dim_utm_channel_mapping
add primary key (utm_source, utm_medium)


-- Removing duplicate records from Web App Events table
start transaction

with removing_duplicates as (
	select *, row_number() over (partition by session_id, event_name, event_timestamp order by event_id) as `row_no`
	from stg_fact_web_app_events
)
select event_id, session_id, account_id, event_name, event_timestamp, event_params_json, platform
from removing_duplicates
where row_no = 1;


DELETE FROM stg_fact_web_app_events
WHERE event_id IN (
    SELECT event_id
    FROM (
        SELECT 
            event_id,
            ROW_NUMBER() OVER (
                PARTITION BY event_id 
                ORDER BY event_id
            ) AS row_num
        FROM stg_fact_web_app_events
        WHERE event_id IS NOT NULL
    ) ranked
    WHERE row_num > 1
);


SELECT COUNT(*) 
FROM (
    SELECT 
        event_id,
        ROW_NUMBER() OVER (
            PARTITION BY session_id, event_name, event_timestamp 
            ORDER BY event_id
        ) AS row_num
    FROM stg_fact_web_app_events
    WHERE session_id IS NOT NULL 
      AND event_name IS NOT NULL 
      AND event_timestamp IS NOT NULL
) ranked
WHERE row_num > 1;


select count(distinct event_id)
from stg_fact_web_app_events


ALTER TABLE stg_fact_web_app_events ADD COLUMN row_id INT AUTO_INCREMENT PRIMARY KEY;

DELETE FROM stg_fact_web_app_events
WHERE row_id IN (
    SELECT row_id FROM (
        SELECT row_id,
               ROW_NUMBER() OVER (
                   PARTITION BY session_id, event_name, event_timestamp
                   ORDER BY event_id, row_id
               ) AS rn
        FROM stg_fact_web_app_events
    ) ranked
    WHERE rn > 1
);

ALTER TABLE stg_fact_web_app_events DROP COLUMN row_id;

SELECT COUNT(*), COUNT(DISTINCT event_id) FROM stg_fact_web_app_events;

commit;



-- Setting up relationships between tables. The only one done so far is between dim_accounts and crm leads
alter table stg_fact_ad_campaign_spend
add constraint fk_ad_group_id
foreign key (ad_group_id) references stg_dim_ad_groups(ad_group_id);

alter table stg_fact_ad_campaign_spend
add constraint composite_fk_from_channel_mapping
foreign key (utm_source, utm_medium)
references stg_dim_utm_channel_mapping (utm_source, utm_medium)


alter table stg_dim_accounts
add foreign key (account_owner_id) references stg_dim_sales_reps (rep_id);

insert into stg_dim_sales_reps(rep_id)
values('Unknown')

update stg_dim_sales_reps
set rep_id = 'Unassigned'
where rep_id = 'Unknown'

alter table stg_fact_subscription_billing
add foreign key (account_id) references stg_dim_accounts (account_id),
add foreign key (plan_id) references stg_dim_product_plans (plan_id)

alter table stg_fact_subscription_churn_cancellations
add foreign key (subscription_id) references stg_fact_subscription_billing (subscription_id),
add foreign key (account_id) references stg_dim_accounts (account_id),
add foreign key (plan_id) references stg_dim_product_plans (plan_id)

alter table stg_fact_user_sessions
add foreign key (lead_id) references stg_fact_crm_leads_opportunities (lead_id),
add foreign key (account_id) references stg_dim_accounts (account_id)

start transaction

update stg_fact_user_sessions
set lead_id = 
case
	when lead_id = '' then null
	else lead_id
end,
account_id = 
case
	when account_id = '' then null
	else account_id
end

select *
from stg_fact_user_sessions

commit;


update stg_fact_web_app_events
set account_id = 
case
	when account_id = '' then null
	else account_id
end

alter table stg_fact_web_app_events
add foreign key (session_id) references stg_fact_user_sessions (session_id),
add foreign key (account_id) references stg_dim_accounts (account_id)


update stg_fact_crm_leads_opportunities
set loss_reason = 
case
	when loss_reason = '' then null
	else loss_reason
end


SELECT loss_reason, LENGTH(loss_reason), HEX(loss_reason), COUNT(*)
FROM stg_fact_crm_leads_opportunities
GROUP BY loss_reason
ORDER BY 4 DESC;

start transaction

UPDATE stg_fact_crm_leads_opportunities
SET loss_reason = NULL
WHERE TRIM(REPLACE(REPLACE(loss_reason, '\r', ''), '\n', '')) = '';

select loss_reason
from stg_fact_crm_leads_opportunities
limit 100;

commit;


alter table stg_fact_crm_leads_opportunities
add foreign key (assigned_rep_id) references stg_dim_sales_reps (rep_id)



update stg_fact_subscription_churn_cancellations
set cancellation_date = 
case
	when cancellation_date regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then str_to_date(cancellation_date, '%Y-%m-%d %H:%i:%s')
	when cancellation_date regexp '^[0-9]{2}/[0-9]{2}/[0-9]{4}' then str_to_date(cancellation_date, '%m/%d/%Y %h:%i:%s %p')
	when cancellation_date regexp '^[0-9]+$' then from_unixtime(cancellation_date)
end

update stg_fact_subscription_churn_cancellations
set feedback_notes = null
where trim(replace(replace(feedback_notes, '\r', ''), '\n', '')) = '';



-- So far, all relationships between tables established. All tables cleaned and data consistency ensured. 
-- Data cleaning part is all done EXCEPT task 3 from project file. Will resolve Semi-Structured JSON issue now on stg_fact_web_app_events table

start transaction

alter table stg_fact_web_app_events
add column utm_source varchar(100),
add column utm_medium varchar(100),
add column utm_campaign varchar(100),
add column page_url varchar(400),
add column screen_resolution varchar(200)

update stg_fact_web_app_events
set utm_source = json_unquote(json_extract(event_params_json, '$.utm_source'));

update stg_fact_web_app_events
set utm_medium = json_unquote(json_extract(event_params_json, '$.utm_medium')),
utm_campaign = json_unquote(json_extract(event_params_json, '$.utm_campaign')),
page_url = json_unquote(json_extract(event_params_json, '$.page_url')),
screen_resolution = json_unquote(json_extract(event_params_json, '$.screen_resolution'))


update stg_fact_web_app_events
set utm_source = 
case
	when utm_source = '' then null
	else utm_source
end,
utm_medium =
case
	when utm_medium = '' then null
	else utm_medium
end,
utm_campaign =
case
	when utm_campaign = '' then null
	else utm_campaign
end,
page_url =
case
	when page_url = '' then null
	else page_url
end,
screen_resolution =
case
	when screen_resolution = '' then null
	else screen_resolution
end


select *
from stg_fact_web_app_events


commit;


-- Convert ALL date cols properly from varchar to datetime. Already converted the values but the col data type is wrong for all.

alter table stg_dim_accounts
modify signup_date datetime

alter table stg_dim_sales_reps
modify hire_date datetime

alter table stg_fact_ad_campaign_spend
modify spend_date datetime

alter table stg_fact_crm_leads_opportunities
modify created_at datetime,
modify mql_date datetime,
modify sql_date datetime,
modify opportunity_date datetime,
modify closed_date datetime

alter table stg_fact_subscription_billing
modify start_date datetime,
modify end_date datetime,
modify churn_date datetime

alter table stg_fact_subscription_churn_cancellations
modify cancellation_date datetime

alter table stg_fact_user_sessions
modify session_start datetime

alter table stg_fact_web_app_events
modify event_timestamp datetime





-- Testing Turning first characters into lower case and others into upper case

start transaction

update stg_dim_utm_channel_mapping
set marketing_channel = 
concat(
	lower(left(substring_index(marketing_channel, ' ', 1), 1)),
	upper(substring(substring_index(marketing_channel, ' ', 1), 2)),
	' ',
    lower(left(substring_index(substring_index(marketing_channel, ' ', 2), ' ', -1), 1)),
    upper(substring(substring_index(substring_index(marketing_channel, ' ', 2), ' ', -1), 2))
)

select marketing_channel
from stg_dim_utm_channel_mapping;

rollback;

commit;



select CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
from information_schema.key_column_usage
where constraint_schema = 'saas_analytics_staging'


























