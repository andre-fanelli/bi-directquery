-- ==============================================================================
-- 07_inserir_vendas_teste.sql
-- Script SQL para inserção de vendas de teste em tempo real (Sem dependências externas)
-- ==============================================================================

-- Executa a função geradora de vendas passando a quantidade desejada (ex: 5 vendas)
SELECT * FROM dw.fn_generate_live_sale(5);

-- Exibe as 10 vendas mais recentes para conferência
SELECT 
    order_id,
    order_time,
    customer_name,
    product_name,
    quantity,
    net_sales_amount,
    margin_amount
FROM dw.vw_live_recent_sales
LIMIT 10;
