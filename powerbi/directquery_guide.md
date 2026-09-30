# Guia Completo: Power BI DirectQuery com PostgreSQL (Padrão PL-300)

Este guia orienta a conexão, modelagem dimensional e aplicação das melhores práticas de **DirectQuery** utilizando o PostgreSQL rodando via Docker.

---

## 1. Conexão no Power BI Desktop

1. Abra o **Power BI Desktop**.
2. Clique em **Obter Dados (Get Data)** -> **Mais...** -> Selecione **Banco de Dados PostgreSQL** -> **Conectar**.
3. No diálogo de conexão:
   - **Servidor:** `localhost:5433`
   - **Banco de dados:** `dw_sales`
   - **Modo de Conectividade de Dados:** Selecione **DirectQuery** ⚡
   - *(Avançado)* Deixe a instrução SQL vazia para permitir o Query Folding nativo sobre as tabelas dimensionais e fatos.
4. Na tela de credenciais:
   - Selecione a aba lateral **Banco de dados**.
   - **Nome de usuário:** `pbi_user`
   - **Senha:** `pbi_pass_123`
   - Nível de privacidade: *Organizacional* ou *Nenhum*.
5. No **Navegador (Navigator)**, expanda o schema `dw` e selecione:
   - `dim_date`
   - `dim_customer`
   - `dim_product`
   - `dim_store`
   - `dim_channel`
   - `dim_promotion`
   - `fact_sales`
   - `fact_sales_target`
   - *(Opcional)* `agg_sales_monthly` (para laboratório de Modelo Composto)
6. Clique em **Carregar (Load)**.

---

## 2. Configuração do Modelo Dimensional (Star Schema)

Acesse a **Exibição de Modelo (Model View)** e configure os relacionamentos (1 para Muitos `1:*` com Direção de Filtro Cruzado: **Única / Single**):

| Tabela Origem (1) | Coluna Origem | Tabela Fato (*) | Coluna Destino | Status |
| :--- | :--- | :--- | :--- | :--- |
| `dim_date` | `date_key` | `fact_sales` | `order_date_key` | **Ativo** |
| `dim_date` | `date_key` | `fact_sales` | `ship_date_key` | **Inativo** (Role-playing) |
| `dim_customer` | `customer_key` | `fact_sales` | `customer_key` | **Ativo** |
| `dim_product` | `product_key` | `fact_sales` | `product_key` | **Ativo** |
| `dim_store` | `store_key` | `fact_sales` | `store_key` | **Ativo** |
| `dim_channel` | `channel_key` | `fact_sales` | `channel_key` | **Ativo** |
| `dim_promotion` | `promotion_key` | `fact_sales` | `promotion_key` | **Ativo** |
| `dim_date` | `date_key` | `fact_sales_target` | `target_date_key` | **Ativo** |

---

## 3. Melhores Práticas PL-300 Essenciais para DirectQuery

### A. Garantir Integridade Referencial (Assume Referential Integrity)
- **O que é:** No Power BI Desktop, abra as propriedades de cada relacionamento ativo da `fact_sales` e marque a opção **"Garantir integridade referencial"**.
- **Impacto no PostgreSQL:** Por padrão, o DirectQuery gera consultas com `LEFT OUTER JOIN` para prever chaves órfãs. Ao ativar essa opção, o Power BI passa a emitir `INNER JOIN`, permitindo que o otimizador do PostgreSQL utilize os índices B-tree com máxima velocidade!
- **Por que é seguro aqui:** Porque nosso schema PostgreSQL já impõe constraints de `FOREIGN KEY` rígidas em todas as chaves.

### B. Tabela de Data Própria (Mark as Date Table)
- No DirectQuery, o recurso de data automática do Power BI (*Auto Date/Time*) fica desativado.
- Clique com o botão direito na tabela `dim_date` -> **Marcar como tabela de data** -> Escolha a coluna `full_date`.
- Isso habilita o funcionamento das funções de Time Intelligence do DAX (`TOTALYTD`, `SAMEPERIODLASTYEAR`, etc.).

### C. Role-Playing Dimension com `USERELATIONSHIP`
- A data de faturamento/pedido é o relacionamento ativo (`order_date_key`).
- Para analisar as entregas e pedidos por data de expedição (`ship_date_key`), crie a medida usando `USERELATIONSHIP`:
  ```dax
  [Receita por Data de Envio] = 
  CALCULATE(
      [Receita Líquida],
      USERELATIONSHIP(fact_sales[ship_date_key], dim_date[date_key])
  )
  ```

### D. Redução de Consultas (Query Reduction)
- Em relatórios DirectQuery com grandes bases, evite disparar consultas a cada clique de filtro:
  - Vá em **Arquivo** -> **Opções e configurações** -> **Opções**.
  - Em **Arquivo Atual**, selecione **Redução de Consulta (Query Reduction)**.
  - Marque: *"Adicionar um botão Aplicar a cada segmentação de dados para aplicar as alterações quando você estiver pronto"*.

### E. Ocultar Chaves Estrangeiras da Visão de Relatório
- Boas práticas da certificação PL-300 recomendam ocultar todas as colunas de ID e chaves numéricas da tabela fato (`customer_key`, `product_key`, etc.) na Exibição de Relatório.
- Os usuários finais devem filtrar atributos exclusivamente pelas tabelas de dimensões (`dim_customer[full_name]`, `dim_product[product_name]`).

---

## 4. Laboratório Avançado: Modelos Compostos & Agregações (Aggregations)

O PL-300 avalia a habilidade de combinar **Import Mode** e **DirectQuery** no mesmo modelo (*Composite Model*):

1. Defina a tabela `dw.agg_sales_monthly` para modo de armazenamento **Importação (Import)**.
2. Mantenha a tabela `dw.fact_sales` em modo **DirectQuery**.
3. Na Exibição de Modelo, clique com o botão direito em `agg_sales_monthly` -> **Gerenciar Agregações (Manage Aggregations)**:
   - Mapeie `total_net_sales` -> Soma de `fact_sales[net_sales_amount]`.
   - Mapeie `total_quantity` -> Soma de `fact_sales[quantity]`.
   - Mapeie `year_month` -> `dim_date[year_month]`.
   - Mapeie `category` -> `dim_product[category]`.
   - Mapeie `region` -> `dim_store[region]`.
4. **Resultado:** Gráficos anuais, mensais ou por região responderão **instantaneamente da memória RAM** do Power BI, e se o usuário detalhar (*drill-through*) até o pedido individual, o Power BI fará a consulta no PostgreSQL via DirectQuery de forma totalmente transparente!
