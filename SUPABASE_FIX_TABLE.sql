-- =============================================
-- FIX TABLE USERS - Components Bay V5
-- =============================================
-- Exécuter ce script dans Supabase > SQL Editor
-- Il vérifie et ajoute les colonnes manquantes

-- Vérifier si la table users existe, sinon la créer
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    password TEXT NOT NULL,
    first_name TEXT DEFAULT '',
    last_name TEXT DEFAULT '',
    role TEXT DEFAULT 'user',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Si la table existe déjà mais avec firstName au lieu de first_name,
-- renommer les colonnes :
DO $$
BEGIN
    -- Renommer firstName → first_name si elle existe
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'firstname'
    ) THEN
        ALTER TABLE users RENAME COLUMN "firstName" TO first_name;
        RAISE NOTICE 'Renamed firstName to first_name';
    END IF;

    -- Renommer lastName → last_name si elle existe
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'lastname'
    ) THEN
        ALTER TABLE users RENAME COLUMN "lastName" TO last_name;
        RAISE NOTICE 'Renamed lastName to last_name';
    END IF;

    -- Ajouter first_name si elle n'existe pas du tout
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'first_name'
    ) THEN
        ALTER TABLE users ADD COLUMN first_name TEXT DEFAULT '';
        RAISE NOTICE 'Added first_name column';
    END IF;

    -- Ajouter last_name si elle n'existe pas du tout
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'last_name'
    ) THEN
        ALTER TABLE users ADD COLUMN last_name TEXT DEFAULT '';
        RAISE NOTICE 'Added last_name column';
    END IF;
END $$;

-- Désactiver RLS pour simplifier (ou configurer des policies)
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- Vérification finale
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'users' ORDER BY ordinal_position;
