# ==============================================================================
# Dockerfile - Custom PostgreSQL 16 Alpine Image for Power BI DirectQuery DW
# ==============================================================================
FROM postgres:16-alpine

LABEL maintainer="Power BI DW Project"
LABEL description="PostgreSQL 16 Alpine customized for Star Schema DirectQuery Analytics"

# Install timezone data for America/Sao_Paulo
RUN apk add --no-cache tzdata
ENV TZ=America/Sao_Paulo

# Copy custom postgresql.conf optimized for analytical queries
COPY config/postgresql.conf /etc/postgresql/postgresql.conf

# Copy Star Schema initialization and seed scripts
# PostgreSQL automatically executes .sql scripts in alphabetical order upon initial DB creation
COPY sql/01_init_schema.sql       /docker-entrypoint-initdb.d/01_init_schema.sql
COPY sql/02_seed_dimensions.sql   /docker-entrypoint-initdb.d/02_seed_dimensions.sql
COPY sql/03_seed_facts.sql        /docker-entrypoint-initdb.d/03_seed_facts.sql
COPY sql/04_create_views.sql      /docker-entrypoint-initdb.d/04_create_views.sql
COPY sql/05_security_roles.sql    /docker-entrypoint-initdb.d/05_security_roles.sql

# Expose default PostgreSQL port
EXPOSE 5432

# Health check to ensure PostgreSQL is ready to receive queries
HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=30s \
  CMD pg_isready -U postgres -d ${POSTGRES_DB:-dw_sales} || exit 1

# Launch PostgreSQL with the custom configuration file
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
