# ============================================================
# Components Bay - Weekly Auto Backup Script (Windows)
# Output: ZIP file in Documents\ComponentsBay_Backups\
# ============================================================

# --- CONFIGURATION ---
$SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"

$BACKUP_ROOT = "$env:USERPROFILE\Documents\ComponentsBay_Backups"

$TABLES = @("efs", "liferafts", "wheels", "maintenance", "composite", "avionic", "troopseats", "engine", "rotorbay", "iafteaft", "pol", "tools", "users", "documents", "generated_tags", "pn_manufacturers")

# --- NE PAS MODIFIER EN DESSOUS ---

$DATE = Get-Date -Format "yyyy-MM-dd_HHhmm"
$TEMP_DIR = "$env:TEMP\ComponentsBay_Backup_$DATE"
$ZIP_NAME = "ComponentsBay_Backup_$DATE.zip"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Components Bay - Backup" -ForegroundColor Cyan
Write-Host "  $DATE" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Creer les dossiers temporaires
New-Item -ItemType Directory -Force -Path $BACKUP_ROOT | Out-Null
New-Item -ItemType Directory -Force -Path "$TEMP_DIR\data" | Out-Null
New-Item -ItemType Directory -Force -Path "$TEMP_DIR\pdfs" | Out-Null

$headers = @{
    "apikey" = $SUPABASE_KEY
    "Authorization" = "Bearer $SUPABASE_KEY"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

$totalItems = 0
$successTables = 0

# Function to load all rows with pagination (Supabase limit = 1000)
function Load-AllRows {
    param($tableName)
    $allRows = @()
    $offset = 0
    $pageSize = 1000
    $hasMore = $true
    
    while ($hasMore) {
        $url = "$SUPABASE_URL/rest/v1/$tableName" + "?select=*&offset=$offset&limit=$pageSize"
        $page = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        
        if ($page -is [array]) {
            $allRows += $page
            if ($page.Count -lt $pageSize) {
                $hasMore = $false
            }
            else {
                $offset += $pageSize
            }
        }
        else {
            if ($page) { $allRows += $page }
            $hasMore = $false
        }
    }
    return $allRows
}

foreach ($table in $TABLES) {
    Write-Host "  Loading $table..." -NoNewline
    try {
        $response = Load-AllRows -tableName $table
        
        $items = @()
        foreach ($row in $response) {
            if ($row.data) {
                $item = $row.data
                if ($item -is [string]) {
                    $item = $item | ConvertFrom-Json
                }
                $items += $item
            }
            else {
                $items += $row
            }
        }
        
        $count = $items.Count
        $totalItems += $count
        
        if ($count -gt 0) {
            $json = $items | ConvertTo-Json -Depth 20 -Compress
            [System.IO.File]::WriteAllText("$TEMP_DIR\data\$table.json", $json, [System.Text.Encoding]::UTF8)
        }
        
        Write-Host " OK - $count items" -ForegroundColor Green
        $successTables++
    }
    catch {
        $errMsg = $_.Exception.Message
        if ($errMsg -match "404") {
            Write-Host " SKIP - table not created yet" -ForegroundColor Yellow
        }
        else {
            Write-Host " ERROR: $errMsg" -ForegroundColor Red
        }
    }
}

# Extraire les PDFs depuis generated_tags
Write-Host ""
Write-Host "  Extracting PDF tags..." -NoNewline
try {
    $tagsFile = "$TEMP_DIR\data\generated_tags.json"
    if (Test-Path $tagsFile) {
        $tagsContent = [System.IO.File]::ReadAllText($tagsFile, [System.Text.Encoding]::UTF8)
        $tags = $tagsContent | ConvertFrom-Json
        $pdfCount = 0
        foreach ($tag in $tags) {
            if ($tag.pdfBase64) {
                $filename = $tag.filename
                if (-not $filename) { $filename = "tag_$($tag.id).pdf" }
                $bytes = [Convert]::FromBase64String($tag.pdfBase64)
                [System.IO.File]::WriteAllBytes("$TEMP_DIR\pdfs\$filename", $bytes)
                $pdfCount++
            }
        }
        Write-Host " OK - $pdfCount PDFs" -ForegroundColor Green
    }
    else {
        Write-Host " No tags file found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# Metadata
$metaObj = @{
    backupDate = (Get-Date).ToString("o")
    backupType = "automatic"
    totalItems = $totalItems
    tablesBackedUp = $successTables
    totalTables = $TABLES.Count
    version = "Components Bay V5.1"
}
$metaJson = $metaObj | ConvertTo-Json
[System.IO.File]::WriteAllText("$TEMP_DIR\backup-info.json", $metaJson, [System.Text.Encoding]::UTF8)

# Creer le ZIP
Write-Host ""
Write-Host "  Creating ZIP file..." -NoNewline
$ZIP_PATH = "$BACKUP_ROOT\$ZIP_NAME"
try {
    if (Test-Path $ZIP_PATH) { Remove-Item $ZIP_PATH -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($TEMP_DIR, $ZIP_PATH, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    Write-Host " OK" -ForegroundColor Green
}
catch {
    # Fallback: Compress-Archive
    try {
        Compress-Archive -Path "$TEMP_DIR\*" -DestinationPath $ZIP_PATH -Force
        Write-Host " OK (fallback)" -ForegroundColor Green
    }
    catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Supprimer le dossier temporaire
Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue

# Taille du ZIP
$zipSize = (Get-Item $ZIP_PATH).Length
$sizeMB = [math]::Round($zipSize / 1MB, 1)

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Backup Complete!" -ForegroundColor Green
Write-Host "  File: $ZIP_PATH" -ForegroundColor Green
Write-Host "  Size: $sizeMB MB" -ForegroundColor Green
Write-Host "  Total: $totalItems items" -ForegroundColor Green
Write-Host "  Tables: $successTables / $($TABLES.Count)" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# Nettoyage: garder seulement les 12 derniers backups ZIP
$allBackups = Get-ChildItem -Path $BACKUP_ROOT -Filter "*.zip" | Sort-Object Name -Descending
if ($allBackups.Count -gt 12) {
    Write-Host ""
    Write-Host "  Cleaning old backups (keeping last 12)..." -ForegroundColor Yellow
    $toRemove = $allBackups | Select-Object -Skip 12
    foreach ($old in $toRemove) {
        Write-Host "    Removing $($old.Name)..." -ForegroundColor DarkGray
        Remove-Item -Path $old.FullName -Force
    }
}

Write-Host ""
Write-Host "Done! Press any key to close..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
