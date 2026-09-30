-- ==============================================================================
-- 02_seed_dimensions.sql
-- Seed Dimension Tables with Realistic High-Volume Data
-- ==============================================================================

SET search_path TO dw, public;

-- ------------------------------------------------------------------------------
-- 1. Seed dim_date (2022 to 2026 = 1826 days)
-- ------------------------------------------------------------------------------
INSERT INTO dw.dim_date (
    date_key,
    full_date,
    year,
    quarter,
    quarter_name,
    month,
    month_name,
    month_short_name,
    year_month,
    year_month_name,
    day_of_month,
    day_of_week,
    day_name,
    day_short_name,
    is_weekend,
    fiscal_year,
    fiscal_quarter,
    week_of_year
)
SELECT
    (to_char(d, 'YYYYMMDD'))::int AS date_key,
    d::date AS full_date,
    EXTRACT(YEAR FROM d)::smallint AS year,
    EXTRACT(QUARTER FROM d)::smallint AS quarter,
    'Q' || EXTRACT(QUARTER FROM d)::text AS quarter_name,
    EXTRACT(MONTH FROM d)::smallint AS month,
    CASE EXTRACT(MONTH FROM d)::int
        WHEN 1 THEN 'Janeiro'
        WHEN 2 THEN 'Fevereiro'
        WHEN 3 THEN 'Março'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Maio'
        WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Setembro'
        WHEN 10 THEN 'Outubro'
        WHEN 11 THEN 'Novembro'
        WHEN 12 THEN 'Dezembro'
    END AS month_name,
    CASE EXTRACT(MONTH FROM d)::int
        WHEN 1 THEN 'Jan'
        WHEN 2 THEN 'Fev'
        WHEN 3 THEN 'Mar'
        WHEN 4 THEN 'Abr'
        WHEN 5 THEN 'Mai'
        WHEN 6 THEN 'Jun'
        WHEN 7 THEN 'Jul'
        WHEN 8 THEN 'Ago'
        WHEN 9 THEN 'Set'
        WHEN 10 THEN 'Out'
        WHEN 11 THEN 'Nov'
        WHEN 12 THEN 'Dez'
    END AS month_short_name,
    (to_char(d, 'YYYYMM'))::int AS year_month,
    to_char(d, 'YYYY-MM') AS year_month_name,
    EXTRACT(DAY FROM d)::smallint AS day_of_month,
    (EXTRACT(DOW FROM d)::smallint + 1) AS day_of_week, -- 1=Dom, 7=Sab
    CASE EXTRACT(DOW FROM d)::int
        WHEN 0 THEN 'Domingo'
        WHEN 1 THEN 'Segunda-feira'
        WHEN 2 THEN 'Terça-feira'
        WHEN 3 THEN 'Quarta-feira'
        WHEN 4 THEN 'Quinta-feira'
        WHEN 5 THEN 'Sexta-feira'
        WHEN 6 THEN 'Sábado'
    END AS day_name,
    CASE EXTRACT(DOW FROM d)::int
        WHEN 0 THEN 'Dom'
        WHEN 1 THEN 'Seg'
        WHEN 2 THEN 'Ter'
        WHEN 3 THEN 'Qua'
        WHEN 4 THEN 'Qui'
        WHEN 5 THEN 'Sex'
        WHEN 6 THEN 'Sáb'
    END AS day_short_name,
    CASE WHEN EXTRACT(DOW FROM d) IN (0, 6) THEN true ELSE false END AS is_weekend,
    -- Fiscal Year (Starts in July, common enterprise PL-300 scenario)
    (CASE WHEN EXTRACT(MONTH FROM d) >= 7 THEN EXTRACT(YEAR FROM d) + 1 ELSE EXTRACT(YEAR FROM d) END)::smallint AS fiscal_year,
    ('FQ' || (CASE 
        WHEN EXTRACT(QUARTER FROM d) = 1 THEN '3'
        WHEN EXTRACT(QUARTER FROM d) = 2 THEN '4'
        WHEN EXTRACT(QUARTER FROM d) = 3 THEN '1'
        ELSE '2'
    END)) AS fiscal_quarter,
    EXTRACT(WEEK FROM d)::smallint AS week_of_year
FROM generate_series('2022-01-01'::date, '2026-12-31'::date, '1 day'::interval) AS d;

-- ------------------------------------------------------------------------------
-- 2. Seed dim_channel
-- ------------------------------------------------------------------------------
INSERT INTO dw.dim_channel (channel_id, channel_name, channel_category) VALUES
('CH-WEB',   'E-commerce Web',     'Digital'),
('CH-APP',   'Aplicativo Mobile',  'Digital'),
('CH-STORE', 'Loja Física',        'Físico'),
('CH-B2B',   'Marketplace B2B',    'Parceiros');

-- ------------------------------------------------------------------------------
-- 3. Seed dim_promotion
-- ------------------------------------------------------------------------------
INSERT INTO dw.dim_promotion (promotion_id, promotion_name, discount_pct) VALUES
('PR-NONE',  'Preço Regular',              0.00),
('PR-BF',    'Black Friday & Cyber Week',  0.25),
('PR-VERAO', 'Liquidação de Verão',        0.15),
('PR-TECH',  'Semana Gamer & Tech',        0.10),
('PR-VIP',   'Clube Fidelidade VIP',       0.08),
('PR-FIRST', 'Cupom Boas-Vindas',          0.12);

-- ------------------------------------------------------------------------------
-- 4. Seed dim_store (30 stores across Brazil)
-- ------------------------------------------------------------------------------
INSERT INTO dw.dim_store (store_id, store_name, store_type, city, state, region, store_size_m2, manager_name, open_date) VALUES
('ST-001', 'Mega Store Paulista',           'Flagship',          'São Paulo',          'SP', 'Sudeste',      1500, 'Carlos Eduardo Silva',    '2018-03-15'),
('ST-002', 'Shopping Morumbi Store',        'Loja Física',       'São Paulo',          'SP', 'Sudeste',      450,  'Mariana Albuquerque',     '2019-06-20'),
('ST-003', 'Campinas Dom Pedro',            'Loja Física',       'Campinas',           'SP', 'Sudeste',      520,  'Rodrigo Fernandes',       '2020-01-10'),
('ST-004', 'BarraShopping Store',           'Flagship',          'Rio de Janeiro',     'RJ', 'Sudeste',      1200, 'Camila Nogueira',         '2018-08-01'),
('ST-005', 'Niterói Plaza',                 'Loja Física',       'Niterói',            'RJ', 'Sudeste',      380,  'Felipe Guimarães',        '2021-04-12'),
('ST-006', 'BH Shopping',                   'Flagship',          'Belo Horizonte',     'MG', 'Sudeste',      950,  'Lucas Vasconcelos',       '2019-11-25'),
('ST-007', 'Uberlândia Center',             'Loja Física',       'Uberlândia',         'MG', 'Sudeste',      400,  'Patrícia Mendes',         '2021-09-05'),
('ST-008', 'Vitória Grand Mall',            'Loja Física',       'Vitória',            'ES', 'Sudeste',      350,  'Gustavo Moreira',         '2022-02-18'),
('ST-009', 'Curitiba ParkShopping',         'Flagship',          'Curitiba',           'PR', 'Sul',          880,  'Juliana Rossi',           '2019-04-10'),
('ST-010', 'Londrina Catuaí',               'Loja Física',       'Londrina',           'PR', 'Sul',          420,  'Marcelo Fontana',         '2021-07-22'),
('ST-011', 'Porto Alegre Iguatemi',         'Flagship',          'Porto Alegre',       'RS', 'Sul',          920,  'Fernando Silveira',       '2018-10-15'),
('ST-012', 'Caxias do Sul San Pelegrino',   'Loja Física',       'Caxias do Sul',      'RS', 'Sul',          360,  'Beatriz Dornelles',       '2022-05-30'),
('ST-013', 'Florianópolis Beiramar',        'Loja Física',       'Florianópolis',      'SC', 'Sul',          480,  'Thiago Schmidt',          '2020-08-14'),
('ST-014', 'Joinville Garten Mall',         'Loja Física',       'Joinville',          'SC', 'Sul',          390,  'Vanessa Becker',          '2021-11-19'),
('ST-015', 'Brasília Park Design',          'Flagship',          'Brasília',           'DF', 'Centro-Oeste', 1100, 'André Luiz Meirelles',    '2019-02-14'),
('ST-016', 'Goiânia Flamboyant',            'Loja Física',       'Goiânia',            'GO', 'Centro-Oeste', 600,  'Renata Castro',           '2020-03-21'),
('ST-017', 'Cuiabá Pantanal Mall',          'Loja Física',       'Cuiabá',             'MT', 'Centro-Oeste', 450,  'Marcos Vinicius Barros',  '2021-10-08'),
('ST-018', 'Campo Grande Bosque',           'Loja Física',       'Campo Grande',       'MS', 'Centro-Oeste', 410,  'Aline Sampaio',           '2022-04-16'),
('ST-019', 'Salvador Shopping',             'Flagship',          'Salvador',           'BA', 'Nordeste',     1050, 'Rafael Queiroz',          '2018-12-05'),
('ST-020', 'Recife RioMar',                 'Flagship',          'Recife',             'PE', 'Nordeste',     1150, 'Fernanda Arcoverde',      '2019-07-19'),
('ST-021', 'Fortaleza Iguatemi Bosque',     'Loja Física',       'Fortaleza',          'CE', 'Nordeste',     580,  'Diego Cavalcanti',        '2020-09-11'),
('ST-022', 'Natal Midway Mall',             'Loja Física',       'Natal',              'RN', 'Nordeste',     430,  'Bruna Medeiros',          '2021-08-25'),
('ST-023', 'Maceió Parque Shopping',        'Loja Física',       'Maceió',             'AL', 'Nordeste',     370,  'Igor Tenório',            '2022-01-20'),
('ST-024', 'Manaus Manauara',               'Loja Física',       'Manaus',             'AM', 'Norte',        620,  'Larissa Pinheiro',        '2020-11-12'),
('ST-025', 'Belém Boulevard',               'Loja Física',       'Belém',              'PA', 'Norte',        510,  'Leonardo Farias',         '2021-03-08'),
('ST-026', 'Outlet SP Catarina',            'Outlet',            'São Roque',          'SP', 'Sudeste',      800,  'Priscila Duarte',         '2020-10-01'),
('ST-027', 'Outlet RJ Premium',             'Outlet',            'Duque de Caxias',    'RJ', 'Sudeste',      750,  'Leandro Goulart',         '2021-06-15'),
('ST-028', 'CD Central Cajamar',            'Centro de Distribuição', 'Cajamar',       'SP', 'Sudeste',     15000, 'Roberto Junqueira',       '2017-01-10'),
('ST-029', 'CD Nordeste Cabo',              'Centro de Distribuição', 'Cabo de Sto Agostinho','PE','Nordeste', 10000, 'Eduardo Paes',        '2019-09-01'),
('ST-030', 'CD Sul Itajaí',                 'Centro de Distribuição', 'Itajaí',        'SC', 'Sul',         12000, 'Cláudio Hering',          '2020-05-15');

-- ------------------------------------------------------------------------------
-- 5. Seed dim_product (~500 realistic tech & electronics products)
-- ------------------------------------------------------------------------------
INSERT INTO dw.dim_product (product_id, sku, product_name, category, subcategory, brand, unit_cost, list_price, product_status)
WITH product_base AS (
    SELECT 
        i,
        cat.category,
        sub.subcategory,
        br.brand,
        sub.base_cost,
        sub.base_price_mult
    FROM generate_series(1, 500) AS i
    CROSS JOIN LATERAL (
        SELECT CASE ((i - 1) % 6)
            WHEN 0 THEN 'Computadores & Notebooks'
            WHEN 1 THEN 'Smartphones & Tablets'
            WHEN 2 THEN 'Áudio & Vídeo'
            WHEN 3 THEN 'Periféricos & Acessórios'
            WHEN 4 THEN 'Eletrodomésticos Inteligentes'
            ELSE 'Wearables & Saúde'
        END AS category
    ) cat
    CROSS JOIN LATERAL (
        SELECT 
            CASE cat.category
                WHEN 'Computadores & Notebooks' THEN 
                    (ARRAY['Ultrabook Pro', 'Notebook Gamer', 'Desktop Workstation', 'Monitor 4K', 'Servidor Compacto'])[(i % 5) + 1]
                WHEN 'Smartphones & Tablets' THEN 
                    (ARRAY['Smartphone Flagship', 'Smartphone Intermediário', 'Tablet Profissional', 'Smartphone Dobrável'])[(i % 4) + 1]
                WHEN 'Áudio & Vídeo' THEN 
                    (ARRAY['Headphone Noise Cancelling', 'Soundbar Dolby Atmos', 'Caixa Bluetooth Portátil', 'Smart TV OLED', 'Microfone Condensador'])[(i % 5) + 1]
                WHEN 'Periféricos & Acessórios' THEN 
                    (ARRAY['Teclado Mecânico RGB', 'Mouse Sem Fio Ergonômico', 'Hub USB-C 8 em 1', 'Webcam 4K HDR', 'SSD NVMe 2TB'])[(i % 5) + 1]
                WHEN 'Eletrodomésticos Inteligentes' THEN 
                    (ARRAY['Aspirador Robô Laser', 'Lâmpada Inteligente Wi-Fi', 'Fechadura Digital Biométrica', 'Ar-Condicionado Inverter Smart', 'Fritadeira Airfryer Conectada'])[(i % 5) + 1]
                ELSE 
                    (ARRAY['Smartwatch Fitness', 'Smartband Tracker', 'Anel Inteligente Biométrico', 'Monitor Cardíaco Bluetooth'])[(i % 4) + 1]
            END AS subcategory,
            CASE cat.category
                WHEN 'Computadores & Notebooks' THEN (1200 + (i % 20) * 150)::numeric
                WHEN 'Smartphones & Tablets' THEN (600 + (i % 15) * 180)::numeric
                WHEN 'Áudio & Vídeo' THEN (150 + (i % 25) * 70)::numeric
                WHEN 'Periféricos & Acessórios' THEN (50 + (i % 30) * 25)::numeric
                WHEN 'Eletrodomésticos Inteligentes' THEN (220 + (i % 18) * 90)::numeric
                ELSE (90 + (i % 12) * 45)::numeric
            END AS base_cost,
            (1.40 + ((i % 10) * 0.03))::numeric AS base_price_mult
    ) sub
    CROSS JOIN LATERAL (
        SELECT 
            CASE cat.category
                WHEN 'Computadores & Notebooks' THEN (ARRAY['Dell', 'Lenovo', 'Apple', 'Asus', 'HP', 'Acer'])[(i % 6) + 1]
                WHEN 'Smartphones & Tablets' THEN (ARRAY['Apple', 'Samsung', 'Xiaomi', 'Motorola', 'Google'])[(i % 5) + 1]
                WHEN 'Áudio & Vídeo' THEN (ARRAY['Sony', 'JBL', 'Bose', 'Sennheiser', 'LG', 'Samsung'])[(i % 6) + 1]
                WHEN 'Periféricos & Acessórios' THEN (ARRAY['Logitech', 'Razer', 'Corsair', 'Kingston', 'SanDisk'])[(i % 5) + 1]
                WHEN 'Eletrodomésticos Inteligentes' THEN (ARRAY['Xiaomi', 'Philips Hue', 'Intelbras', 'iRobot', 'Electrolux'])[(i % 5) + 1]
                ELSE (ARRAY['Apple', 'Samsung', 'Garmin', 'Fitbit', 'Amazfit'])[(i % 5) + 1]
            END AS brand
    ) br
)
SELECT 
    'PRD-' || lpad(i::text, 4, '0') AS product_id,
    'SKU-' || upper(substr(brand, 1, 3)) || '-' || lpad(i::text, 4, '0') AS sku,
    brand || ' ' || subcategory || ' Mod-' || (100 + (i % 899)) AS product_name,
    category,
    subcategory,
    brand,
    ROUND(base_cost, 2) AS unit_cost,
    ROUND(base_cost * base_price_mult, 2) AS list_price,
    CASE WHEN (i % 35 = 0) THEN 'Descontinuado' ELSE 'Ativo' END AS product_status
FROM product_base;

-- ------------------------------------------------------------------------------
-- 6. Seed dim_customer (10,000 realistic customers)
-- ------------------------------------------------------------------------------
INSERT INTO dw.dim_customer (
    customer_id,
    first_name,
    last_name,
    full_name,
    gender,
    birth_date,
    age,
    age_group,
    email,
    phone,
    city,
    state,
    region,
    country,
    customer_segment
)
WITH raw_customers AS (
    SELECT
        i,
        fn.first_name,
        fn.gender,
        ln.last_name,
        loc.city,
        loc.state,
        loc.region,
        bdate.birth_date,
        bdate.age,
        seg.customer_segment
    FROM generate_series(1, 10000) AS i
    CROSS JOIN LATERAL (
        SELECT 
            CASE (i % 2)
                WHEN 0 THEN (ARRAY['Ana', 'Beatriz', 'Camila', 'Débora', 'Fernanda', 'Gabriela', 'Helena', 'Isabela', 'Juliana', 'Larissa', 'Mariana', 'Natália', 'Patrícia', 'Renata', 'Sofia', 'Tatiane', 'Vanessa', 'Bruna', 'Carolina', 'Letícia'])[(i % 20) + 1]
                ELSE (ARRAY['Alexandre', 'Bernardo', 'Carlos', 'Diego', 'Eduardo', 'Felipe', 'Gabriel', 'Henrique', 'Igor', 'João', 'Lucas', 'Marcelo', 'Nelson', 'Otávio', 'Pedro', 'Rafael', 'Rodrigo', 'Thiago', 'Vinicius', 'William'])[(i % 20) + 1]
            END AS first_name,
            CASE (i % 2) WHEN 0 THEN 'F' ELSE 'M' END AS gender
    ) fn
    CROSS JOIN LATERAL (
        SELECT (ARRAY['Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves', 'Pereira', 'Lima', 'Gomes', 'Costa', 'Ribeiro', 'Martins', 'Carvalho', 'Almeida', 'Lopes', 'Soares', 'Fernandes', 'Vieira', 'Barbosa', 'Rocha', 'Dias', 'Nascimento', 'Andrade', 'Moreira', 'Nunes', 'Marques', 'Machado', 'Mendes', 'Freitas'])[(i % 30) + 1] AS last_name
    ) ln
    CROSS JOIN LATERAL (
        SELECT 
            cities.city,
            cities.state,
            cities.region
        FROM (
            VALUES 
                ('São Paulo', 'SP', 'Sudeste'),
                ('Campinas', 'SP', 'Sudeste'),
                ('Ribeirão Preto', 'SP', 'Sudeste'),
                ('Rio de Janeiro', 'RJ', 'Sudeste'),
                ('Niterói', 'RJ', 'Sudeste'),
                ('Belo Horizonte', 'MG', 'Sudeste'),
                ('Uberlândia', 'MG', 'Sudeste'),
                ('Vitória', 'ES', 'Sudeste'),
                ('Curitiba', 'PR', 'Sul'),
                ('Londrina', 'PR', 'Sul'),
                ('Porto Alegre', 'RS', 'Sul'),
                ('Caxias do Sul', 'RS', 'Sul'),
                ('Florianópolis', 'SC', 'Sul'),
                ('Joinville', 'SC', 'Sul'),
                ('Brasília', 'DF', 'Centro-Oeste'),
                ('Goiânia', 'GO', 'Centro-Oeste'),
                ('Cuiabá', 'MT', 'Centro-Oeste'),
                ('Campo Grande', 'MS', 'Centro-Oeste'),
                ('Salvador', 'BA', 'Nordeste'),
                ('Recife', 'PE', 'Nordeste'),
                ('Fortaleza', 'CE', 'Nordeste'),
                ('Natal', 'RN', 'Nordeste'),
                ('Maceió', 'AL', 'Nordeste'),
                ('Manaus', 'AM', 'Norte'),
                ('Belém', 'PA', 'Norte')
        ) AS cities(city, state, region)
        OFFSET (i % 25) LIMIT 1
    ) loc
    CROSS JOIN LATERAL (
        SELECT 
            ('1950-01-01'::date + ((i * 123) % 19000) * '1 day'::interval)::date AS birth_date,
            (EXTRACT(YEAR FROM age('2024-01-01'::date, ('1950-01-01'::date + ((i * 123) % 19000) * '1 day'::interval)::date)))::smallint AS age
    ) bdate
    CROSS JOIN LATERAL (
        SELECT 
            CASE 
                WHEN (i % 10 < 7) THEN 'Varejo'
                WHEN (i % 10 < 9) THEN 'Corporativo'
                ELSE 'Pequenas Empresas'
            END AS customer_segment
    ) seg
)
SELECT
    'CUST-' || lpad(i::text, 6, '0') AS customer_id,
    first_name,
    last_name,
    first_name || ' ' || last_name AS full_name,
    gender,
    birth_date,
    age,
    CASE 
        WHEN age < 26 THEN '18-25'
        WHEN age < 36 THEN '26-35'
        WHEN age < 51 THEN '36-50'
        ELSE '51+'
    END AS age_group,
    lower(first_name) || '.' || lower(last_name) || i::text || '@email.com.br' AS email,
    '+55 (' || (11 + (i % 80)) || ') 9' || lpad((10000000 + (i * 73) % 89999999)::text, 8, '0') AS phone,
    city,
    state,
    region,
    'Brasil' AS country,
    customer_segment
FROM raw_customers;
