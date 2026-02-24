-- Table pour stocker l'historique des tags générés
CREATE TABLE IF NOT EXISTS generated_tags (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activer RLS
ALTER TABLE generated_tags ENABLE ROW LEVEL SECURITY;

-- Politique : tout le monde peut lire/écrire
CREATE POLICY "Allow all on generated_tags" ON generated_tags
    FOR ALL USING (true) WITH CHECK (true);

-- Index pour recherche rapide
CREATE INDEX idx_generated_tags_data ON generated_tags USING GIN (data);
