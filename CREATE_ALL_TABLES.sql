-- =============================================
-- CREATION TABLES - Components Bay V5.1
-- Toutes les tables pour tous les modules
-- Executer dans Supabase > SQL Editor
-- =============================================

-- TABLE EFS
CREATE TABLE IF NOT EXISTS efs (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE LIFERAFTS
CREATE TABLE IF NOT EXISTS liferafts (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE WHEELS
CREATE TABLE IF NOT EXISTS wheels (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE MAINTENANCE
CREATE TABLE IF NOT EXISTS maintenance (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE COMPOSITE
CREATE TABLE IF NOT EXISTS composite (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE AVIONIC
CREATE TABLE IF NOT EXISTS avionic (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE TROOP SEATS
CREATE TABLE IF NOT EXISTS troopseats (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE ENGINE
CREATE TABLE IF NOT EXISTS engine (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE ROTOR BAY
CREATE TABLE IF NOT EXISTS rotorbay (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE IAFT/EAFT
CREATE TABLE IF NOT EXISTS iafteaft (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE POL
CREATE TABLE IF NOT EXISTS pol (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE TOOLS
CREATE TABLE IF NOT EXISTS tools (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE DOCUMENTS
CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE USERS
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE GENERATED TAGS
CREATE TABLE IF NOT EXISTS generated_tags (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE P/N MANUFACTURERS
CREATE TABLE IF NOT EXISTS pn_manufacturers (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ENABLE RLS but allow all operations (public access with anon key)
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN SELECT unnest(ARRAY['efs','liferafts','wheels','maintenance','composite','avionic','troopseats','engine','rotorbay','iafteaft','pol','tools','documents','users','generated_tags','pn_manufacturers'])
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('DROP POLICY IF EXISTS "Allow all on %s" ON %I', t, t);
        EXECUTE format('CREATE POLICY "Allow all on %s" ON %I FOR ALL USING (true) WITH CHECK (true)', t, t);
    END LOOP;
END $$;

-- VERIFICATION
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
