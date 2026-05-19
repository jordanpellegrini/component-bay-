# ============================================================
# Components Bay - EFS Auto-Sync from C.A.R.O.
# - full plan  : dates 18M / 36M + H/C
# - kardex     : flight hours (colonne G = Currently FH)
# - Absent CARO -> H/C = Spare + Unserviceable
# Schedule: Every Wednesday at 12:00
# ============================================================

# --- CONFIGURATION ---
$SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"

$CARO_FILE      = "C:\Users\jpellegrini\Desktop\APP 5.5\CARO update\C.A.R.O. 2.6.1.xlsm"
$SHEET_FULLPLAN = "full plan"
$SHEET_KARDEX   = "kardex"   # <-- nom exact de l'onglet kardex

$EFS_PN_LIST = @(
    "S956A20A1004",
    "S956A20A1005",
    "S956A20A1006",
    "S956A20A1007",
    "S956A20A1013",
    "S956A20A1014"
)

$EFS_DESIGNATIONS = @{
    "S956A20A1004" = "LH FWD EFS"
    "S956A20A1005" = "RH FWD EFS"
    "S956A20A1006" = "LH AFT EFS"
    "S956A20A1013" = "LH AFT EFS"
    "S956A20A1007" = "RH AFT EFS"
    "S956A20A1014" = "RH AFT EFS"
}

$LOG_DIR  = "$env:USERPROFILE\Documents\ComponentsBay_Backups"
$LOG_FILE = "$LOG_DIR\efs_sync_log.txt"

# --- NE PAS MODIFIER EN DESSOUS ---

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] $Message"
    Write-Host $logLine -ForegroundColor $Color
    Add-Content -Path $LOG_FILE -Value $logLine -Encoding UTF8
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  EFS Auto-Sync from C.A.R.O."              -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm')"   -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
Write-Log "--- EFS Sync Started ---" "Cyan"

# ============================================================
# STEP 1: Check CARO file
# ============================================================
if (-not (Test-Path $CARO_FILE)) {
    Write-Log "ERREUR: Fichier CARO introuvable: $CARO_FILE" "Red"
    exit 1
}
Write-Log "Fichier CARO trouve: $CARO_FILE" "Green"

# ============================================================
# STEP 2: Open Excel READ-ONLY
# ============================================================
Write-Log "Ouverture Excel en LECTURE SEULE..." "Yellow"
$excel    = $null
$workbook = $null

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible       = $false
    $excel.DisplayAlerts = $false
    $workbook = $excel.Workbooks.Open($CARO_FILE, 0, $true)

    # ============================================================
    # STEP 3: Read FULL PLAN -> dates + H/C
    # ============================================================
    $sheetFP = $null
    foreach ($ws in $workbook.Worksheets) {
        if ($ws.Name -eq $SHEET_FULLPLAN) { $sheetFP = $ws; break }
    }
    if (-not $sheetFP) {
        Write-Log "ERREUR: Onglet '$SHEET_FULLPLAN' introuvable!" "Red"
        $workbook.Close($false); $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        exit 1
    }
    Write-Log "Onglet '$SHEET_FULLPLAN' ouvert" "Green"

    $lastCol = $sheetFP.UsedRange.Columns.Count
    $lastRow = $sheetFP.UsedRange.Rows.Count
    Write-Log "Full plan: $lastRow lignes x $lastCol colonnes"

    $colPN=-1; $colSN=-1; $colTask=-1; $colDueDate=-1; $colHC=-1; $colDMC=-1

    for ($c = 1; $c -le $lastCol; $c++) {
        $h = $sheetFP.Cells(1, $c).Text.Trim().ToUpper()
        switch ($h) {
            "PN"       { $colPN      = $c }
            "SN"       { $colSN      = $c }
            "TASK"     { $colTask    = $c }
            "DUE DATE" { $colDueDate = $c }
            "H/C"      { $colHC      = $c }
            "DMC"      { $colDMC     = $c }
        }
    }

    if ($colPN -eq -1 -or $colSN -eq -1 -or $colTask -eq -1 -or $colDueDate -eq -1) {
        Write-Log "ERREUR: Colonnes manquantes! PN=$colPN SN=$colSN Task=$colTask DueDate=$colDueDate" "Red"
        $workbook.Close($false); $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        exit 1
    }
    Write-Log "Colonnes full plan: PN=$colPN SN=$colSN Task=$colTask DueDate=$colDueDate HC=$colHC" "Gray"

    # Structure: key = "PN|SN" -> { pn, sn, hc, next18M, next36M, flightHours }
    $efsItems     = @{}
    $rowsRead     = 0
    $rowsFiltered = 0

    for ($r = 2; $r -le $lastRow; $r++) {
        $pn = $sheetFP.Cells($r, $colPN).Text.Trim().ToUpper()
        if ($EFS_PN_LIST -notcontains $pn) { continue }

        $task = $sheetFP.Cells($r, $colTask).Text.Trim()
        if ($task -match "OTL") { $rowsFiltered++; continue }

        $snRaw      = $sheetFP.Cells($r, $colSN).Text.Trim()
        $dueDateRaw = $sheetFP.Cells($r, $colDueDate).Text.Trim()
        $hc         = if ($colHC  -gt 0) { $sheetFP.Cells($r, $colHC).Text.Trim()  } else { "" }
        $dmc        = if ($colDMC -gt 0) { $sheetFP.Cells($r, $colDMC).Text.Trim() } else { "" }

        $snList = $snRaw -split '[\s,/\r\n]+' | Where-Object { $_ -ne '' }

        # Parse due date
        $dueDate = ""
        if ($dueDateRaw) {
            try {
                $parsedDate = $null
                $formats = @("dd-MM-yy","dd-MM-yyyy","dd/MM/yy","dd/MM/yyyy","yyyy-MM-dd")
                foreach ($fmt in $formats) {
                    try {
                        $parsedDate = [DateTime]::ParseExact($dueDateRaw, $fmt, [System.Globalization.CultureInfo]::InvariantCulture)
                        if ($parsedDate.Year -lt 2000) { $parsedDate = $parsedDate.AddYears(100) }
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
            }
        }

        foreach ($sn in $snList) {
            $key = "$pn|$sn"
            if (-not $efsItems.ContainsKey($key)) {
                $efsItems[$key] = @{ pn=$pn; sn=$sn; hc=$hc; next18M=""; next36M=""; flightHours="" }
            }
            if ($hc) { $efsItems[$key].hc = $hc }

            if      ($task -match "PE\s*18\s*M") { $efsItems[$key].next18M = $dueDate }
            elseif  ($task -match "PE\s*3\s*Y")  { $efsItems[$key].next36M = $dueDate }
            else    { Write-Log "  INFO: Task non reconnue row $r : '$task' (DMC: $dmc)" "Gray" }

            $rowsRead++
        }
    }
    Write-Log "Full plan: $rowsRead lignes lues | $rowsFiltered OTL ignores | $($efsItems.Count) items EFS" "Green"

    # ============================================================
    # STEP 4: Read KARDEX -> flight hours (col G = Currently FH)
    # Colonnes: A=HC, B=Designation, C=P/N, D=S/N, G=Currently FH
    # ============================================================
    $sheetKD = $null
    foreach ($ws in $workbook.Worksheets) {
        if ($ws.Name -ieq $SHEET_KARDEX) { $sheetKD = $ws; break }
    }

    if (-not $sheetKD) {
        Write-Log "WARN: Onglet '$SHEET_KARDEX' introuvable - flight hours non mis a jour" "Yellow"
    } else {
        Write-Log "Onglet '$SHEET_KARDEX' ouvert" "Green"

        $kdLastCol = $sheetKD.UsedRange.Columns.Count
        $kdLastRow = $sheetKD.UsedRange.Rows.Count
        Write-Log "Kardex: $kdLastRow lignes x $kdLastCol colonnes"

        # Trouver colonnes depuis header row
        $kdColPN=-1; $kdColSN=-1; $kdColFH=-1

        for ($c = 1; $c -le $kdLastCol; $c++) {
            $h = $sheetKD.Cells(1, $c).Text.Trim().ToUpper()
            switch -Wildcard ($h) {
                "P/N"          { $kdColPN = $c }
                "PN"           { $kdColPN = $c }
                "S/N"          { $kdColSN = $c }
                "SN"           { $kdColSN = $c }
                "CURRENTLY FH" { $kdColFH = $c }
                "CURRENTLY*"   { if ($kdColFH -eq -1) { $kdColFH = $c } }
            }
        }

        # Fallback: si headers pas trouves, utiliser positions fixes (C=3, D=4, G=7)
        if ($kdColPN -eq -1) { $kdColPN = 3; Write-Log "  Kardex P/N: colonne fixe C(3)" "Gray" }
        if ($kdColSN -eq -1) { $kdColSN = 4; Write-Log "  Kardex S/N: colonne fixe D(4)" "Gray" }
        if ($kdColFH -eq -1) { $kdColFH = 7; Write-Log "  Kardex FH: colonne fixe G(7)"  "Gray" }

        Write-Log "Colonnes kardex: PN=$kdColPN SN=$kdColSN FH=$kdColFH" "Gray"

        $fhRead = 0
        for ($r = 2; $r -le $kdLastRow; $r++) {
            $pn = $sheetKD.Cells($r, $kdColPN).Text.Trim().ToUpper()
            if ($EFS_PN_LIST -notcontains $pn) { continue }

            $sn = $sheetKD.Cells($r, $kdColSN).Text.Trim()
            $fh = $sheetKD.Cells($r, $kdColFH).Text.Trim()

            if (-not $sn) { continue }

            $key = "$pn|$sn"
            if ($efsItems.ContainsKey($key)) {
                if ($fh) {
                    $efsItems[$key].flightHours = $fh
                    $fhRead++
                    Write-Log "  FH: $pn / SN $sn -> $fh" "Gray"
                }
            } else {
                # P/N+SN dans kardex mais pas dans full plan -> on cree l'entree pour FH seulement
                Write-Log "  INFO Kardex: $pn / SN $sn trouve (pas dans full plan)" "Gray"
            }
        }
        Write-Log "Kardex: $fhRead flight hours lus" "Green"
    }

    $workbook.Close($false)
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    $excel = $null
    Write-Log "Excel ferme (aucune modification)" "Green"

} catch {
    Write-Log "ERREUR Excel: $($_.Exception.Message)" "Red"
    if ($workbook) { try { $workbook.Close($false) } catch {} }
    if ($excel)    { try { $excel.Quit(); [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null } catch {} }
    exit 1
}

# ============================================================
# STEP 5: Load current EFS from Supabase
# ============================================================
Write-Log "Chargement des EFS depuis Supabase..." "Yellow"

$headers = @{
    "apikey"        = $SUPABASE_KEY
    "Authorization" = "Bearer $SUPABASE_KEY"
    "Content-Type"  = "application/json"
    "Prefer"        = "return=representation"
}

try {
    $response    = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/efs?select=*" -Headers $headers -Method Get
    $supabaseEFS = if ($response) { @($response) } else { @() }
    Write-Log "EFS en base: $($supabaseEFS.Count) items" "Green"
} catch {
    Write-Log "ERREUR Supabase GET: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================
# STEP 6: Update items found in CARO (dates + H/C + FH)
# ============================================================
Write-Log "Mise a jour des EFS presents dans CARO..." "Yellow"

$updated = 0
$skipped = 0
$now     = Get-Date

foreach ($key in $efsItems.Keys) {
    $item    = $efsItems[$key]
    $pnUpper = $item.pn.ToUpper()
    $sn      = $item.sn.Trim()

    $existing = $supabaseEFS | Where-Object {
        $d = $_.data
        if ($d -is [string]) { $d = $d | ConvertFrom-Json }
        ($d.partNumber   -and $d.partNumber.ToUpper().Trim() -eq $pnUpper) -and
        ($d.serialNumber -and $d.serialNumber.Trim()         -eq $sn)
    }

    if (-not $existing) {
        Write-Log "  SKIP (non trouve en base): $($item.pn) / SN $sn" "Yellow"
        $skipped++
        continue
    }

    $existingData = $existing.data
    if ($existingData -is [string]) { $existingData = $existingData | ConvertFrom-Json }

    $changed = $false
    $changes = @()

    # H/C
    if ($item.hc -and $existingData.hc -ne $item.hc) {
        $existingData | Add-Member -NotePropertyName "hc" -NotePropertyValue $item.hc -Force
        $changed = $true; $changes += "H/C: $($item.hc)"
    }

    # next18M
    if ($item.next18M -and $existingData.next18M -ne $item.next18M) {
        $existingData | Add-Member -NotePropertyName "next18M" -NotePropertyValue $item.next18M -Force
        $changed = $true; $changes += "18M: $($item.next18M)"
    }

    # next36M
    if ($item.next36M -and $existingData.next36M -ne $item.next36M) {
        $existingData | Add-Member -NotePropertyName "next36M" -NotePropertyValue $item.next36M -Force
        $changed = $true; $changes += "36M: $($item.next36M)"
    }

    # Flight Hours (depuis kardex)
    if ($item.flightHours -and $existingData.flightHours -ne $item.flightHours) {
        $existingData | Add-Member -NotePropertyName "flightHours" -NotePropertyValue $item.flightHours -Force
        $changed = $true; $changes += "FH: $($item.flightHours)"
    }

    # Serviceability based on dates
    $isOverdue = $false
    if ($existingData.next18M) { try { if ([DateTime]::Parse($existingData.next18M) -lt $now) { $isOverdue = $true } } catch {} }
    if ($existingData.next36M) { try { if ([DateTime]::Parse($existingData.next36M) -lt $now) { $isOverdue = $true } } catch {} }

    $newSvc = if ($isOverdue) { "Unserviceable" } else { "Serviceable" }
    if ($existingData.serviceability -ne $newSvc) {
        $existingData | Add-Member -NotePropertyName "serviceability" -NotePropertyValue $newSvc -Force
        $changed = $true; $changes += "Status: $newSvc"
    }

    if ($changed) {
        $existingData | Add-Member -NotePropertyName "lastModified" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ") -Force
        $existingData | Add-Member -NotePropertyName "modifiedBy"   -NotePropertyValue "CARO-AutoSync" -Force

        $body = @{ data = $existingData; updated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ") } | ConvertTo-Json -Depth 10 -Compress
        try {
            $ph = $headers.Clone(); $ph["Prefer"] = "return=minimal"
            Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/efs?id=eq.$($existing.id)" -Headers $ph -Method Patch -Body $body | Out-Null
            $updated++
            Write-Log "  UPDATED: $($item.pn) / SN $sn -> $($changes -join ', ')" "Green"
        } catch {
            Write-Log "  ERREUR update $($item.pn) / SN $sn : $($_.Exception.Message)" "Red"
        }
    } else {
        $skipped++
        Write-Log "  SKIP: $($item.pn) / SN $sn (pas de changement)" "Gray"
    }
}

# ============================================================
# STEP 7: Absent du CARO -> H/C = Spare + Unserviceable
# ============================================================
Write-Log "Verification des EFS absents du CARO..." "Yellow"
$spared = 0

foreach ($dbItem in $supabaseEFS) {
    $d = $dbItem.data
    if ($d -is [string]) { $d = $d | ConvertFrom-Json }

    $dbPN = ($d.partNumber   + '').ToUpper().Trim()
    $dbSN = ($d.serialNumber + '').Trim()

    if ($EFS_PN_LIST -notcontains $dbPN) { continue }
    if ($d.hc -eq 'Spare') { continue }

    $key = "$dbPN|$dbSN"
    if (-not $efsItems.ContainsKey($key)) {
        $d | Add-Member -NotePropertyName "hc"             -NotePropertyValue "Spare"         -Force
        $d | Add-Member -NotePropertyName "serviceability" -NotePropertyValue "Unserviceable" -Force
        $d | Add-Member -NotePropertyName "lastModified"   -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ") -Force
        $d | Add-Member -NotePropertyName "modifiedBy"     -NotePropertyValue "CARO-AutoSync" -Force

        $body = @{ data = $d; updated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ") } | ConvertTo-Json -Depth 10 -Compress
        try {
            $ph = $headers.Clone(); $ph["Prefer"] = "return=minimal"
            Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/efs?id=eq.$($dbItem.id)" -Headers $ph -Method Patch -Body $body | Out-Null
            $spared++
            Write-Log "  SPARE + UNSERVICEABLE: $dbPN / SN $dbSN (absent du CARO)" "Magenta"
        } catch {
            Write-Log "  ERREUR spare $dbPN / SN $dbSN : $($_.Exception.Message)" "Red"
        }
    }
}

# ============================================================
# STEP 8: Summary
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Log "RESUME:" "Cyan"
Write-Log "  Items mis a jour       : $updated" "Green"
Write-Log "  Items -> Spare+Unserv. : $spared"  "Magenta"
Write-Log "  Items inchanges/skip   : $skipped" "Gray"
Write-Log "--- EFS Sync Termine ---" "Cyan"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Appuyez sur une touche..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
