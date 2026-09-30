-- ==============================================================================
-- 06_live_stream_generator.sql
-- Real-time Simulation Engine for Testing Power BI DirectQuery Live Updates
-- ==============================================================================

SET search_path TO dw, public;

CREATE OR REPLACE FUNCTION dw.fn_generate_live_sale(p_count INT DEFAULT 1)
RETURNS TABLE (
    o_order_id VARCHAR(30),
    o_customer_name VARCHAR(100),
    o_product_name VARCHAR(120),
    o_store_name VARCHAR(100),
    o_channel_name VARCHAR(50),
    o_quantity INT,
    o_net_sales NUMERIC(12, 2),
    o_margin NUMERIC(12, 2),
    o_created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
AS $func$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_date_key INT := (to_char(CURRENT_DATE, 'YYYYMMDD'))::int;
    v_i INT;
    v_rand_cust INT;
    v_rand_prod INT;
    v_rand_store INT;
    v_rand_chan INT;
    v_rand_qty INT;
    v_cost NUMERIC(12, 2);
    v_price NUMERIC(12, 2);
    v_disc_pct NUMERIC(5, 2) := 0.00;
    v_disc_amt NUMERIC(12, 2);
    v_gross NUMERIC(12, 2);
    v_net NUMERIC(12, 2);
    v_total_cost NUMERIC(12, 2);
    v_margin NUMERIC(12, 2);
    v_tax NUMERIC(12, 2);
    v_ord_id VARCHAR(30);
    v_cust_name VARCHAR(100);
    v_prod_name VARCHAR(120);
    v_st_name VARCHAR(100);
    v_ch_name VARCHAR(50);
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    FOR v_i IN 1..p_count LOOP
        v_now := clock_timestamp();
        v_rand_cust := floor(random() * 10000 + 1)::int;
        v_rand_prod := floor(random() * 500 + 1)::int;
        v_rand_store := floor(random() * 30 + 1)::int;
        v_rand_chan := floor(random() * 4 + 1)::int;
        v_rand_qty := floor(random() * 3 + 1)::int;

        SELECT full_name INTO v_cust_name FROM dw.dim_customer WHERE customer_key = v_rand_cust;
        SELECT product_name, unit_cost, list_price INTO v_prod_name, v_cost, v_price FROM dw.dim_product WHERE product_key = v_rand_prod;
        SELECT store_name INTO v_st_name FROM dw.dim_store WHERE store_key = v_rand_store;
        SELECT channel_name INTO v_ch_name FROM dw.dim_channel WHERE channel_key = v_rand_chan;

        IF random() < 0.25 THEN
            v_disc_pct := 0.10;
        ELSE
            v_disc_pct := 0.00;
        END IF;

        v_gross := ROUND(v_rand_qty * v_price, 2);
        v_disc_amt := ROUND(v_gross * v_disc_pct, 2);
        v_net := v_gross - v_disc_amt;
        v_total_cost := ROUND(v_rand_qty * v_cost, 2);
        v_margin := v_net - v_total_cost;
        v_tax := ROUND(v_net * 0.12, 2);

        v_ord_id := 'ORD-LIVE-' || to_char(v_now, 'YYYYMMDD') || '-' || lpad((floor(random() * 899999 + 100000))::text, 6, '0');

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
            tax_amount,
            created_at
        ) VALUES (
            v_ord_id,
            1,
            v_date_key,
            v_date_key,
            v_rand_cust,
            v_rand_prod,
            v_rand_store,
            v_rand_chan,
            1,
            'Entregue',
            v_rand_qty,
            v_cost,
            v_price,
            v_disc_amt,
            v_gross,
            v_net,
            v_total_cost,
            v_margin,
            v_tax,
            v_now
        );

        o_order_id := v_ord_id;
        o_customer_name := v_cust_name;
        o_product_name := v_prod_name;
        o_store_name := v_st_name;
        o_channel_name := v_ch_name;
        o_quantity := v_rand_qty;
        o_net_sales := v_net;
        o_margin := v_margin;
        o_created_at := v_now;
        RETURN NEXT;
    END LOOP;
END;
$func$;

GRANT EXECUTE ON FUNCTION dw.fn_generate_live_sale(INT) TO pbi_user;
