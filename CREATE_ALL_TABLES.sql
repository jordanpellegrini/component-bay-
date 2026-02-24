-- =============================================
-- CRÉATION TABLES - Components Bay V5
-- Toutes les tables pour tous les modules
-- Exécuter dans Supabase > SQL Editor
-- =============================================
-- Approche: colonnes id + timestamps + JSONB data
-- Cela permet de stocker n'importe quel champ
-- sans erreur de colonne manquante

-- TABLE EFS
CREATE TABLE IF NOT EXISTS efs (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE LIFERAFTS
CREATE TABLE IF NOT EXISTS liferafts (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE WHEELS
CREATE TABLE IF NOT EXISTS wheels (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE MAINTENANCE
CREATE TABLE IF NOT EXISTS maintenance (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE COMPOSITE
CREATE TABLE IF NOT EXISTS composite (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE AVIONIC
CREATE TABLE IF NOT EXISTS avionic (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE TROOP SEATS
CREATE TABLE IF NOT EXISTS troopseats (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE DOCUMENTS
CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- DÉSACTIVER RLS SUR TOUTES LES TABLES
ALTER TABLE efs DISABLE ROW LEVEL SECURITY;
ALTER TABLE liferafts DISABLE ROW LEVEL SECURITY;
ALTER TABLE wheels DISABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance DISABLE ROW LEVEL SECURITY;
ALTER TABLE composite DISABLE ROW LEVEL SECURITY;
ALTER TABLE avionic DISABLE ROW LEVEL SECURITY;
ALTER TABLE troopseats DISABLE ROW LEVEL SECURITY;
ALTER TABLE documents DISABLE ROW LEVEL SECURITY;

-- VÉRIFICATION : lister toutes les tables public
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
