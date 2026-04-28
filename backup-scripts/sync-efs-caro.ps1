# ============================================================
# Components Bay - EFS Auto-Sync from C.A.R.O.
# Reads CARO Excel (READ-ONLY) and updates EFS in Supabase
# Schedule: Every Wednesday at 12:00
# ============================================================

# --- CONFIGURATION ---
$SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"

# Chemin du fichier CARO (LECTURE SEULE - jamais modifie)
$CARO_FILE = "C:\Users\jpellegrini\Desktop\APP 5.5\CARO update\C.A.R.O. 2.6.1.xlsm"
$SHEET_NAME = "full plan"

# P/N EFS a filtrer (insensible a la casse)
$EFS_PN_LIST = @(
    "S956A20A1004",
    "S956A20A1005",
    "S956A20A1006",
    "S956A20A1007",
    "S956A20A1013",
    "S956A20A1014"
)

# Mapping P/N -> Designation
$EFS_DESIGNATIONS = @{
    "S956A20A1004" = "LH FWD EFS"
    "S956A20A1005" = "RH FWD EFS"
    "S956A20A1006" = "LH AFT EFS"
    "S956A20A1013" = "LH AFT EFS"
    "S956A20A1007" = "RH AFT EFS"
    "S956A20A1014" = "RH AFT EFS"
}

# Log file
$LOG_DIR = "$env:USERPROFILE\Documents\ComponentsBay_Backups"
$LOG_FILE = "$LOG_DIR\efs_sync_log.txt"

# --- NE PAS MODIFIER EN DESSOUS ---

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] $Message"
    Write-Host $logLine -ForegroundColor $Color
    Add-Content -Path $LOG_FILE -Value $logLine -Encoding UTF8
}

# Header
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  EFS Auto-Sync from C.A.R.O." -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Create log directory
New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
Write-Log "--- EFS Sync Started ---" "Cyan"

# ============================================================
# STEP 1: Check CARO file exists
# ============================================================
if (-not (Test-Path $CARO_FILE)) {
    Write-Log "ERREUR: Fichier CARO introuvable: $CARO_FILE" "Red"
    Write-Log "--- Sync Aborted ---" "Red"
    pause
    exit 1
}
Write-Log "Fichier CARO trouve: $CARO_FILE" "Green"

# ============================================================
# STEP 2: Open Excel in READ-ONLY mode
# ============================================================
Write-Log "Ouverture Excel en LECTURE SEULE..." "Yellow"

$excel = $null
$workbook = $null

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    
    # Open READ-ONLY (3rd parameter = Format, 4th = Password, 5th = WriteResPassword)
    # ReadOnly = $true (parameter after filename)
    $workbook = $excel.Workbooks.Open($CARO_FILE, 0, $true)
    
    # Find the sheet
    $sheet = $null
    foreach ($ws in $workbook.Worksheets) {
        if ($ws.Name -eq $SHEET_NAME) {
            $sheet = $ws
            break
        }
    }
    
    if (-not $sheet) {
        Write-Log "ERREUR: Onglet '$SHEET_NAME' introuvable!" "Red"
        $workbook.Close($false)
        $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        pause
        exit 1
    }
    
    Write-Log "Onglet '$SHEET_NAME' ouvert" "Green"

    # ============================================================
    # STEP 3: Find column positions from header row
    # ============================================================
    $lastCol = $sheet.UsedRange.Columns.Count
    $lastRow = $sheet.UsedRange.Rows.Count
    Write-Log "Plage: $lastRow lignes x $lastCol colonnes"
    
    $colPN = -1
    $colSN = -1
    $colTask = -1
    $colDueDate = -1
    $colHC = -1
    $colDMC = -1
    
    # Scan header row (row 1)
    for ($c = 1; $c -le $lastCol; $c++) {
        $header = $sheet.Cells(1, $c).Text.Trim().ToUpper()
        switch ($header) {
            "PN"       { $colPN = $c }
            "SN"       { $colSN = $c }
            "TASK"     { $colTask = $c }
            "DUE DATE" { $colDueDate = $c }
            "H/C"      { $colHC = $c }
            "DMC"      { $colDMC = $c }
        }
    }
    
    if ($colPN -eq -1 -or $colSN -eq -1 -or $colTask -eq -1 -or $colDueDate -eq -1) {
        Write-Log "ERREUR: Colonnes manquantes! PN=$colPN SN=$colSN Task=$colTask DueDate=$colDueDate" "Red"
        $workbook.Close($false)
        $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        pause
        exit 1
    }
    
    Write-Log "Colonnes: PN=$colPN, SN=$colSN, Task=$colTask, DueDate=$colDueDate, DMC=$colDMC" "Gray"

    # ============================================================
    # STEP 4: Read and filter EFS rows
    # ============================================================
    Write-Log "Lecture des donnees EFS..." "Yellow"
    
    # Structure: key = "PN|SN" -> { pn, sn, hc, next18M, next36M }
    $efsItems = @{}
    $rowsRead = 0
    $rowsFiltered = 0
    
    for ($r = 2; $r -le $lastRow; $r++) {
        $pn = $sheet.Cells($r, $colPN).Text.Trim().ToUpper()
        
        # Skip if not in EFS P/N list
        if ($EFS_PN_LIST -notcontains $pn) { continue }
        
        $task = $sheet.Cells($r, $colTask).Text.Trim()
        
        # Skip OTL lines
        if ($task -match "OTL") { 
            $rowsFiltered++
            continue 
        }
        
        $snRaw = $sheet.Cells($r, $colSN).Text.Trim()
        $dueDateRaw = $sheet.Cells($r, $colDueDate).Text.Trim()
        $hc = if ($colHC -gt 0) { $sheet.Cells($r, $colHC).Text.Trim() } else { "" }
        $dmc = if ($colDMC -gt 0) { $sheet.Cells($r, $colDMC).Text.Trim() } else { "" }
        
        # Split multiple S/N in same cell (separated by spaces, commas, slashes, newlines)
        $snList = $snRaw -split '[\s,/\r\n]+' | Where-Object { $_ -ne '' }
        
        # Parse Due Date (format: DD-MM-YY or DD-MM-YYYY or DD/MM/YY)
        $dueDate = ""
        if ($dueDateRaw) {
            try {
                $parsedDate = $null
                $formats = @("dd-MM-yy", "dd-MM-yyyy", "dd/MM/yy", "dd/MM/yyyy", "yyyy-MM-dd")
                foreach ($fmt in $formats) {
                    try {
                        $parsedDate = [DateTime]::ParseExact($dueDateRaw, $fmt, [System.Globalization.CultureInfo]::InvariantCulture)
                        # Force 21st century if 2-digit year was used (e.g. "26" -> 2026 not 1926)
                        if ($parsedDate.Year -lt 2000) {
                            $parsedDate = $parsedDate.AddYears(100)
                        }
                        break
                    } catch { continue }
                }
                if (-not $parsedDate) {
                    $parsedDate = [DateTime]::Parse($dueDateRaw)
                    if ($parsedDate.Year -lt 2000) { $parsedDate = $parsedDate.AddYears(100) }
                }
                $dueDate = $parsedDate.ToString("yyyy-MM-dd")
            } catch {
                Write-Log "  WARN: Date non parsee row $r : '$dueDateRaw'" "Yellow"
                $dueDate = ""
            }
        }
        
        # Process each S/N separately
        foreach ($sn in $snList) {
        $key = "$pn|$sn"
        
        # Create entry if first time seeing this P/N + S/N
        if (-not $efsItems.ContainsKey($key)) {
            $efsItems[$key] = @{
                pn = $pn
                sn = $sn
                hc = $hc
                next18M = ""
                next36M = ""
            }
        }
        
        # Always update H/C (might change)
        if ($hc) { $efsItems[$key].hc = $hc }
        
        # Determine interval from Task
        if ($task -match "PE\s*18\s*M") {
            $efsItems[$key].next18M = $dueDate
        }
        elseif ($task -match "PE\s*3\s*Y") {
            $efsItems[$key].next36M = $dueDate
        }
        else {
            Write-Log "  INFO: Task non reconnue row $r : '$task' (DMC: $dmc)" "Gray"
        }
        
        } # end foreach sn
                $rowsRead++
    }
    
    Write-Log "Lignes lues: $rowsRead | Lignes OTL ignorees: $rowsFiltered | Items EFS uniques: $($efsItems.Count)" "Green"

    # Close Excel - READ ONLY, no save
    $workbook.Close($false)
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    $excel = $null
    Write-Log "Excel ferme (aucune modification)" "Green"

} catch {
    Write-Log "ERREUR Excel: $($_.Exception.Message)" "Red"
    if ($workbook) { try { $workbook.Close($false) } catch {} }
    if ($excel) { try { $excel.Quit(); [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null } catch {} }
    pause
    exit 1
}

# ============================================================
# STEP 5: Load current EFS data from Supabase
# ============================================================
Write-Log "Chargement des EFS depuis Supabase..." "Yellow"

$headers = @{
    "apikey" = $SUPABASE_KEY
    "Authorization" = "Bearer $SUPABASE_KEY"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

try {
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/efs?select=*" -Headers $headers -Method Get
    $supabaseEFS = @()
    if ($response) {
        $supabaseEFS = @($response)
    }
    Write-Log "EFS en base: $($supabaseEFS.Count) items" "Green"
} catch {
    Write-Log "ERREUR Supabase GET: $($_.Exception.Message)" "Red"
    pause
    exit 1
}

# ============================================================
# STEP 6: Match and update
# ============================================================
Write-Log "Mise a jour des EFS..." "Yellow"

$updated = 0
$created = 0
$skipped = 0

foreach ($key in $efsItems.Keys) {
    $item = $efsItems[$key]
    $pn = $item.pn
    $sn = $item.sn
    
    # Normalize P/N for comparison (case-insensitive)
    $pnUpper = $pn.ToUpper()
    
    # Find matching item in Supabase by P/N + S/N
    $existing = $supabaseEFS | Where-Object {
        $d = $_.data
        if ($d -is [string]) { $d = $d | ConvertFrom-Json }
        ($d.partNumber -and $d.partNumber.ToUpper() -eq $pnUpper) -and
        ($d.serialNumber -and $d.serialNumber -eq $sn)
    }
    
    if ($existing) {
        # UPDATE existing item
        $existingData = $existing.data
        if ($existingData -is [string]) { $existingData = $existingData | ConvertFrom-Json }
        
        $changed = $false
        $changes = @()
        
        # Check H/C
        if ($item.hc -and $existingData.hc -ne $item.hc) {
            $existingData | Add-Member -NotePropertyName "hc" -NotePropertyValue $item.hc -Force
            $changed = $true
            $changes += "H/C: $($item.hc)"
        }
        
        # Check next18M
        if ($item.next18M -and $existingData.next18M -ne $item.next18M) {
            $existingData | Add-Member -NotePropertyName "next18M" -NotePropertyValue $item.next18M -Force
            $changed = $true
            $changes += "18M: $($item.next18M)"
        }
        
        # Check next36M
        if ($item.next36M -and $existingData.next36M -ne $item.next36M) {
            $existingData | Add-Member -NotePropertyName "next36M" -NotePropertyValue $item.next36M -Force
            $changed = $true
            $changes += "36M: $($item.next36M)"
        }
        
        # Update serviceability based on dates
        $now = Get-Date
        $isOverdue = $false
        if ($existingData.next18M) {
            try { if ([DateTime]::Parse($existingData.next18M) -lt $now) { $isOverdue = $true } } catch {}
        }
        if ($existingData.next36M) {
            try { if ([DateTime]::Parse($existingData.next36M) -lt $now) { $isOverdue = $true } } catch {}
        }
        
        $newServiceability = if ($isOverdue) { "Unserviceable" } else { "Serviceable" }
        if ($existingData.serviceability -ne $newServiceability) {
            $existingData | Add-Member -NotePropertyName "serviceability" -NotePropertyValue $newServiceability -Force
            $changed = $true
            $changes += "Status: $newServiceability"
        }
        
        if ($changed) {
            # Update lastModified
            $existingData | Add-Member -NotePropertyName "lastModified" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ") -Force
            $existingData | Add-Member -NotePropertyName "modifiedBy" -NotePropertyValue "CARO-AutoSync" -Force
            
            $body = @{
                data = $existingData
                updated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
            } | ConvertTo-Json -Depth 10 -Compress
            
            try {
                $patchHeaders = $headers.Clone()
                $patchHeaders["Prefer"] = "return=minimal"
                Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/efs?id=eq.$($existing.id)" -Headers $patchHeaders -Method Patch -Body $body | Out-Null
                $updated++
                Write-Log "  UPDATED: $pn / SN $sn -> $($changes -join ', ')" "Green"
            } catch {
                Write-Log "  ERREUR update $pn / SN $sn : $($_.Exception.Message)" "Red"
            }
        } else {
            $skipped++
            Write-Log "  SKIP: $pn / SN $sn (pas de changement)" "Gray"
        }
    } else {
        # Item not found in Supabase - SKIP (no auto-create)
        $skipped++
        Write-Log "  SKIP: $pn / SN $sn (n'existe pas en base - ajoutez-le manuellement)" "Yellow"
    }
}

# ============================================================
# STEP 7: Summary
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Log "RESUME:" "Cyan"
Write-Log "  Items mis a jour : $updated" "Green"
Write-Log "  Items inchanges   : $skipped" "Gray"
Write-Log "--- EFS Sync Termine ---" "Cyan"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Appuyez sur une touche..." -ForegroundColor Yellow
pause
