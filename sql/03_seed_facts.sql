-- ==============================================================================
-- 03_seed_facts.sql
-- Seed Fact Tables with Realistic High Volume for DirectQuery Performance
-- ==============================================================================

SET search_path TO dw, public;

-- ------------------------------------------------------------------------------
-- 1. Seed fact_sales (~350,000 transactions)
-- Optimized with CTE and set-returning functions for fast bulk generation (< 15s)
-- ------------------------------------------------------------------------------
INSERT INTO dw.fact_sales (
    order_id,
    order_line,
    order_date_key,
    ship_date_key,
    customer_key,
    product_key,
    store_key,
    channel_key,
    promotion_key,
    order_status,
    quantity,
    unit_cost,
    unit_price,
    discount_amount,
    gross_sales_amount,
    net_sales_amount,
    total_cost_amount,
    margin_amount,
    tax_amount
)
WITH raw_transactions AS (
    SELECT
        i,
        -- Generate orders across 2022 to 2025 (1460 days)
        -- Weight later years and Q4 months heavier to simulate realistic company growth and seasonal peak
        ('2022-01-01'::date + (
            CASE 
                -- 25% of orders concentrated in Q4 (Nov/Dec)
                WHEN (i % 4 = 0) THEN 
                    ((i % 4) * 365 + 300 + (i % 60))::int
                ELSE 
                    ((i * 7) % 1450)::int
            END
        ) * '1 day'::interval)::date AS order_date,
        -- Ship date 1 to 5 days after order date
        (1 + (i % 5)) AS shipping_days,
        -- Keys
        ((i * 17) % 10000 + 1) AS customer_key,
        ((i * 31) % 500 + 1)   AS product_key,
        ((i * 7) % 30 + 1)     AS store_key,
        -- Channel distribution: 1=Web (40%), 2=App (30%), 3=Loja (20%), 4=B2B (10%)
        CASE 
            WHEN (i % 10) < 4 THEN 1
            WHEN (i % 10) < 7 THEN 2
            WHEN (i % 10) < 9 THEN 3
            ELSE 4
        END AS channel_key,
        -- Order line (1 to 3 items per order)
        ((i % 3) + 1) AS order_line,
        -- Order status
        CASE 
            WHEN (i % 100) < 2  THEN 'Cancelado'
            WHEN (i % 100) < 5  THEN 'Processando'
            WHEN (i % 100) < 12 THEN 'Enviado'
            ELSE 'Entregue'
        END AS order_status,
        -- Quantity (mostly 1-3, but larger quantities for B2B channel)
        CASE 
            WHEN (i % 10 = 9) THEN (5 + (i % 15)) -- B2B
            ELSE (1 + (i % 3))
        END AS quantity
    FROM generate_series(1, 350000) AS i
),
enriched_transactions AS (
    SELECT
        t.i,
        'ORD-' || to_char(t.order_date, 'YYYY') || '-' || lpad((t.i / 2 + 1)::text, 7, '0') AS order_id,
        t.order_line,
        (to_char(t.order_date, 'YYYYMMDD'))::int AS order_date_key,
        (to_char((t.order_date + t.shipping_days * '1 day'::interval), 'YYYYMMDD'))::int AS ship_date_key,
        t.customer_key,
        t.product_key,
        t.store_key,
        t.channel_key,
        -- Promotion mapping: Black Friday in Nov, Summer Sale in Jan, etc.
        CASE 
            WHEN EXTRACT(MONTH FROM t.order_date) = 11 AND (t.i % 2 = 0) THEN 2 -- Black Friday
            WHEN EXTRACT(MONTH FROM t.order_date) = 1  AND (t.i % 3 = 0) THEN 3 -- Liquidação Verão
            WHEN (t.i % 15 = 0) THEN 4 -- Semana Tech
            WHEN (t.i % 20 = 0) THEN 5 -- VIP
            WHEN (t.i % 25 = 0) THEN 6 -- Boas-Vindas
            ELSE 1                     -- Preço Regular
        END AS promotion_key,
        t.order_status,
        t.quantity,
        p.unit_cost,
        p.list_price AS unit_price,
        pr.discount_pct
    FROM raw_transactions t
    JOIN dw.dim_product p ON p.product_key = t.product_key
    JOIN dw.dim_promotion pr ON pr.promotion_key = (
        CASE 
            WHEN EXTRACT(MONTH FROM t.order_date) = 11 AND (t.i % 2 = 0) THEN 2
            WHEN EXTRACT(MONTH FROM t.order_date) = 1  AND (t.i % 3 = 0) THEN 3
            WHEN (t.i % 15 = 0) THEN 4
            WHEN (t.i % 20 = 0) THEN 5
            WHEN (t.i % 25 = 0) THEN 6
            ELSE 1
        END
    )
)
SELECT
    order_id,
    order_line,
    order_date_key,
    ship_date_key,
    customer_key,
    product_key,
    store_key,
    channel_key,
    promotion_key,
    order_status,
    quantity,
    unit_cost,
    unit_price,
    ROUND(quantity * unit_price * discount_pct, 2) AS discount_amount,
    ROUND(quantity * unit_price, 2) AS gross_sales_amount,
    ROUND((quantity * unit_price) * (1.00 - discount_pct), 2) AS net_sales_amount,
    ROUND(quantity * unit_cost, 2) AS total_cost_amount,
    ROUND(((quantity * unit_price) * (1.00 - discount_pct)) - (quantity * unit_cost), 2) AS margin_amount,
    ROUND(((quantity * unit_price) * (1.00 - discount_pct)) * 0.12, 2) AS tax_amount
FROM enriched_transactions;

-- ------------------------------------------------------------------------------
-- 2. Seed fact_sales_target
-- Monthly targets by Category and Region (2022 to 2026)
-- ------------------------------------------------------------------------------
INSERT INTO dw.fact_sales_target (
    year_month,
    target_date_key,
    category,
    region,
    target_sales_amount
)
WITH months AS (
    SELECT DISTINCT
        year_month,
        (year_month * 100 + 1) AS target_date_key,
        year,
        month
    FROM dw.dim_date
),
categories AS (
    SELECT DISTINCT category FROM dw.dim_product
),
regions AS (
    SELECT DISTINCT region FROM dw.dim_store WHERE region <> 'Online'
)
SELECT
    m.year_month,
    m.target_date_key,
    c.category,
    r.region,
    ROUND(
        (
            -- Base target according to region
            CASE r.region
                WHEN 'Sudeste' THEN 450000.00
                WHEN 'Sul' THEN 280000.00
                WHEN 'Nordeste' THEN 220000.00
                WHEN 'Centro-Oeste' THEN 180000.00
                ELSE 120000.00
            END
            -- Category multiplier
            * CASE c.category
                WHEN 'Computadores & Notebooks' THEN 1.6
                WHEN 'Smartphones & Tablets' THEN 1.4
                WHEN 'Áudio & Vídeo' THEN 1.0
                WHEN 'Eletrodomésticos Inteligentes' THEN 1.1
                WHEN 'Periféricos & Acessórios' THEN 0.7
                ELSE 0.8
            END
            -- Seasonal multiplier (November / December peaks)
            * CASE m.month
                WHEN 11 THEN 1.8  -- Black Friday
                WHEN 12 THEN 2.1  -- Natal
                WHEN 1 THEN 1.2   -- Saldão Janeiro
                WHEN 2 THEN 0.85  -- Carnaval (mês curto)
                ELSE 1.0
            END
            -- YoY growth (8% per year)
            * POWER(1.08, (m.year - 2022))
        )::numeric,
        2
    ) AS target_sales_amount
FROM months m
CROSS JOIN categories c
CROSS JOIN regions r;
