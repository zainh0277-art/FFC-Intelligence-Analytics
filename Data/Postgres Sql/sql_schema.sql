CREATE TABLE IF NOT EXISTS ffc_annual_financials (
    fiscal_year INT PRIMARY KEY,
    sales_pkr_thousands BIGINT,
    profit_after_tax_pkr_thousands BIGINT,
    eps_pkr NUMERIC(12,2),
    gross_profit_margin_pct NUMERIC(8,2),
    net_profit_margin_pct NUMERIC(8,2),
    basis TEXT,
    source_url TEXT,
    sales_pkr_billions NUMERIC(15,4),
    profit_pkr_billions NUMERIC(15,4),
    calculated_net_margin_pct NUMERIC(8,2)
);

CREATE TABLE IF NOT EXISTS ffc_quarterly_financials (
    period VARCHAR(10) PRIMARY KEY,
    sales_pkr_thousands BIGINT,
    profit_after_tax_pkr_thousands BIGINT,
    eps_pkr NUMERIC(12,2),
    basis TEXT,
    source_url TEXT,
    sales_pkr_billions NUMERIC(15,4),
    profit_pkr_billions NUMERIC(15,4)
);

CREATE TABLE IF NOT EXISTS ffc_operations (
    year INT,
    product VARCHAR(30),
    entity VARCHAR(30),
    metric VARCHAR(50),
    value NUMERIC(15,2),
    unit VARCHAR(20),
    source TEXT,
    source_url TEXT,
    tonnes NUMERIC(18,2),
    PRIMARY KEY (year, product, entity, metric)
);

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

SELECT *
FROM ffc_annual_financials
ORDER BY fiscal_year;

SELECT COUNT(*) AS total_records
FROM ffc_annual_financials;

SELECT 'Annual Financials' AS dataset, COUNT(*) AS total_rows
FROM ffc_annual_financials

UNION ALL

SELECT 'Quarterly Financials', COUNT(*)
FROM ffc_quarterly_financials

UNION ALL

SELECT 'Fertilizer Operations', COUNT(*)
FROM ffc_operations;

CREATE OR REPLACE VIEW vw_ffc_financial_performance AS
WITH annual_base AS (
    SELECT
        fiscal_year,
        sales_pkr_thousands / 1000000.0 AS revenue_bn,
        profit_after_tax_pkr_thousands / 1000000.0 AS profit_bn,
        eps_pkr,
        basis,
        source_url
    FROM ffc_annual_financials
),
growth_calculation AS (
    SELECT
        *,
        LAG(revenue_bn) OVER (
            ORDER BY fiscal_year
        ) AS previous_year_revenue,

        LAG(profit_bn) OVER (
            ORDER BY fiscal_year
        ) AS previous_year_profit,

        LAG(fiscal_year) OVER (
            ORDER BY fiscal_year
        ) AS previous_fiscal_year
    FROM annual_base
)
SELECT
    fiscal_year,

    ROUND(revenue_bn, 2) AS revenue_bn,
    ROUND(profit_bn, 2) AS profit_bn,

    ROUND(
        profit_bn * 100.0 / NULLIF(revenue_bn, 0),
        2
    ) AS net_profit_margin_pct,

    CASE
        WHEN fiscal_year = previous_fiscal_year + 1
        THEN ROUND(
            (revenue_bn - previous_year_revenue)
            * 100.0 / NULLIF(previous_year_revenue, 0),
            2
        )
        ELSE NULL
    END AS revenue_yoy_pct,

    CASE
        WHEN fiscal_year = previous_fiscal_year + 1
        THEN ROUND(
            (profit_bn - previous_year_profit)
            * 100.0 / NULLIF(previous_year_profit, 0),
            2
        )
        ELSE NULL
    END AS profit_yoy_pct,

    eps_pkr,
    basis,
    source_url

FROM growth_calculation;

SELECT
    fiscal_year,
    revenue_bn,
    profit_bn,
    net_profit_margin_pct,
    revenue_yoy_pct,
    profit_yoy_pct,
    eps_pkr
FROM vw_ffc_financial_performance
ORDER BY fiscal_year;

SELECT
    year,
    product,
    entity,
    metric,
    value,
    unit
FROM ffc_operations
ORDER BY year, product, entity, metric;

CREATE OR REPLACE VIEW vw_ffc_operations_analytics AS

WITH operations_base AS (
    SELECT
        year,
        product,
        entity,
        metric,
        value,
        unit,
        source_url,

        LAG(value) OVER (
            PARTITION BY product, entity, metric, unit
            ORDER BY year
        ) AS previous_value,

        LAG(year) OVER (
            PARTITION BY product, entity, metric, unit
            ORDER BY year
        ) AS previous_year

    FROM ffc_operations
)

SELECT
    year,
    product,
    entity,
    metric,
    value,
    unit,
    previous_value,

    CASE
        WHEN year = previous_year + 1
             AND previous_value <> 0
        THEN ROUND(
            (value - previous_value)
            * 100.0 / previous_value,
            2
        )
        ELSE NULL
    END AS yoy_change_pct,

    source_url

FROM operations_base;

CREATE OR REPLACE VIEW vw_ffc_market_share AS

WITH share_base AS (
    SELECT
        year,
        product,
        entity,
        metric,
        value AS market_share_pct,
        unit,
        source_url,

        LAG(value) OVER (
            PARTITION BY product, entity, metric, unit
            ORDER BY year
        ) AS previous_share_pct,

        LAG(year) OVER (
            PARTITION BY product, entity, metric, unit
            ORDER BY year
        ) AS previous_year

    FROM ffc_operations
    WHERE LOWER(metric) LIKE '%market%share%'
)

SELECT
    year,
    product,
    entity,
    metric,
    market_share_pct,
    unit,

    CASE
        WHEN year = previous_year + 1
        THEN ROUND(
            market_share_pct - previous_share_pct,
            2
        )
        ELSE NULL
    END AS share_change_pp,

    source_url

FROM share_base;

SELECT *
FROM vw_ffc_operations_analytics
ORDER BY year, product, metric;

SELECT *
FROM vw_ffc_market_share
ORDER BY year, product;

SELECT 'Operations Analytics' AS view_name,
       COUNT(*) AS total_rows
FROM vw_ffc_operations_analytics

UNION ALL

SELECT 'Market Share Analytics',
       COUNT(*)
FROM vw_ffc_market_share;


SELECT DISTINCT
    product,
    entity,
    metric,
    unit
FROM ffc_operations
ORDER BY product, entity, metric;

SELECT *
FROM ffc_operations
WHERE LOWER(metric) LIKE '%share%';

CREATE OR REPLACE VIEW vw_ffc_market_share AS
WITH share_base AS (
    SELECT
        year,
        product,
        entity,
        metric,
        value AS market_share_pct,
        unit,
        source_url,
        LAG(value) OVER (
            PARTITION BY product, entity, metric, unit
            ORDER BY year
        ) AS previous_share_pct,
        LAG(year) OVER (
            PARTITION BY product, entity, metric, unit
            ORDER BY year
        ) AS previous_year
    FROM ffc_operations
    WHERE LOWER(metric) LIKE '%share%'
)
SELECT
    year,
    product,
    entity,
    metric,
    market_share_pct,
    unit,
    CASE
        WHEN year = previous_year + 1
        THEN ROUND(market_share_pct - previous_share_pct, 2)
        ELSE NULL
    END AS share_change_pp,
    source_url
FROM share_base;

SELECT *
FROM vw_ffc_market_share
ORDER BY year, product;

CREATE OR REPLACE VIEW vw_ffc_quarterly_performance AS
SELECT
    period,
    ROUND(
        sales_pkr_thousands / 1000000.0,
        2
    ) AS revenue_bn,
    ROUND(
        profit_after_tax_pkr_thousands / 1000000.0,
        2
    ) AS profit_bn,
    ROUND(
        profit_after_tax_pkr_thousands * 100.0
        / NULLIF(sales_pkr_thousands, 0),
        2
    ) AS net_profit_margin_pct,
    eps_pkr,
    basis,
    source_url
FROM ffc_quarterly_financials;

SELECT *
FROM vw_ffc_quarterly_performance
ORDER BY period;

SELECT
    year,
    product,
    entity,
    metric,
    value,
    unit
FROM ffc_operations
WHERE LOWER(metric) LIKE '%share%';

SELECT DISTINCT metric
FROM ffc_operations
ORDER BY metric;

CREATE OR REPLACE VIEW vw_ffc_market_share AS
WITH share_base AS (
    SELECT
        year,
        product,
        entity,
        metric,
        value AS market_share_pct,
        unit,
        source_url,

        LAG(value) OVER (
            PARTITION BY product, entity, metric, unit
            ORDER BY year
        ) AS previous_share_pct,

        LAG(year) OVER (
            PARTITION BY product, entity, metric, unit
            ORDER BY year
        ) AS previous_year

    FROM ffc_operations
    WHERE LOWER(metric) LIKE '%share%'
)
SELECT
    year,
    product,
    entity,
    metric,
    market_share_pct,
    unit,

    CASE
        WHEN year = previous_year + 1
        THEN ROUND(
            market_share_pct - previous_share_pct, 2
        )
        ELSE NULL
    END AS share_change_pp,

    source_url
FROM share_base;

SELECT COUNT(*) AS market_share_rows
FROM vw_ffc_market_share;

SELECT
    year,
    product,
    entity,
    metric,
    value,
    unit
FROM ffc_operations
WHERE metric = 'offtake'
ORDER BY year, product, entity;


CREATE OR REPLACE VIEW vw_ffc_quarterly_performance AS
SELECT
    period,
    ROUND(sales_pkr_thousands / 1000000.0, 2)
        AS revenue_bn,
    ROUND(profit_after_tax_pkr_thousands / 1000000.0, 2)
        AS profit_bn,
    ROUND(
        profit_after_tax_pkr_thousands * 100.0
        / NULLIF(sales_pkr_thousands, 0), 2
    ) AS net_profit_margin_pct,
    eps_pkr,
    basis,
    source_url
FROM ffc_quarterly_financials;

SELECT COUNT(*)
FROM vw_ffc_quarterly_performance;

SELECT
    year,
    product,
    entity,
    value,
    unit
FROM ffc_operations
WHERE metric = 'offtake'
ORDER BY year, product, entity;

DROP VIEW IF EXISTS vw_ffc_market_share;

CREATE VIEW vw_ffc_market_share AS
WITH offtake_data AS (
    SELECT
        year,
        product,
        MAX(CASE WHEN entity = 'FFC'
            THEN value END) AS ffc_offtake_kt,
        MAX(CASE WHEN entity = 'Industry'
            THEN value END) AS industry_offtake_kt
    FROM ffc_operations
    WHERE metric = 'offtake'
      AND unit = 'KT'
    GROUP BY year, product
),
market_share AS (
    SELECT
        year,
        product,
        ffc_offtake_kt,
        industry_offtake_kt,
        ROUND(
            ffc_offtake_kt * 100.0 /
            NULLIF(industry_offtake_kt, 0), 2
        ) AS market_share_pct
    FROM offtake_data
)
SELECT
    year,
    product,
    ffc_offtake_kt,
    industry_offtake_kt,
    market_share_pct,
    ROUND(
        market_share_pct -
        LAG(market_share_pct) OVER (
            PARTITION BY product
            ORDER BY year
        ), 2
    ) AS share_change_pp
FROM market_share;

SELECT *
FROM vw_ffc_market_share
ORDER BY product, year;

SELECT COUNT(*) AS quarterly_rows
FROM vw_ffc_quarterly_performance;

SELECT
    current_database() AS database_name,
    inet_server_port() AS server_port,
    current_user AS username;

SELECT current_database(), inet_server_port();

