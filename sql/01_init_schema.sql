-- ==============================================================================
-- 01_init_schema.sql
-- Star Schema Data Warehouse DDL for Power BI DirectQuery
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS dw;

-- Set search_path so queries can reference dw tables directly or with dw prefix
SET search_path TO dw, public;

-- Drop existing tables if recreating
DROP TABLE IF EXISTS dw.fact_sales_target CASCADE;
DROP TABLE IF EXISTS dw.fact_sales CASCADE;
DROP TABLE IF EXISTS dw.dim_promotion CASCADE;
DROP TABLE IF EXISTS dw.dim_channel CASCADE;
DROP TABLE IF EXISTS dw.dim_store CASCADE;
DROP TABLE IF EXISTS dw.dim_product CASCADE;
DROP TABLE IF EXISTS dw.dim_customer CASCADE;
DROP TABLE IF EXISTS dw.dim_date CASCADE;

-- ------------------------------------------------------------------------------
-- Dimension: Date (dim_date)
-- Fundamental for DirectQuery Time Intelligence (Auto Date/Time is disabled in DQ)
-- ------------------------------------------------------------------------------
CREATE TABLE dw.dim_date (
    date_key            INT PRIMARY KEY,              -- Format: YYYYMMDD (e.g., 20240115)
    full_date           DATE NOT NULL UNIQUE,
    year                SMALLINT NOT NULL,            -- e.g. 2024
    quarter             SMALLINT NOT NULL,            -- 1, 2, 3, 4
    quarter_name        VARCHAR(10) NOT NULL,         -- 'Q1', 'Q2', 'Q3', 'Q4'
    month               SMALLINT NOT NULL,            -- 1 to 12
    month_name          VARCHAR(20) NOT NULL,         -- 'Janeiro', 'Fevereiro', ...
    month_short_name    VARCHAR(3) NOT NULL,          -- 'Jan', 'Fev', ...
    year_month          INT NOT NULL,                 -- YYYYMM (e.g. 202401)
    year_month_name     VARCHAR(10) NOT NULL,         -- '2024-01'
    day_of_month        SMALLINT NOT NULL,            -- 1 to 31
    day_of_week         SMALLINT NOT NULL,            -- 1 (Dom) to 7 (Sab)
    day_name            VARCHAR(20) NOT NULL,         -- 'Domingo', 'Segunda-feira', ...
    day_short_name      VARCHAR(3) NOT NULL,          -- 'Dom', 'Seg', ...
    is_weekend          BOOLEAN NOT NULL,
    fiscal_year         SMALLINT NOT NULL,            -- July-June fiscal year or Jan-Dec
    fiscal_quarter      VARCHAR(10) NOT NULL,
    week_of_year        SMALLINT NOT NULL
);

-- ------------------------------------------------------------------------------
-- Dimension: Customer (dim_customer)
-- Conformed dimension with demographic and geographical attributes
-- ------------------------------------------------------------------------------
CREATE TABLE dw.dim_customer (
    customer_key        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id         VARCHAR(20) NOT NULL UNIQUE,
    first_name          VARCHAR(50) NOT NULL,
    last_name           VARCHAR(50) NOT NULL,
    full_name           VARCHAR(100) NOT NULL,
    gender              VARCHAR(1) NOT NULL,          -- 'M', 'F'
    birth_date          DATE NOT NULL,
    age                 SMALLINT NOT NULL,
    age_group           VARCHAR(20) NOT NULL,         -- '18-25', '26-35', '36-50', '51+'
    email               VARCHAR(100) NOT NULL,
    phone               VARCHAR(30),
    city                VARCHAR(50) NOT NULL,
    state               VARCHAR(2) NOT NULL,          -- SP, RJ, MG, RS, PR, etc.
    region              VARCHAR(20) NOT NULL,         -- Sudeste, Sul, Nordeste, Centro-Oeste, Norte
    country             VARCHAR(30) NOT NULL DEFAULT 'Brasil',
    customer_segment    VARCHAR(30) NOT NULL          -- 'Varejo', 'Corporativo', 'Pequenas Empresas'
);

-- ------------------------------------------------------------------------------
-- Dimension: Product (dim_product)
-- Flattened Star Schema dimension (Category and Subcategory denormalized into Product)
-- ------------------------------------------------------------------------------
CREATE TABLE dw.dim_product (
    product_key         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id          VARCHAR(20) NOT NULL UNIQUE,
    sku                 VARCHAR(30) NOT NULL UNIQUE,
    product_name        VARCHAR(120) NOT NULL,
    category            VARCHAR(50) NOT NULL,
    subcategory         VARCHAR(50) NOT NULL,
    brand               VARCHAR(50) NOT NULL,
    unit_cost           NUMERIC(12, 2) NOT NULL,
    list_price          NUMERIC(12, 2) NOT NULL,
    product_status      VARCHAR(20) NOT NULL DEFAULT 'Ativo'
);

-- ------------------------------------------------------------------------------
-- Dimension: Store / Territory (dim_store)
-- Physical & distribution network
-- ------------------------------------------------------------------------------
CREATE TABLE dw.dim_store (
    store_key           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id            VARCHAR(20) NOT NULL UNIQUE,
    store_name          VARCHAR(100) NOT NULL,
    store_type          VARCHAR(30) NOT NULL,         -- 'Loja Física', 'Flagship', 'Outlet', 'Centro de Distribuição'
    city                VARCHAR(50) NOT NULL,
    state               VARCHAR(2) NOT NULL,
    region              VARCHAR(20) NOT NULL,
    store_size_m2       INT,
    manager_name        VARCHAR(100),
    open_date           DATE NOT NULL
);

-- ------------------------------------------------------------------------------
-- Dimension: Sales Channel (dim_channel)
-- Omnichannel sales points
-- ------------------------------------------------------------------------------
CREATE TABLE dw.dim_channel (
    channel_key         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    channel_id          VARCHAR(20) NOT NULL UNIQUE,
    channel_name        VARCHAR(50) NOT NULL,         -- 'E-commerce Web', 'Aplicativo Mobile', 'Loja Física', 'Marketplace B2B'
    channel_category    VARCHAR(30) NOT NULL          -- 'Digital', 'Físico', 'Parceiros'
);

-- ------------------------------------------------------------------------------
-- Dimension: Promotion (dim_promotion)
-- Promotional campaigns and discounts
-- ------------------------------------------------------------------------------
CREATE TABLE dw.dim_promotion (
    promotion_key       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    promotion_id        VARCHAR(20) NOT NULL UNIQUE,
    promotion_name      VARCHAR(100) NOT NULL,
    discount_pct        NUMERIC(5, 2) NOT NULL DEFAULT 0.00
);

-- ------------------------------------------------------------------------------
-- Fact: Sales Transactions (fact_sales)
-- Fine-grained transaction line items (Grain: 1 row per order line)
-- Role-playing Date Dimension: order_date_key (Active) and ship_date_key (Inactive)
-- ------------------------------------------------------------------------------
CREATE TABLE dw.fact_sales (
    sales_key           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id            VARCHAR(30) NOT NULL,
    order_line          INT NOT NULL,
    order_date_key      INT NOT NULL REFERENCES dw.dim_date(date_key),
    ship_date_key       INT NOT NULL REFERENCES dw.dim_date(date_key),
    customer_key        INT NOT NULL REFERENCES dw.dim_customer(customer_key),
    product_key         INT NOT NULL REFERENCES dw.dim_product(product_key),
    store_key           INT NOT NULL REFERENCES dw.dim_store(store_key),
    channel_key         INT NOT NULL REFERENCES dw.dim_channel(channel_key),
    promotion_key       INT NOT NULL REFERENCES dw.dim_promotion(promotion_key),
    order_status        VARCHAR(20) NOT NULL,         -- 'Entregue', 'Enviado', 'Processando', 'Cancelado'
    quantity            INT NOT NULL,
    unit_cost           NUMERIC(12, 2) NOT NULL,
    unit_price          NUMERIC(12, 2) NOT NULL,
    discount_amount     NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gross_sales_amount  NUMERIC(12, 2) NOT NULL,
    net_sales_amount    NUMERIC(12, 2) NOT NULL,
    total_cost_amount   NUMERIC(12, 2) NOT NULL,
    margin_amount       NUMERIC(12, 2) NOT NULL,
    tax_amount          NUMERIC(12, 2) NOT NULL
);

-- ------------------------------------------------------------------------------
-- Fact: Sales Targets (fact_sales_target)
-- Monthly Sales Target by Category & Region (Grain: Month + Category + Region)
-- Demonstrates handling different granularities in Power BI (classic PL-300 topic)
-- ------------------------------------------------------------------------------
CREATE TABLE dw.fact_sales_target (
    target_key          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    year_month          INT NOT NULL,                 -- YYYYMM (e.g. 202401)
    target_date_key     INT NOT NULL REFERENCES dw.dim_date(date_key), -- 1st day of month
    category            VARCHAR(50) NOT NULL,
    region              VARCHAR(20) NOT NULL,
    target_sales_amount NUMERIC(14, 2) NOT NULL
);

-- ==============================================================================
-- B-TREE Indexes for DirectQuery Performance
-- DirectQuery sends SQL JOINs and GROUP BY queries on every user interaction!
-- Without indexes on Foreign Keys, PostgreSQL falls back to sequential scans.
-- ==============================================================================

-- Fact Sales Foreign Key & Filter Indexes
CREATE INDEX idx_fact_sales_order_date  ON dw.fact_sales (order_date_key);
CREATE INDEX idx_fact_sales_ship_date   ON dw.fact_sales (ship_date_key);
CREATE INDEX idx_fact_sales_customer    ON dw.fact_sales (customer_key);
CREATE INDEX idx_fact_sales_product     ON dw.fact_sales (product_key);
CREATE INDEX idx_fact_sales_store       ON dw.fact_sales (store_key);
CREATE INDEX idx_fact_sales_channel     ON dw.fact_sales (channel_key);
CREATE INDEX idx_fact_sales_promotion   ON dw.fact_sales (promotion_key);
CREATE INDEX idx_fact_sales_status      ON dw.fact_sales (order_status);

-- Composite Index for Common Time-Series Aggregations
CREATE INDEX idx_fact_sales_date_prod   ON dw.fact_sales (order_date_key, product_key);
CREATE INDEX idx_fact_sales_date_store  ON dw.fact_sales (order_date_key, store_key);

-- Fact Target Indexes
CREATE INDEX idx_fact_target_date       ON dw.fact_sales_target (target_date_key);
CREATE INDEX idx_fact_target_cat_reg    ON dw.fact_sales_target (category, region);

-- Dimension Lookup Indexes
CREATE INDEX idx_dim_customer_region    ON dw.dim_customer (region, state);
CREATE INDEX idx_dim_customer_segment   ON dw.dim_customer (customer_segment);
CREATE INDEX idx_dim_product_category   ON dw.dim_product (category, subcategory);
CREATE INDEX idx_dim_store_region       ON dw.dim_store (region, state);
CREATE INDEX idx_dim_date_year_month    ON dw.dim_date (year_month);
