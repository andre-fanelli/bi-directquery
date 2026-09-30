# 📘 PROJETO GUIADO: DASHBOARD COMPLETO NO POWER BI COM DIRECTQUERY

> **Objetivo:** Construir do zero um relatório profissional de Business Intelligence no **Power BI Desktop**, utilizando conexão **DirectQuery** ao PostgreSQL em arquitetura **Star Schema**, com métricas financeiras, análise de metas, dimensões com múltiplos papéis (*Role-Playing*) e validação de **streaming em tempo real** através de Atualização Automática de Página (APR).

---

## 📑 Sumário do Projeto
1. [Módulo 1: Conexão e Ingestão com DirectQuery](#módulo-1-conexão-e-ingestão-com-directquery)
2. [Módulo 2: Modelagem Dimensional Estrela (Star Schema)](#módulo-2-modelagem-dimensional-estrela-star-schema)
3. [Módulo 3: Criação da Tabela de Medidas e DAX](#módulo-3-criação-da-tabela-de-medidas-e-dax)
4. [Módulo 4: Construção da Página 1 - Visão Executiva & Metas](#módulo-4-construção-da-página-1---visão-executiva--metas)
5. [Módulo 5: Construção da Página 2 - Monitoramento em Tempo Real (Live APR)](#módulo-5-construção-da-página-2---monitoramento-em-tempo-real-live-apr)
6. [Módulo 6: Validação Prática em Tempo Real](#módulo-6-validação-prática-em-tempo-real)
7. [Módulo 7: Checklist de Melhores Práticas do Exame PL-300](#módulo-7-checklist-de-melhores-práticas-do-exame-pl-300)

---

## Módulo 1: Conexão e Ingestão com DirectQuery

### Passo 1.1: Garantir que o container do banco está ativo
No terminal PowerShell, verifique se o banco PostgreSQL está rodando na porta **5433**:
```powershell
docker ps --filter "name=pbi-postgres-dw"
```
*(Deve exibir o container com status `healthy` e porta `0.0.0.0:5433->5432/tcp`).*

---

### Passo 1.2: Conectar o Power BI Desktop
1. Abra o **Power BI Desktop**.
2. Na faixa de opções superior (**Página Inicial**), clique em **Obter Dados** -> **Mais...**
3. Na caixa de pesquisa, digite `PostgreSQL` e clique em **Conectar**.
4. Preencha os parâmetros de conexão:
   - **Servidor:** `localhost:5433`
   - **Banco de Dados:** `dw_sales`
   - **Modo de Conectividade de Dados:** Marque a opção **DirectQuery** ⚡
   > ⚠️ **Atenção:** NÃO selecione "Importar". O modo DirectQuery envia consultas SQL sob demanda ao banco, mantendo os dados no PostgreSQL sem sobrecarregar a memória RAM do arquivo `.pbix`.
5. Clique em **OK**.
6. Na janela de credenciais:
   - Selecione a aba lateral **Banco de Dados**.
   - **Nome de usuário:** `pbi_user`
   - **Senha:** `pbi_pass_123`
   - Nível de privacidade: *Nenhum* ou *Organizacional*.
   - Clique em **Conectar**.

---

### Passo 1.3: Seleção das Tabelas
No diálogo do **Navegador (Navigator)**, expanda o schema **`dw`** e selecione as seguintes **9 tabelas/views**:
- [x] `dim_date`
- [x] `dim_customer`
- [x] `dim_product`
- [x] `dim_store`
- [x] `dim_channel`
- [x] `dim_promotion`
- [x] `fact_sales`
- [x] `fact_sales_target`
- [x] `vw_live_recent_sales`

Clique diretamente em **Carregar (Load)**.
*(O Power BI lerá apenas a estrutura de metadados em poucos segundos, sem importar as 350.000 linhas para o arquivo).*

---

## Módulo 2: Modelagem Dimensional Estrela (Star Schema)

Acesse a **Exibição de Modelo (Model View)** no painel esquerdo do Power BI (ícone de diagrama).

```
               +-------------------+
               |     dim_date      |
               +-------------------+
                         | 1
                         |
                         | * (order_date_key / ship_date_key)
+-------------------+    |    +--------------------+    +--------------------+
|   dim_customer    |----+----|     fact_sales     |----+|     dim_store      |
+-------------------+ 1  |  * +--------------------+ *  1+--------------------+
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

### Passo 2.1: Configurar os Relacionamentos
Crie/verifique cada relacionamento arrastando o campo de origem para o de destino:

| Tabela Origem (1) | Coluna Origem | Tabela Fato (*) | Coluna Destino | Cardinalidade | Direção Filtro |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `dim_date` | `date_key` | `fact_sales` | `order_date_key` | `1 para Muitos (1:*)` | Única (Single) |
| `dim_date` | `date_key` | `fact_sales` | `ship_date_key` | `1 para Muitos (1:*)` | Única (Inativo) |
| `dim_customer` | `customer_key` | `fact_sales` | `customer_key` | `1 para Muitos (1:*)` | Única |
| `dim_product` | `product_key` | `fact_sales` | `product_key` | `1 para Muitos (1:*)` | Única |
| `dim_store` | `store_key` | `fact_sales` | `store_key` | `1 para Muitos (1:*)` | Única |
| `dim_channel` | `channel_key` | `fact_sales` | `channel_key` | `1 para Muitos (1:*)` | Única |
| `dim_promotion` | `promotion_key` | `fact_sales` | `promotion_key` | `1 para Muitos (1:*)` | Única |
| `dim_date` | `date_key` | `fact_sales_target` | `target_date_key` | `1 para Muitos (1:*)` | Única |

---

### Passo 2.2: O Segredo de Performance: "Garantir Integridade Referencial"
1. Dê um duplo clique na linha de relacionamento entre `dim_date` e `fact_sales` (`order_date_key`).
2. Marque a caixa de seleção: **Garantir integridade referencial (Assume referential integrity)**.
3. Repita o mesmo procedimento para os relacionamentos de:
   - `dim_customer` -> `fact_sales`
   - `dim_product` -> `fact_sales`
   - `dim_store` -> `fact_sales`
   - `dim_channel` -> `fact_sales`

> 🎯 **Conceito PL-300:** Ao ativar essa opção, o Power BI substitui cláusulas pesadas de `LEFT OUTER JOIN` por `INNER JOIN` nas consultas enviadas ao PostgreSQL, aproveitando os índices B-Tree criados no banco e acelerando as consultas em até 10x!

---

### Passo 2.3: Marcar Tabela de Data (Mark as Date Table)
1. Clique com o botão direito na tabela `dim_date`.
2. Selecione **Marcar como tabela de data** -> **Marcar como tabela de data**.
3. Na caixa suspensa, selecione a coluna **`full_date`**.
4. Clique em **OK**.
*(Isso habilita o funcionamento das funções de Time Intelligence do DAX no DirectQuery).*

---

### Passo 2.4: Ocultar Colunas Técnicas
Para seguir as regras de boa prática de design dimensional:
- Na tabela `fact_sales`, selecione as colunas de chave: `customer_key`, `product_key`, `store_key`, `channel_key`, `promotion_key`, `order_date_key`, `ship_date_key`.
- Clique com botão direito -> **Ocultar na exibição de relatório**.
*(Os usuários do relatório devem filtrar atributos usando os nomes e descrições das tabelas de dimensão).*

---

## Módulo 3: Criação da Tabela de Medidas e DAX

### Passo 3.1: Criar uma Tabela Dedicada para Medidas
1. Na faixa de opções (**Página Inicial**), clique em **Inserir Dados**.
2. Altere o nome da tabela para **`_Medidas`**.
3. Clique em **Carregar**.
4. Após criar a primeira medida abaixo, clique com botão direito na coluna vazia `Coluna1` e selecione **Excluir do modelo**.

---

### Passo 3.2: Criar as Fórmulas DAX
Clique com botão direito na tabela `_Medidas` -> **Nova Medida** e insira as fórmulas organizadas por pasta:

#### Pasta: `01 - Faturamento`
```dax
Receita Bruta = 
SUM(fact_sales[gross_sales_amount])
```
*(Formate como Moeda: R$)*

```dax
Desconto Total = 
SUM(fact_sales[discount_amount])
```

```dax
Receita Líquida = 
SUM(fact_sales[net_sales_amount])
```
*(Formate como Moeda: R$)*

```dax
Custo Total = 
SUM(fact_sales[total_cost_amount])
```

```dax
Lucro Bruto = 
[Receita Líquida] - [Custo Total]
```
*(Formate como Moeda: R$)*

```dax
Margem % = 
DIVIDE([Lucro Bruto], [Receita Líquida], 0)
```
*(Formate como Percentual: 0,0%)*

```dax
Qtd de Pedidos = 
DISTINCTCOUNT(fact_sales[order_id])
```

```dax
Ticket Médio = 
DIVIDE([Receita Líquida], [Qtd de Pedidos], 0)
```

---

#### Pasta: `02 - Metas`
```dax
Meta de Vendas = 
SUM(fact_sales_target[target_sales_amount])
```

```dax
% Atingimento de Meta = 
DIVIDE([Receita Líquida], [Meta de Vendas], 0)
```
*(Formate como Percentual: 0,0%)*

```dax
Variação Meta = 
[Receita Líquida] - [Meta de Vendas]
```

---

#### Pasta: `03 - Time Intelligence`
```dax
Receita YTD = 
TOTALYTD(
    [Receita Líquida],
    dim_date[full_date]
)
```

```dax
Receita Ano Anterior = 
CALCULATE(
    [Receita Líquida],
    SAMEPERIODLASTYEAR(dim_date[full_date])
)
```

```dax
Crescimento YoY % = 
DIVIDE([Receita Líquida] - [Receita Ano Anterior], [Receita Ano Anterior], 0)
```

---

#### Pasta: `04 - Logística (Role-Playing)`
```dax
Receita por Data de Envio = 
CALCULATE(
    [Receita Líquida],
    USERELATIONSHIP(fact_sales[ship_date_key], dim_date[date_key])
)
```

---

#### Pasta: `05 - Monitoramento Live (Tempo Real)`
```dax
Data Hoje Key = 
YEAR(TODAY()) * 10000 + MONTH(TODAY()) * 100 + DAY(TODAY())
```

```dax
Receita Hoje - Live = 
CALCULATE(
    [Receita Líquida],
    FILTER(
        dim_date,
        dim_date[date_key] = [Data Hoje Key]
    )
)
```

```dax
Qtd Pedidos Hoje - Live = 
CALCULATE(
    [Qtd de Pedidos],
    FILTER(
        dim_date,
        dim_date[date_key] = [Data Hoje Key]
    )
)
```

```dax
Último Horário de Pedido = 
COALESCE(
    MAX(vw_live_recent_sales[order_time]),
    "Aguardando vendas hoje..."
)
```

---

## Módulo 4: Construção da Página 1 - Visão Executiva & Metas

Renomeie a primeira página do relatório para **`Visão Executiva`**.

```
+-----------------------------------------------------------------------------------+
| [Segmentador: Ano]  [Segmentador: Segmento Cliente]          [Logo / Título Executivo]|
+-----------------------------------------------------------------------------------+
| [Card: Receita Líquida] [Card: Lucro Bruto] [Card: Margem %] [Card: Total Pedidos]  |
+-------------------------------------------------+---------------------------------+
| Gráfico de Colunas e Linha:                     | Gráfico de Rosca:               |
| Receita Líquida vs Meta de Vendas por Categoria | Faturamento por Canal de Venda  |
+-------------------------------------------------+---------------------------------+
| Gráfico de Linha (Tendência):                   | Gráfico de Barras Horizontais:  |
| Evolução Mensal da Receita Líquida              | Faturamento por Região          |
+-------------------------------------------------+---------------------------------+
```

### Passo 4.1: Segmentadores de Dados (Filtros no Cabeçalho)
- **Segmentador 1:** Arraste `dim_date[year]` (Ano). Formato: Estilo Lista Vertical ou Dropdown.
- **Segmentador 2:** Arraste `dim_customer[customer_segment]` (Varejo, Corporativo, Pequenas Empresas).

---

### Passo 4.2: Cartões de Indicadores (KPIs)
Adicione 4 visuais do tipo **Cartão (Card)** alinhados no topo:
1. Campo: `_Medidas[Receita Líquida]`
2. Campo: `_Medidas[Lucro Bruto]`
3. Campo: `_Medidas[Margem %]`
4. Campo: `_Medidas[Qtd de Pedidos]`

---

### Passo 4.3: Gráfico de Colunas Clusterizadas e Linha (Realizado vs Meta)
1. Selecione o visual **Gráfico de colunas e linha**.
2. **Eixo X:** `dim_product[category]`
3. **Eixo Y da coluna:** `_Medidas[Receita Líquida]`
4. **Eixo Y da linha:** `_Medidas[Meta de Vendas]`
*(Demonstra a comparação de vendas contra a meta corporativa).*

---

### Passo 4.4: Gráfico de Rosca (Canais de Venda)
1. Selecione o visual **Gráfico de rosca**.
2. **Legenda:** `dim_channel[channel_name]`
3. **Valores:** `_Medidas[Receita Líquida]`

---

### Passo 4.5: Gráfico de Linhas (Evolução Temporal)
1. Selecione o visual **Gráfico de linhas**.
2. **Eixo X:** `dim_date[year_month_name]`
3. **Eixo Y:** `_Medidas[Receita Líquida]`

---

### Passo 4.6: Gráfico de Barras Horizontais (Vendas por Região)
1. Selecione o visual **Gráfico de barras clusterizadas**.
2. **Eixo Y:** `dim_store[region]`
3. **Eixo X:** `_Medidas[Receita Líquida]`

---

## Módulo 5: Construção da Página 2 - Monitoramento em Tempo Real (Live APR)

Crie uma nova página e renomeie para **`Monitoramento Live`**.

```
+-----------------------------------------------------------------------------------+
| 🔴 MONITORAMENTO EM TEMPO REAL (DIRECTQUERY STREAMING)                            |
+-----------------------------------------------------------------------------------+
| [Card Verde: Receita Hoje]  [Card Azul: Pedidos Hoje]   [Card Roxo: Último Horário] |
+-----------------------------------------------------------------------------------+
| Tabela de Feed em Tempo Real (vw_live_recent_sales):                              |
| Horário  | Pedido ID      | Cliente        | Produto        | Qtd | Valor Líquido |
+-----------------------------------------------------------------------------------+
| Gráfico de Barras: Top 5 Produtos Vendidos Hoje                                   |
+-----------------------------------------------------------------------------------+
```

### Passo 5.1: Ativar a Atualização Automática de Página (APR)
1. Clique em uma área vazia da página.
2. No painel lateral direito, clique em **Formatar página do relatório** (ícone do pincel).
3. Localize e ative a seção **Atualização de página (Page refresh)**.
4. Defina:
   - **Tipo de atualização:** `Atualização periódica (Periodic refresh)`
   - **Atualizar a cada:** `5` `Segundos`

> 💡 *Pronto! A partir de agora, a cada 5 segundos o Power BI Desktop envia automaticamente uma consulta SQL ao PostgreSQL e redesenha os visuais sem nenhuma ação manual do usuário!*

---

### Passo 5.2: Cartões de Destaque Live
Adicione 3 cartões no topo da tela:
1. **Cartão 1:** Campo: `_Medidas[Receita Hoje - Live]` (Formatação de texto grande em Verde).
2. **Cartão 2:** Campo: `_Medidas[Qtd Pedidos Hoje - Live]`.
3. **Cartão 3:** Campo: `_Medidas[Último Horário de Pedido]`.

---

### Passo 5.3: Tabela de Feed Transacional ao Vivo
1. Adicione um visual do tipo **Tabela**.
2. Arraste os seguintes campos da view `dw.vw_live_recent_sales`:
   - `order_time` (Horário)
   - `order_id` (Código do Pedido)
   - `customer_name` (Cliente)
   - `product_name` (Produto)
   - `store_name` (Filial)
   - `quantity` (Quantidade)
   - `net_sales_amount` (Valor Líquido R$)
   - `margin_amount` (Lucro R$)
3. Clique no cabeçalho da coluna **`order_time`** para ordenar de forma **Decrescente** (as compras mais recentes aparecerão no topo).

---

### Passo 5.4: Gráfico de Barras: Top Produtos Hoje
1. Selecione o visual **Gráfico de barras clusterizadas**.
2. **Eixo Y:** `dim_product[product_name]`
3. **Eixo X:** `_Medidas[Receita Hoje - Live]`
4. No painel **Filtros**, em `product_name`:
   - Tipo de filtro: **Top N**
   - Mostrar itens: **Superior** `5`
   - Por valor: arraste `_Medidas[Receita Hoje - Live]`
   - Clique em **Aplicar filtro**.

---

## Módulo 6: Validação Prática em Tempo Real

Agora faremos a prova real de que o DirectQuery está respondendo instantaneamente ao banco de dados:

1. Deixe o **Power BI Desktop visível na Página 2 (Monitoramento Live)**.
2. Abra o terminal **PowerShell** na pasta do projeto e execute:
   ```powershell
   # Injeta 5 pedidos de teste diretamente no banco:
   docker exec pbi-postgres-dw psql -U postgres -d dw_sales -c "SELECT * FROM dw.fn_generate_live_sale(5);"
   ```
3. **Observe a tela do Power BI Desktop:**
   - Em menos de 5 segundos, sem tocar no mouse, os cartões de **Receita Hoje** e **Pedidos Hoje** vão somar os novos valores.
   - O cartão de **Último Horário de Pedido** atualizará com a hora exata.
   - As 5 novas vendas surgirão instantaneamente no topo da tabela de feed!

Se quiser deixar um fluxo contínuo de simulação rodando:
```powershell
.\scripts\simulate_live_sales.ps1 -IntervalSeconds 3
```
*(Para interromper, basta pressionar `Ctrl + C` no terminal).*

---

## Módulo 7: Checklist de Melhores Práticas do Exame PL-300

| Requisito do Exame | Como Foi Implementado no Projeto |
| :--- | :--- |
| **Star Schema Puro** | Eliminamos nós Snowflake. Categorias foram desnormalizadas na `dim_product` e geografia na `dim_customer`/`dim_store`. |
| **Garantir Integridade Referencial** | Opção ativada nos relacionamentos da fato, instruindo o Power BI a gerar `INNER JOIN` em vez de `LEFT OUTER JOIN`. |
| **Tabela de Data Física** | Tabela `dim_date` dedicada (2022 a 2026) marcada como Tabela de Data (essencial porque *Auto Date/Time* é desabilitado em DirectQuery). |
| **Role-Playing Dimension** | Criamos a medida `[Receita por Data de Envio]` com a função `USERELATIONSHIP(fact_sales[ship_date_key], dim_date[date_key])`. |
| **Diferentes Granularidades** | Fato de vendas diárias em nível de linha de pedido vs Fato de metas em nível mensal por categoria/região. |
| **Automatic Page Refresh (APR)** | Atualização periódica a cada 5 segundos ativada diretamente na página para streaming operacional. |
| **Segurança de Acesso ao Banco** | Conexão feita com usuário de privilégios mínimos de leitura (`pbi_user`) em vez do superusuário `postgres`. |

---

Salve seu arquivo `.pbix` na pasta do projeto com o nome **`PBI_DQ_TEST.pbix`**.
O projeto está 100% completo, sem nenhuma dependência de bibliotecas Python, e totalmente focado no ecossistema **Power BI + PostgreSQL**.
