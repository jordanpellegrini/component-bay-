# 📦 Components Bay - Backup Scripts

## 📁 Contenu

| Fichier | Description |
|---------|-------------|
| `RUN_BACKUP.bat` | Lance un backup manuellement (double-cliquez) |
| `INSTALL_WEEKLY_BACKUP.bat` | Installe le backup automatique chaque Dimanche 20h (exécuter 1 seule fois en admin) |
| `backup-components-bay.ps1` | Script PowerShell principal (ne pas modifier sauf configuration) |

## 🚀 Installation

### Backup Manuel
1. Copiez le dossier `backup-scripts` où vous voulez sur votre PC
2. Double-cliquez sur `RUN_BACKUP.bat` quand vous voulez faire un backup

### Backup Automatique (chaque semaine)
1. Clic droit sur `INSTALL_WEEKLY_BACKUP.bat` → **Exécuter en tant qu'administrateur**
2. C'est tout ! Le backup se fera automatiquement chaque **Dimanche à 20h00**

## 📂 Où sont les backups ?

```
C:\Users\VOTRE_NOM\Documents\ComponentsBay_Backups\
├── Backup_2026-02-25_20h00\
│   ├── data\
│   │   ├── efs.json
│   │   ├── wheel.json
│   │   ├── maintenance.json
│   │   ├── generated_tags.json
│   │   ├── pn_manufacturers.json
│   │   └── ...
│   ├── pdfs\
│   │   ├── LH_FWD_EFS_745_Serviceable.pdf
│   │   └── ...
│   └── backup-info.json
├── Backup_2026-03-04_20h00\
│   └── ...
```

## 🧹 Nettoyage automatique
Le script garde les **12 derniers backups** (≈ 3 mois) et supprime les plus anciens automatiquement.

## ⚙️ Configuration
Modifiez le fichier `backup-components-bay.ps1` pour changer :
- `$BACKUP_ROOT` : dossier de destination des backups
- Le nombre de backups conservés (ligne `Select-Object -Skip 12`)
