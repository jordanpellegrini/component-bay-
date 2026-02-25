-- Table pour stocker l'historique des tags générés
CREATE TABLE IF NOT EXISTS generated_tags (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE generated_tags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all on generated_tags" ON generated_tags;
CREATE POLICY "Allow all on generated_tags" ON generated_tags
    FOR ALL USING (true) WITH CHECK (true);
CREATE INDEX IF NOT EXISTS idx_generated_tags_data ON generated_tags USING GIN (data);

-- Table pour le mapping P/N → Manufacturer
CREATE TABLE IF NOT EXISTS pn_manufacturers (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE pn_manufacturers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all on pn_manufacturers" ON pn_manufacturers;
CREATE POLICY "Allow all on pn_manufacturers" ON pn_manufacturers
    FOR ALL USING (true) WITH CHECK (true);
CREATE INDEX IF NOT EXISTS idx_pn_manufacturers_data ON pn_manufacturers USING GIN (data);
