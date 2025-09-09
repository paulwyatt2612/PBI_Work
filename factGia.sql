WITH revenue_base AS (
    SELECT
        DATE(ap.starting)              AS revenue_date,
        MONTH(ap.starting)             AS revenue_month,
        YEAR(ap.starting)              AS revenue_year,
        t.source_country               AS source_country,
        t.currency_id                  AS currency_id,
        d.business_group_name          AS business_group,
        d.business_unit_name           AS business_unit,
        d.name                         AS department,
        s.name                         AS subsidiary,
        l.location_id                  AS location_id,
        l.name                         AS location,
        c.customer_id                  AS customer_id,
        c.name                         AS customer_name,
        p.project_code                 AS project_code,
        e1.full_name                   AS project_manager,
        e1.employee_id                 AS project_manager_id,
        e2.full_name                   AS fee_earner,
        t.transaction_id               AS transaction_id,
        t.transaction_number           AS transaction_number,
        t.tranid                       AS legacy_tranid,
        t.transaction_type             AS transaction_type,
        t.transaction_date             AS transaction_date,
        tl.line_memo,
        t.memo,
        tl.line_amount * -1            AS amount,
        tl.line_amount_foreign * -1    AS amount_foreign,
        a.accountnumber                AS account_number,
        a.name                         AS account_name,
        a.isinactive                   AS account_inactive,
        ap.closed                      AS accounting_period_closed,
        CASE
            WHEN a.accountnumber ILIKE ('41%') 
              OR a.accountnumber ILIKE ('42%')
              OR a.accountnumber ILIKE ('43%')
              OR a.accountnumber ILIKE ('44%')
              OR a.accountnumber ILIKE ('45%')
              OR (a.accountnumber ILIKE ('46%') AND a.accountnumber <> '46950-000')
            THEN '1. Fee Income'

            WHEN a.accountnumber ILIKE ('47%')
              OR a.accountnumber ILIKE ('57%')
              OR a.accountnumber = '46950-000'
            THEN '2. Net Recharges'

            WHEN a.accountnumber ILIKE ('56100%')
              OR a.accountnumber ILIKE ('56300%')
              OR a.accountnumber ILIKE ('53200%')
            THEN '3. SubAgent Costs'

            ELSE NULL
        END AS account_group
    -- JOINING --
    FROM DM_FINANCE_DEV.NETSUITE_REPORTING.TRANS_LINES             AS tl
    INNER JOIN DM_FINANCE_DEV.NETSUITE_REPORTING.TRANS_ALL         AS t
           ON tl.transaction_id = t.transaction_id
    LEFT JOIN DM_FINANCE_DEV.NETSUITE_REPORTING.DIM_SUBSIDIARIES   AS s
           ON tl.subsidiary_id = s.subsidiary_id
    LEFT JOIN DM_FINANCE_DEV.NETSUITE_REPORTING.DIM_DEPARTMENTS    AS d
           ON tl.department_id = d.department_id
    LEFT JOIN DM_FINANCE_DEV.NETSUITE_REPORTING.DIM_LOCATIONS      AS l
           ON tl.location_id = l.location_id
    JOIN      DM_FINANCE_DEV.NETSUITE_REPORTING.DIM_ACCOUNTS       AS a
           ON tl.account_id = a.account_id
    JOIN      DM_FINANCE_DEV.NETSUITE_REPORTING.DIM_ACCOUNTING_PERIODS AS ap
           ON t.accounting_period_id = ap.accounting_period_id
    LEFT JOIN DM_FINANCE_DEV.NETSUITE_REPORTING.TRANS_LINES        AS t2
           ON  t.created_from_transaction_id = t2.transaction_id
           AND t2.line_project_id IS NOT NULL
           AND t.transaction_type = 'Item Receipt'
    LEFT JOIN DM_FINANCE_DEV.NETSUITE_REPORTING.DIM_PROJECTS       AS p
           ON COALESCE(t2.line_project_id, tl.line_project_id, t.project_id) = p.project_id
    LEFT JOIN DM_FINANCE_DEV.NETSUITE_REPORTING.DIM_CUSTOMERS      AS c
           ON p.customer_id = c.customer_id
    LEFT JOIN DM_FINANCE_DEV.NETSUITE_REPORTING.DIM_EMPLOYEES      AS e1
           ON p.project_manager_employee_id = e1.employee_id
    LEFT JOIN DM_FINANCE_DEV.NETSUITE_REPORTING.DIM_EMPLOYEES      AS e2
           ON p.fee_earner_employee_id = e2.employee_id
)
-- COMPILED QUERY --
SELECT *
FROM revenue_base
WHERE account_group IS NOT NULL
  AND revenue_year >= 2025
  AND accounting_period_closed = 'Yes'
  AND department ILIKE 'UK%'
  AND account_inactive = 'No'
GROUP BY ALL
ORDER BY revenue_date, revenue_year, source_country, currency_id,
         business_group, business_unit, department, subsidiary, location
LIMIT 5;

