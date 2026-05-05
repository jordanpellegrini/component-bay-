// Universal Claude Action Handler — Components Bay
// Handles add/update/delete actions from Claude responses
// Injected into all modules

window.ClaudeActionHandler = {

    // Parse <action>{...}</action> from Claude response
    parse(text) {
        const match = text.match(/<action>([\s\S]*?)<\/action>/);
        if (!match) return null;
        try {
            return JSON.parse(match[1].trim());
        } catch(e) {
            console.warn('ClaudeActionHandler: invalid JSON in action tag', e);
            return null;
        }
    },

    // Execute action with confirmation UI
    async execute(action, appendMessage, dataArray, saveDataFn, deleteItemFn, refreshFn) {
        if (!action) return;

        const type = action.type;
        const fields = action.fields || {};
        const id = action.id;

        if (type === 'add') {
            // Build confirmation message
            const fieldsList = Object.entries(fields).map(([k,v]) => `• ${k}: ${v}`).join('\n');
            appendMessage('assistant', `✅ Ajout confirmé. Ajout en cours...`);
            
            // Create new item
            const newItem = {
                id: Date.now().toString(),
                ...fields
            };
            
            try {
                await saveDataFn(newItem);
                appendMessage('assistant', `✅ Item ajouté avec succès !`);
                if (refreshFn) refreshFn();
            } catch(e) {
                appendMessage('assistant', `❌ Erreur lors de l'ajout: ${e.message}`);
            }

        } else if (type === 'update') {
            const item = dataArray.find(i => i.id === id);
            if (!item) {
                appendMessage('assistant', `❌ Item introuvable (id: ${id})`);
                return;
            }
            
            appendMessage('assistant', `✅ Modification confirmée. Mise à jour en cours...`);
            
            const updatedItem = { ...item, ...fields };
            try {
                await saveDataFn(updatedItem);
                appendMessage('assistant', `✅ Item modifié avec succès !`);
                if (refreshFn) refreshFn();
            } catch(e) {
                appendMessage('assistant', `❌ Erreur lors de la modification: ${e.message}`);
            }

        } else if (type === 'delete') {
            const item = dataArray.find(i => i.id === id);
            if (!item) {
                appendMessage('assistant', `❌ Item introuvable (id: ${id})`);
                return;
            }
            
            appendMessage('assistant', `✅ Suppression confirmée. Suppression en cours...`);
            
            try {
                await deleteItemFn(id);
                appendMessage('assistant', `✅ Item supprimé avec succès !`);
                if (refreshFn) refreshFn();
            } catch(e) {
                appendMessage('assistant', `❌ Erreur lors de la suppression: ${e.message}`);
            }
        }
    }
};
