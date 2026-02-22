// Configuration Supabase pour Components Bay V5
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// VOS VRAIES CLÉS SUPABASE
const supabaseUrl = 'https://nwidtkiteamvnomewjux.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI'

const supabase = createClient(supabaseUrl, supabaseKey)

// Helper Functions pour Components Bay
window.ComponentsBayDB = {
    // Tables mapping
    tables: {
        users: 'users',
        efs: 'efs',
        liferafts: 'liferafts',
        wheels: 'wheels',
        maintenance: 'maintenance',
        composite: 'composite',
        avionic: 'avionic',
        troopseats: 'troopseats',
        documents: 'documents'
    },

    // Tables avec colonnes directes (pas JSONB)
    flatTables: ['users'],

    // Convertir camelCase en snake_case pour PostgreSQL
    toSnakeCase(obj) {
        const result = {};
        for (const [key, value] of Object.entries(obj)) {
            const snakeKey = key.replace(/([A-Z])/g, '_$1').toLowerCase();
            result[snakeKey] = value;
        }
        return result;
    },

    // Convertir snake_case en camelCase pour le JS
    toCamelCase(obj) {
        const result = {};
        for (const [key, value] of Object.entries(obj)) {
            const camelKey = key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
            result[camelKey] = value;
        }
        return result;
    },

    // Sauvegarder dans Supabase
    async save(tableName, data) {
        try {
            // Générer ID si pas présent
            if (!data.id) {
                data.id = Date.now().toString();
            }

            const now = new Date().toISOString();
            let dbRecord;

            if (this.flatTables.includes(tableName)) {
                // TABLE USERS : colonnes directes avec snake_case
                data.updated_at = now;
                if (!data.created_at) data.created_at = now;
                dbRecord = this.toSnakeCase(data);
            } else {
                // AUTRES TABLES : JSONB (id + data + timestamps)
                const { id, created_at, updated_at, ...rest } = data;
                dbRecord = {
                    id: data.id,
                    data: rest,
                    created_at: data.created_at || now,
                    updated_at: now
                };
            }

            console.log(`📤 Saving to ${tableName}:`, dbRecord.id);

            const { data: result, error } = await supabase
                .from(tableName)
                .upsert(dbRecord)
                .select()
                .single();

            if (error) {
                console.error(`❌ Supabase save error (${tableName}):`, error);
                throw error;
            }

            // Reconvertir pour le retour
            let returnData;
            if (this.flatTables.includes(tableName)) {
                returnData = this.toCamelCase(result);
            } else {
                returnData = {
                    id: result.id,
                    ...result.data,
                    created_at: result.created_at,
                    updated_at: result.updated_at
                };
            }

            console.log(`✅ Saved to ${tableName}:`, returnData.id);
            return returnData;

        } catch (error) {
            console.error(`💥 Save failed (${tableName}):`, error.message);
            
            // Fallback to localStorage
            const localKey = `componentsBay${tableName}`;
            let localData = JSON.parse(localStorage.getItem(localKey) || '[]');
            
            const existingIndex = localData.findIndex(item => item.id === data.id);
            if (existingIndex >= 0) {
                localData[existingIndex] = data;
            } else {
                localData.push(data);
            }
            
            localStorage.setItem(localKey, JSON.stringify(localData));
            console.log(`💾 Fallback: Saved to localStorage (${tableName})`);
            return data;
        }
    },

    // Charger depuis Supabase
    async load(tableName) {
        try {
            console.log(`📥 Loading from ${tableName}...`);

            const { data, error } = await supabase
                .from(tableName)
                .select('*')
                .order('created_at', { ascending: false });

            if (error) {
                console.error(`❌ Supabase load error (${tableName}):`, error);
                throw error;
            }

            console.log(`✅ Loaded ${data.length} items from ${tableName}`);

            // Reconvertir selon le type de table
            let items;
            if (this.flatTables.includes(tableName)) {
                items = data.map(item => this.toCamelCase(item));
            } else {
                items = data.map(row => ({
                    id: row.id,
                    ...(row.data || {}),
                    created_at: row.created_at,
                    updated_at: row.updated_at
                }));
            }
            
            // Sync to localStorage for offline access
            const localKey = `componentsBay${tableName}`;
            localStorage.setItem(localKey, JSON.stringify(items));
            
            return items || [];

        } catch (error) {
            console.error(`💥 Load failed (${tableName}):`, error.message);
            
            // Fallback to localStorage
            const localKey = `componentsBay${tableName}`;
            const localData = JSON.parse(localStorage.getItem(localKey) || '[]');
            console.log(`💾 Fallback: Loaded ${localData.length} items from localStorage (${tableName})`);
            return localData;
        }
    },

    // Bulk insert to Supabase (for import)
    async bulkSave(tableName, items) {
        try {
            const now = new Date().toISOString();
            const records = items.map(item => {
                const { id, created_at, updated_at, ...rest } = item;
                return {
                    id: item.id,
                    data: rest,
                    created_at: now,
                    updated_at: now
                };
            });

            // Insert in batches of 50 to avoid request size limits
            let inserted = 0;
            for (let i = 0; i < records.length; i += 50) {
                const batch = records.slice(i, i + 50);
                const { error } = await supabase
                    .from(tableName)
                    .upsert(batch, { onConflict: 'id' });

                if (error) {
                    console.error(`❌ Bulk save batch error (${tableName}):`, error);
                } else {
                    inserted += batch.length;
                }
            }
            
            console.log(`✅ Bulk saved ${inserted}/${items.length} to ${tableName}`);
            return inserted;
        } catch (error) {
            console.error(`💥 Bulk save failed (${tableName}):`, error.message);
            return 0;
        }
    },

    // Bulk delete from Supabase (for import replace)
    async bulkDelete(tableName) {
        try {
            const { error } = await supabase
                .from(tableName)
                .delete()
                .neq('id', '___never_match___');

            if (error) {
                console.error(`❌ Bulk delete error (${tableName}):`, error);
            } else {
                console.log(`✅ Bulk deleted all from ${tableName}`);
            }
        } catch (error) {
            console.error(`💥 Bulk delete failed (${tableName}):`, error.message);
        }
    },

    // Supprimer de Supabase
    async delete(tableName, id) {
        try {
            console.log(`🗑️ Deleting from ${tableName}:`, id);

            const { error } = await supabase
                .from(tableName)
                .delete()
                .eq('id', id);

            if (error) {
                console.error(`❌ Supabase delete error (${tableName}):`, error);
                throw error;
            }

            console.log(`✅ Deleted from ${tableName}:`, id);
            
            // Also remove from localStorage
            const localKey = `componentsBay${tableName}`;
            let localData = JSON.parse(localStorage.getItem(localKey) || '[]');
            localData = localData.filter(item => item.id !== id);
            localStorage.setItem(localKey, JSON.stringify(localData));

        } catch (error) {
            console.error(`💥 Delete failed (${tableName}):`, error.message);
            
            // Fallback: remove from localStorage only
            const localKey = `componentsBay${tableName}`;
            let localData = JSON.parse(localStorage.getItem(localKey) || '[]');
            localData = localData.filter(item => item.id !== id);
            localStorage.setItem(localKey, JSON.stringify(localData));
            console.log(`💾 Fallback: Removed from localStorage (${tableName})`);
        }
    },

    // Upload PDF vers Supabase Storage
    async uploadPDF(file) {
        try {
            const fileName = `${Date.now()}_${file.name}`;
            const filePath = `pdfs/${fileName}`;

            console.log('📎 Uploading PDF to Supabase Storage...');

            const { data, error } = await supabase.storage
                .from('documents')
                .upload(filePath, file);

            if (error) {
                console.error('❌ Supabase storage error:', error);
                throw error;
            }

            // Get public URL
            const { data: urlData } = supabase.storage
                .from('documents')
                .getPublicUrl(filePath);

            console.log('✅ PDF uploaded successfully to Supabase Storage');

            return {
                fileName: fileName,
                originalName: file.name,
                downloadURL: urlData.publicUrl,
                size: file.size,
                path: filePath
            };

        } catch (error) {
            console.error('💥 PDF upload failed:', error.message);
            
            // Fallback to base64 in localStorage
            return new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = function(e) {
                    console.log('💾 Fallback: PDF saved as base64 in localStorage');
                    resolve({
                        fileName: file.name,
                        originalName: file.name,
                        downloadURL: e.target.result,
                        size: file.size,
                        isBase64: true
                    });
                };
                reader.onerror = reject;
                reader.readAsDataURL(file);
            });
        }
    }
};

// Initialiser la connexion
console.log('🔥 Supabase connection initialized for Components Bay');
console.log('📊 Database URL:', supabaseUrl);
console.log('✅ Ready for full database integration!');
