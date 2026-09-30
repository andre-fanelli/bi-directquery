-- ==============================================================================
-- 04_create_views.sql
-- Analytical Views & Aggregation Tables for Power BI Composite Models
-- ==============================================================================

SET search_path TO dw, public;

-- ------------------------------------------------------------------------------
-- 1. Aggregation Table: agg_sales_monthly
-- Used in Power BI to demonstrate User-Defined Aggregations (Composite Models)
-- Mode: Import in Power BI, mapped to DirectQuery dw.fact_sales
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS dw.agg_sales_monthly CASCADE;

CREATE TABLE dw.agg_sales_monthly AS
SELECT
    d.year_month,
    d.year,
    d.month,
    p.category,
    s.region,
    c.channel_name,
    COUNT(DISTINCT f.order_id)           AS total_orders,
    SUM(f.quantity)                      AS total_quantity,
    ROUND(SUM(f.gross_sales_amount), 2)  AS total_gross_sales,
    ROUND(SUM(f.discount_amount), 2)     AS total_discount,
    ROUND(SUM(f.net_sales_amount), 2)    AS total_net_sales,
    ROUND(SUM(f.total_cost_amount), 2)   AS total_cost,
    ROUND(SUM(f.margin_amount), 2)       AS total_margin,
    ROUND(SUM(f.tax_amount), 2)          AS total_tax
FROM dw.fact_sales f
JOIN dw.dim_date d     ON d.date_key = f.order_date_key
JOIN dw.dim_product p  ON p.product_key = f.product_key
JOIN dw.dim_store s    ON s.store_key = f.store_key
JOIN dw.dim_channel c  ON c.channel_key = f.channel_key
WHERE f.order_status <> 'Cancelado'
GROUP BY
    d.year_month,
    d.year,
    d.month,
    p.category,
    s.region,
    c.channel_name;

-- Indexes for the aggregation table
CREATE INDEX idx_agg_sales_ym_cat_reg ON dw.agg_sales_monthly (year_month, category, region);

-- ------------------------------------------------------------------------------
-- 2. View: vw_actual_vs_target
-- Pre-joined view for Target vs Actual comparison at Monthly/Category/Region grain
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW dw.vw_actual_vs_target AS
WITH actuals AS (
    SELECT
        d.year_month,
        p.category,
        s.region,
        ROUND(SUM(f.net_sales_amount), 2) AS actual_sales_amount,
        COUNT(DISTINCT f.order_id)        AS actual_orders_count,
        SUM(f.quantity)                   AS actual_quantity_sold
    FROM dw.fact_sales f
    JOIN dw.dim_date d    ON d.date_key = f.order_date_key
    JOIN dw.dim_product p ON p.product_key = f.product_key
    JOIN dw.dim_store s   ON s.store_key = f.store_key
    WHERE f.order_status <> 'Cancelado'
    GROUP BY d.year_month, p.category, s.region
)
SELECT
    COALESCE(a.year_month, t.year_month) AS year_month,
    COALESCE(a.category, t.category)     AS category,
    COALESCE(a.region, t.region)         AS region,
    COALESCE(a.actual_sales_amount, 0)   AS actual_sales_amount,
    COALESCE(t.target_sales_amount, 0)   AS target_sales_amount,
    ROUND(COALESCE(a.actual_sales_amount, 0) - COALESCE(t.target_sales_amount, 0), 2) AS variance_amount,
    ROUND(
        CASE 
            WHEN COALESCE(t.target_sales_amount, 0) > 0 
            THEN (COALESCE(a.actual_sales_amount, 0) / t.target_sales_amount) * 100.00
            ELSE 0 
        END, 
        2
    ) AS target_achievement_pct
FROM actuals a
FULL OUTER JOIN dw.fact_sales_target t
    ON a.year_month = t.year_month
   AND a.category = t.category
   AND a.region = t.region;

-- ------------------------------------------------------------------------------
-- 3. View: vw_live_recent_sales
-- Real-time audit view for monitoring live sales in Power BI DirectQuery
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW dw.vw_live_recent_sales AS
SELECT
    f.sales_key,
    f.order_id,
    f.created_at,
    to_char(f.created_at AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI:SS') AS order_time,
    d.full_date AS order_date,
    c.full_name AS customer_name,
    c.city || ' - ' || c.state AS customer_location,
    p.product_name,
    p.category AS product_category,
    s.store_name,
    s.region AS store_region,
    ch.channel_name,
    f.quantity,
    f.unit_price,
    f.discount_amount,
    f.net_sales_amount,
    f.margin_amount,
    f.order_status
FROM dw.fact_sales f
JOIN dw.dim_date d     ON d.date_key = f.order_date_key
JOIN dw.dim_customer c ON c.customer_key = f.customer_key
JOIN dw.dim_product p  ON p.product_key = f.product_key
JOIN dw.dim_store s    ON s.store_key = f.store_key
JOIN dw.dim_channel ch ON ch.channel_key = f.channel_key
ORDER BY f.created_at DESC
LIMIT 100;

