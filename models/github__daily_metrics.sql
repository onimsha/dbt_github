with github_issues as (
    select *
    from {{ ref('github__issues') }}
), 

pull_requests as (
    select *
    from {{ ref('github__pull_requests') }}
), 

issues_opened_per_day as (
   select 
      {{ dbt.date_trunc('day', 'created_at') }} as day, 
      count(*) as number_issues_opened,
      sum(days_issue_open) as sum_days_issue_open,
      max(days_issue_open) as longest_days_issue_open,
      repository as repository
    from github_issues
    group by 
      1,
      repository
), 

issues_closed_per_day as (
   select 
      {{ dbt.date_trunc('day', 'closed_at') }} as day, 
      count(*) as number_issues_closed,
      repository as repository
    from github_issues
    where closed_at is not null
    group by 
      1,
      repository
), 

prs_opened_per_day as (
   select 
      {{ dbt.date_trunc('day', 'created_at') }} as day, 
      count(*) as number_prs_opened,
      sum(days_issue_open) as sum_days_pr_open,
      max(days_issue_open) as longest_days_pr_open,
      repository as repository
    from pull_requests
    group by 
      1,
      repository
), 

prs_merged_per_day as (
   select 
      {{ dbt.date_trunc('day', 'merged_at') }} as day, 
      count(*) as number_prs_merged,
      repository as repository
    from pull_requests
    where merged_at is not null
    group by
      1,
      repository
), 

prs_closed_without_merge_per_day as (
   select 
      {{ dbt.date_trunc('day', 'closed_at') }} as day, 
      count(*) as number_prs_closed_without_merge,
      repository as repository
    from pull_requests
    where closed_at is not null
      and merged_at is null
    group by
      1,
      repository
), 

issues_per_day as (
    select 
      coalesce(issues_opened_per_day.day, 
        issues_closed_per_day.day
      ) as day,
      coalesce(issues_opened_per_day.repository, 
        issues_closed_per_day.repository
      ) as repository,
      number_issues_opened,
      number_issues_closed,      
      sum_days_issue_open,
      longest_days_issue_open
    from issues_opened_per_day
    full outer join issues_closed_per_day
    on 
      issues_opened_per_day.day = issues_closed_per_day.day
      and issues_opened_per_day.repository = issues_closed_per_day.repository
), 

prs_per_day as (
    select 
      coalesce(prs_opened_per_day.day, 
        prs_merged_per_day.day,
        prs_closed_without_merge_per_day.day
      ) as day,
      coalesce(prs_opened_per_day.repository, 
        prs_merged_per_day.repository,
        prs_closed_without_merge_per_day.repository
      ) as repository,
      number_prs_opened,
      number_prs_merged,
      number_prs_closed_without_merge,
      sum_days_pr_open,
      longest_days_pr_open
    from prs_opened_per_day
    full outer join prs_merged_per_day 
    on
      prs_opened_per_day.day = prs_merged_per_day.day
      AND prs_opened_per_day.repository = prs_merged_per_day.repository
    full outer join prs_closed_without_merge_per_day 
    on
      coalesce(prs_opened_per_day.day, prs_merged_per_day.day) = prs_closed_without_merge_per_day.day
      AND coalesce(prs_opened_per_day.repository, prs_merged_per_day.repository) = prs_closed_without_merge_per_day.repository
)

select 
  coalesce(issues_per_day.day, prs_per_day.day) as day,
  coalesce(issues_per_day.repository, prs_per_day.repository) as repository,
  coalesce(number_issues_opened, 0) as number_issues_opened,
  coalesce(number_issues_closed, 0) as number_issues_closed,
  sum_days_issue_open,
  longest_days_issue_open,
  coalesce(number_prs_opened, 0) as number_prs_opened,
  coalesce(number_prs_merged, 0) as number_prs_merged,
  coalesce(number_prs_closed_without_merge, 0) as number_prs_closed_without_merge,
  sum_days_pr_open,
  longest_days_pr_open
from issues_per_day 
full outer join prs_per_day 
on
  issues_per_day.day = prs_per_day.day
  AND issues_per_day.repository = prs_per_day.repository
order by day desc
