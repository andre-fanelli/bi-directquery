-- ==============================================================================
-- 05_security_roles.sql
-- Enterprise Security: Dedicated Read-Only User for Power BI DirectQuery
-- ==============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'pbi_user') THEN
        CREATE ROLE pbi_user WITH LOGIN PASSWORD 'pbi_pass_123';
    ELSE
        ALTER ROLE pbi_user WITH PASSWORD 'pbi_pass_123';
    END IF;
END
$$;

-- Grant access to schemas
GRANT USAGE, CREATE ON SCHEMA dw TO pbi_user;
GRANT USAGE, CREATE ON SCHEMA public TO pbi_user;

-- Grant full access to all existing tables, views, and sequences in schema dw
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA dw TO pbi_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA dw TO pbi_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO pbi_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO pbi_user;

-- Ensure future tables and sequences in schema dw will also have full access
ALTER DEFAULT PRIVILEGES IN SCHEMA dw GRANT ALL PRIVILEGES ON TABLES TO pbi_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA dw GRANT ALL PRIVILEGES ON SEQUENCES TO pbi_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO pbi_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO pbi_user;

-- Set search_path for pbi_user
ALTER ROLE pbi_user SET search_path TO dw, public;
