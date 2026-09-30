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
GRANT USAGE ON SCHEMA dw TO pbi_user;
GRANT USAGE ON SCHEMA public TO pbi_user;

-- Grant read-only access to all existing tables and views in schema dw
GRANT SELECT ON ALL TABLES IN SCHEMA dw TO pbi_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO pbi_user;

-- Ensure future tables and views in schema dw will also be readable
ALTER DEFAULT PRIVILEGES IN SCHEMA dw GRANT SELECT ON TABLES TO pbi_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO pbi_user;

-- Set search_path for pbi_user
ALTER ROLE pbi_user SET search_path TO dw, public;
