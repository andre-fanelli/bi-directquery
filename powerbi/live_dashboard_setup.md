# 📊 Guia de Construção do Dashboard em Tempo Real (Power BI Desktop)

Este guia ensina a criar um Dashboard com **duas páginas profissionais** no Power BI Desktop conectado ao PostgreSQL via **DirectQuery**, com suporte à **Atualização Automática de Página (Automatic Page Refresh - APR)** para validação do streaming em tempo real.

---

## 1. Conexão e Carga no Power BI Desktop

1. Abra o **Power BI Desktop**.
2. Vá em **Página Inicial** -> **Obter Dados** -> **PostgreSQL**.
3. Servidor: `localhost:5433` | Banco: `dw_sales` | Modo: **DirectQuery** ⚡.
4. Usuário: `pbi_user` | Senha: `pbi_pass_123`.
5. No Navegador, selecione todas as tabelas:
   - `dw.dim_date`
   - `dw.dim_customer`
   - `dw.dim_product`
   - `dw.dim_store`
   - `dw.dim_channel`
   - `dw.dim_promotion`
   - `dw.fact_sales`
   - `dw.fact_sales_target`
   - `dw.vw_live_recent_sales` (Visão para auditoria live)
6. Na aba **Exibição de Modelo (Model View)**, confirme os relacionamentos (1 para Muitos `1:*`, Filtro Cruzado: **Única**, e marque **Garantir Integridade Referencial** nos relacionamentos da `fact_sales`).

---

## 2. Página 1: Visão Executiva & Metas (Padrão PL-300)

*Objetivo: Demonstrar a capacidade analítica sobre 350.000+ linhas históricas via DirectQuery.*

### A. Cartões de Indicadores (KPI Cards) - Topo da Página
- **Cartão 1:** `[Receita Líquida]` (Formato Moeda R$)
- **Cartão 2:** `[Lucro Bruto]` (Formato Moeda R$)
- **Cartão 3:** `[Margem %]` (Formato Percentual com 1 decimal)
- **Cartão 4:** `[Qtd de Pedidos]` (Formato Número Inteiro)
- **Cartão 5:** `[% Atingimento de Meta]` (Formato Percentual)

### B. Visuais Gráficos (Corpo do Relatório)
1. **Gráfico de Colunas Clusterizadas e Linha:**
   - Eixo X: `dim_product[category]`
   - Eixo Y (Coluna): `[Receita Líquida]`
   - Eixo Y (Linha): `[Meta de Vendas]`
   - *Finalidade:* Comparativo de Realizado vs Meta por categoria.
2. **Gráfico de Linhas (Evolução Temporal):**
   - Eixo X: `dim_date[year_month_name]`
   - Eixo Y: `[Receita Líquida]`
   - *Finalidade:* Tendência histórica de faturamento (2022 a 2026).
3. **Gráfico de Rosca (Donut):**
   - Legenda: `dim_channel[channel_name]`
   - Valores: `[Receita Líquida]`
   - *Finalidade:* Participação dos canais (E-commerce Web, Mobile App, Loja Física, B2B).
4. **Gráfico de Barras Horizontais (Geográfico):**
   - Eixo Y: `dim_store[region]`
   - Eixo X: `[Receita Líquida]`
   - *Finalidade:* Ranking de vendas por região (Sudeste, Sul, Nordeste, Centro-Oeste, Norte).

### C. Segmentadores de Dados (Filtros no Topo/Lateral)
- `dim_date[year]` (Ano: 2022, 2023, 2024, 2025, 2026)
- `dim_customer[customer_segment]` (Varejo, Corporativo, Pequenas Empresas)

---

## 3. Página 2: Monitoramento em Tempo Real (Live DirectQuery Monitor)

*Objetivo: Ver os números e o feed de transações mudarem sozinhos na tela conforme os pedidos chegam no PostgreSQL.*

### A. Ativação da Atualização Automática de Página (APR)
1. Clique em uma área vazia da página.
2. Abra o painel **Formatar página de relatório (pincel)**.
3. Localize e ative a seção **Atualização de página (Page refresh)**.
4. Tipo de atualização: **Atualização periódica (Periodic refresh)**.
5. Definir intervalo: **5 segundos** (ou 3 segundos).
> 💡 *Em DirectQuery, essa funcionalidade reexecuta as consultas SQL no PostgreSQL automaticamente a cada 5s sem que o usuário precise clicar em nenhum botão!*

### B. Cartões Dinâmicos do Dia
- **Cartão 1 (Destaque Verde):** `[Receita Hoje - Live]` (Faturamento das compras realizadas no dia atual)
- **Cartão 2:** `[Qtd Pedidos Hoje - Live]` (Volume de pedidos de hoje)
- **Cartão 3:** `[Ticket Médio Hoje]`
- **Cartão 4:** `[Último Horário de Pedido]` (Exibe o horário exato da última compra inserida)

### C. Tabela de Feed em Tempo Real (Live Stream)
- Crie um visual de **Tabela** utilizando os campos de `dw.vw_live_recent_sales`:
  - `order_time` (Horário do Pedido)
  - `order_id` (Código do Pedido)
  - `customer_name` (Cliente)
  - `product_name` (Produto Comprado)
  - `store_name` (Filial)
  - `quantity` (Quantidade)
  - `net_sales_amount` (Valor Líquido R$)
  - `margin_amount` (Lucro R$)
- Ordene a tabela por `order_time` **Decrescente** (as vendas mais recentes no topo).

### D. Gráfico de Barras: Top Produtos Hoje
- Eixo Y: `dim_product[product_name]`
- Eixo X: `[Receita Hoje - Live]`
- Filtro no visual: Filtro de Top N -> 5 superiores por `[Receita Hoje - Live]`.

---

## 4. Como Executar o Teste Prático de Streaming em Tempo Real

1. Com o Power BI Desktop aberto na **Página 2** (com Atualização Automática de Página ativa a cada 5s).
2. Abra um terminal PowerShell na pasta do projeto e execute o simulador contínuo:
   ```powershell
   .\scripts\simulate_live_sales.ps1 -IntervalSeconds 3
   ```
3. Ou insira um lote de 10 pedidos instantaneamente:
   ```powershell
   .\scripts\simulate_live_sales.ps1 -Batch 10
   ```
4. **Observe o Power BI:**
   - O cartão de `[Receita Hoje - Live]` incrementa em tempo real.
   - O `[Último Horário de Pedido]` se atualiza com o horário da última venda.
   - A tabela do feed exibe a nova linha no topo instantaneamente!
