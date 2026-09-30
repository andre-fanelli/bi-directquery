# Dicionário de Dados do Data Warehouse (Star Schema)

Este documento descreve a modelagem dimensional estrela (*Star Schema*) implementada no PostgreSQL para relatórios analíticos de alta performance com **DirectQuery** no Power BI.

---

## 1. Visão Geral da Modelagem

```
               +-------------------+
               |     dim_date      |
               +-------------------+
                         | 1
                         |
                         | * (order_date_key / ship_date_key)
+-------------------+    |    +--------------------+
|   dim_customer    |----+----|     fact_sales     |----+---- dim_store
+-------------------+ 1  |  * +--------------------+ 1    +--------------------+
                         |             | *
+-------------------+ 1  |           1 |
|    dim_product    |----+    +--------------------+
+-------------------+         |    dim_channel     |
          |                   +--------------------+
          |                            |
          +----------+                 | 1
                     |                 |
                   * |               * |
              +----------------------------+
              |     fact_sales_target      |
              +----------------------------+
```

---

## 2. Tabelas Dimensionais (Dimensões Conformadas)

### 2.1. `dw.dim_date`
- **Descrição:** Calendário dimensional completo para suporte a Time Intelligence.
- **Granularidade:** 1 linha por dia (2022-01-01 a 2026-12-31, 1.826 registros).
- **Chave Primária:** `date_key` (Inteiro formato `YYYYMMDD`).

| Coluna | Tipo | Descrição | Exemplo |
| :--- | :--- | :--- | :--- |
| `date_key` | INT | Chave substituta (Surrogate Key) | `20240515` |
| `full_date` | DATE | Data civil completa | `2024-05-15` |
| `year` | SMALLINT | Ano civil | `2024` |
| `quarter` | SMALLINT | Trimestre civil (1 a 4) | `2` |
| `quarter_name` | VARCHAR(10) | Nome do trimestre | `'Q2'` |
| `month` | SMALLINT | Mês numérico (1 a 12) | `5` |
| `month_name` | VARCHAR(20) | Nome do mês por extenso | `'Maio'` |
| `month_short_name`| VARCHAR(3) | Abreviação do mês | `'Mai'` |
| `year_month` | INT | Identificador ano-mês numérico | `202405` |
| `year_month_name` | VARCHAR(10) | Identificador ano-mês texto | `'2024-05'` |
| `day_of_month` | SMALLINT | Dia do mês (1 a 31) | `15` |
| `day_of_week` | SMALLINT | Dia da semana numérico (1=Dom, 7=Sáb) | `4` |
| `day_name` | VARCHAR(20) | Nome do dia da semana | `'Quarta-feira'` |
| `day_short_name` | VARCHAR(3) | Abreviação do dia | `'Qua'` |
| `is_weekend` | BOOLEAN | Indicador de final de semana | `false` |
| `fiscal_year` | SMALLINT | Ano fiscal (início em Julho) | `2024` |
| `fiscal_quarter` | VARCHAR(10) | Trimestre fiscal | `'FQ4'` |
| `week_of_year` | SMALLINT | Semana do ano (1 a 53) | `20` |

---

### 2.2. `dw.dim_customer`
- **Descrição:** Cadastro consolidado de clientes.
- **Granularidade:** 1 linha por cliente (10.000 clientes).
- **Chave Primária:** `customer_key` (Inteiro autoincremental).

| Coluna | Tipo | Descrição | Exemplo |
| :--- | :--- | :--- | :--- |
| `customer_key` | INT | Chave substituta | `1` |
| `customer_id` | VARCHAR(20) | Identificador de negócio | `'CUST-000001'` |
| `first_name` | VARCHAR(50) | Primeiro nome | `'Mariana'` |
| `last_name` | VARCHAR(50) | Sobrenome | `'Alves'` |
| `full_name` | VARCHAR(100) | Nome completo | `'Mariana Alves'` |
| `gender` | VARCHAR(1) | Gênero (`M`, `F`) | `'F'` |
| `birth_date` | DATE | Data de nascimento | `'1988-04-12'` |
| `age` | SMALLINT | Idade | `36` |
| `age_group` | VARCHAR(20) | Faixa etária (`18-25`, `26-35`, `36-50`, `51+`) | `'36-50'` |
| `email` | VARCHAR(100) | E-mail de contato | `'mariana.alves1@email.com.br'` |
| `phone` | VARCHAR(30) | Telefone | `'+55 (11) 98765432'` |
| `city` | VARCHAR(50) | Cidade | `'São Paulo'` |
| `state` | VARCHAR(2) | UF | `'SP'` |
| `region` | VARCHAR(20) | Região geográfica brasileira | `'Sudeste'` |
| `country` | VARCHAR(30) | País de residência | `'Brasil'` |
| `customer_segment` | VARCHAR(30) | Segmento (`Varejo`, `Corporativo`, `Pequenas Empresas`) | `'Varejo'` |

---

### 2.3. `dw.dim_product`
- **Descrição:** Catálogo de produtos com hierarquia desnormalizada (eliminando Snowflake conforme boas práticas do PL-300).
- **Granularidade:** 1 linha por produto (500 produtos).
- **Chave Primária:** `product_key` (Inteiro autoincremental).

| Coluna | Tipo | Descrição | Exemplo |
| :--- | :--- | :--- | :--- |
| `product_key` | INT | Chave substituta | `1` |
| `product_id` | VARCHAR(20) | Identificador do produto | `'PRD-0001'` |
| `sku` | VARCHAR(30) | Código de estoque (SKU) | `'SKU-DEL-0001'` |
| `product_name` | VARCHAR(120) | Nome comercial do produto | `'Dell Ultrabook Pro Mod-101'` |
| `category` | VARCHAR(50) | Categoria macro | `'Computadores & Notebooks'` |
| `subcategory` | VARCHAR(50) | Subcategoria | `'Ultrabook Pro'` |
| `brand` | VARCHAR(50) | Fabricante/Marca | `'Dell'` |
| `unit_cost` | NUMERIC(12,2) | Custo padrão de aquisição | `1200.00` |
| `list_price` | NUMERIC(12,2) | Preço de tabela sugerido | `1680.00` |
| `product_status` | VARCHAR(20) | Situação (`Ativo`, `Descontinuado`) | `'Ativo'` |

---

### 2.4. `dw.dim_store`
- **Descrição:** Lojas físicas e centros de distribuição.
- **Granularidade:** 1 linha por unidade de atendimento (30 unidades).
- **Chave Primária:** `store_key`.

| Coluna | Tipo | Descrição | Exemplo |
| :--- | :--- | :--- | :--- |
| `store_key` | INT | Chave substituta | `1` |
| `store_id` | VARCHAR(20) | Identificador da loja | `'ST-001'` |
| `store_name` | VARCHAR(100) | Nome da filial | `'Mega Store Paulista'` |
| `store_type` | VARCHAR(30) | Formato (`Flagship`, `Loja Física`, `Outlet`, `CD`) | `'Flagship'` |
| `city` | VARCHAR(50) | Cidade | `'São Paulo'` |
| `state` | VARCHAR(2) | UF | `'SP'` |
| `region` | VARCHAR(20) | Região geográfica | `'Sudeste'` |
| `store_size_m2` | INT | Área em metros quadrados | `1500` |
| `manager_name` | VARCHAR(100) | Nome do gerente responsável | `'Carlos Eduardo Silva'` |
| `open_date` | DATE | Data de inauguração | `'2018-03-15'` |

---

### 2.5. `dw.dim_channel` & `dw.dim_promotion`
- `dw.dim_channel`: Canais de venda (`E-commerce Web`, `Aplicativo Mobile`, `Loja Física`, `Marketplace B2B`).
- `dw.dim_promotion`: Campanhas de desconto (`Preço Regular`, `Black Friday`, `Liquidação de Verão`, etc.).

---

## 3. Tabelas Fato

### 3.1. `dw.fact_sales`
- **Descrição:** Fato transacional de vendas em nível de item do pedido.
- **Granularidade:** 1 linha por item de pedido (350.000 transações).
- **Chave Primária:** `sales_key` (BIGINT).
- **Chaves Estrangeiras:**
  - `order_date_key` -> `dim_date.date_key` (Data de emissão da compra - Relacionamento Ativo no Power BI)
  - `ship_date_key` -> `dim_date.date_key` (Data de despacho - Relacionamento Inativo / Role-playing)
  - `customer_key` -> `dim_customer.customer_key`
  - `product_key` -> `dim_product.product_key`
  - `store_key` -> `dim_store.store_key`
  - `channel_key` -> `dim_channel.channel_key`
  - `promotion_key` -> `dim_promotion.promotion_key`

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `order_id` | VARCHAR(30) | Código do pedido (agrupador de linhas) |
| `order_line` | INT | Número sequencial da linha do pedido (1, 2, 3) |
| `order_status` | VARCHAR(20) | Estado do pedido (`Entregue`, `Enviado`, `Processando`, `Cancelado`) |
| `quantity` | INT | Quantidade comercializada |
| `unit_cost` | NUMERIC(12,2) | Custo unitário no momento da venda |
| `unit_price` | NUMERIC(12,2) | Preço unitário de tabela |
| `discount_amount` | NUMERIC(12,2) | Valor total de desconto concedido no item |
| `gross_sales_amount` | NUMERIC(12,2) | Valor bruto (`quantity * unit_price`) |
| `net_sales_amount` | NUMERIC(12,2) | Valor líquido (`gross_sales_amount - discount_amount`) |
| `total_cost_amount` | NUMERIC(12,2) | Custo total (`quantity * unit_cost`) |
| `margin_amount` | NUMERIC(12,2) | Lucro bruto (`net_sales_amount - total_cost_amount`) |
| `tax_amount` | NUMERIC(12,2) | Impostos estimados incidentes (12%) |

---

### 3.2. `dw.fact_sales_target`
- **Descrição:** Fato de metas comerciais para comparação Realizado vs Meta.
- **Granularidade:** 1 linha por Mês + Categoria + Região (1.800 registros de 2022 a 2026).
- **Chaves Estrangeiras:** `target_date_key` -> `dim_date.date_key` (Dia 01 de cada mês).

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `target_key` | INT | Chave primária |
| `year_month` | INT | Formato numérico YYYYMM |
| `target_date_key` | INT | Chave de data referenciando o primeiro dia do mês |
| `category` | VARCHAR(50) | Categoria do produto |
| `region` | VARCHAR(20) | Região de vendas |
| `target_sales_amount`| NUMERIC(14,2) | Valor de meta de vendas estipulado |

---

## 4. Otimizações para DirectQuery
1. **Índices B-tree:** Todas as Foreign Keys e colunas de agregação possuem índices criados no banco, garantindo que o PostgreSQL execute `Index Scan` ou `Bitmap Heap Scan` em vez de varreduras completas (*Seq Scan*).
2. **PostgreSQL Tuning:** Configurações de `work_mem = 64MB`, `random_page_cost = 1.1` e paralelismo de workers ativadas em `postgresql.conf` para acelerar os `GROUP BY` e `JOIN` emitidos pelo Power BI.
