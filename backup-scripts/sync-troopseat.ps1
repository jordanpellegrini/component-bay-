# ============================================================
# Components Bay - Troop Seat Sync from Troop Seat LifingV1.0
# Reads Excel (READ-ONLY) and updates Troop Seats in Supabase
# RUN MANUALLY ONLY - no scheduled task
# ============================================================

# --- CONFIGURATION ---
$SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"

$TROOP_FILE = "C:\Users\jpellegrini\Desktop\APP 5.5\CARO update\Troop Seat LifingV1.0.xlsm"
$SHEET_FLEET = "Fleet overview"
$SHEET_STD   = "STD"
$SHEET_AVD   = "AVD"

$PN_STD = "S252M20A1007"
$PN_AVD = "S252M20A2002"

# Log file
$LOG_DIR  = "$env:USERPROFILE\Documents\ComponentsBay_Backups"
$LOG_FILE = "$LOG_DIR\troopseat_sync_log.txt"

# --- FUNCTIONS ---
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] $Message"
    Write-Host $logLine -ForegroundColor $Color
    Add-Content -Path $LOG_FILE -Value $logLine -Encoding UTF8
}

function Parse-Date {
    param([string]$raw)
    if ([string]::IsNullOrWhiteSpace($raw)) { return "" }
    $raw = $raw.Trim()
    # Ignore invalid values
    if ($raw -match "N/C|#VALUE|#REF|#NAME|\?|Not Fitted|N/A" -or $raw.Length -lt 4) { return "" }
    $formats = @("dd-MM-yy","dd-MM-yyyy","dd/MM/yy","dd/MM/yyyy","yyyy-MM-dd","MM/dd/yyyy","dd-MMM-yy")
    foreach ($fmt in $formats) {
        try {
            $d = [DateTime]::ParseExact($raw, $fmt, [System.Globalization.CultureInfo]::InvariantCulture)
            if ($d.Year -lt 2000) { $d = $d.AddYears(100) }
            return $d.ToString("yyyy-MM-dd")
        } catch { continue }
    }
    try {
        $d = [DateTime]::Parse($raw)
        if ($d.Year -lt 2000) { $d = $d.AddYears(100) }
        return $d.ToString("yyyy-MM-dd")
    } catch { return "" }
}

function Calc-Next3Y {
    param([string]$baseDate)
    if ([string]::IsNullOrWhiteSpace($baseDate)) { return "" }
    try {
        $d = [DateTime]::Parse($baseDate)
        return $d.AddYears(3).ToString("yyyy-MM-dd")
    } catch { return "" }
}

# ============================================================
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Troop Seat Sync from Troop Seat LifingV1.0" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
Write-Log "--- Troop Seat Sync Started ---" "Cyan"

# ============================================================
# STEP 1: Check file
# ============================================================
if (-not (Test-Path $TROOP_FILE)) {
    Write-Log "ERREUR: Fichier introuvable: $TROOP_FILE" "Red"
    pause; exit 1
}
Write-Log "Fichier trouve: $TROOP_FILE" "Green"

# ============================================================
# STEP 2: Open Excel READ-ONLY
# ============================================================
Write-Log "Ouverture Excel en LECTURE SEULE..." "Yellow"
$excel = $null; $workbook = $null

function Get-Sheet {
    param($wb, [string]$name)
    foreach ($ws in $wb.Worksheets) {
        if ($ws.Name -eq $name) { return $ws }
    }
    return $null
}

function Read-SheetData {
    param($sheet)
    # Returns hashtable: key = SN -> { pn, sn, inspectionDate, nextInspection }
    $data = @{}
    if (-not $sheet) { return $data }

    $lastRow = $sheet.UsedRange.Rows.Count
    $lastCol = $sheet.UsedRange.Columns.Count

    # Find column positions from header row 1
    $colPN = -1; $colSN = -1; $colNext3Y = -1; $colLastMaint = -1
    for ($c = 1; $c -le $lastCol; $c++) {
        $h = $sheet.Cells(1, $c).Text.Trim().ToUpper()
        if ($h -match "^P/N$|^PART.NUMBER$|^PN$") { $colPN = $c }
        elseif ($h -match "^S/N$|^SERIAL|^SN$") { $colSN = $c }
        elseif ($h -match "NEXT.*3Y|3Y") { $colNext3Y = $c }
        elseif ($h -match "TSI|LAST.*MAINT|FIRST.*FLIGHT|MAINTENANCE") { $colLastMaint = $c }
    }

    Write-Log "  Onglet '$($sheet.Name)': PN=$colPN SN=$colSN LastMaint=$colLastMaint" "Gray"

    for ($r = 2; $r -le $lastRow; $r++) {
        $pn = $sheet.Cells($r, $colPN).Text.Trim().ToUpper()
        $sn = $sheet.Cells($r, $colSN).Text.Trim()
        if (-not $pn -or -not $sn) { continue }

        $lastMaintRaw = if ($colLastMaint -gt 0) { $sheet.Cells($r, $colLastMaint).Text.Trim() } else { "" }
        $inspDate = Parse-Date $lastMaintRaw
        $nextInsp = Calc-Next3Y $inspDate

        $data["$pn|$sn"] = @{
            pn = $pn
            sn = $sn
            inspectionDate = $inspDate
            nextInspection = $nextInsp
        }
    }
    return $data
}

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $workbook = $excel.Workbooks.Open($TROOP_FILE, 0, $true)

    $sheetFleet = Get-Sheet $workbook $SHEET_FLEET
    $sheetSTD   = Get-Sheet $workbook $SHEET_STD
    $sheetAVD   = Get-Sheet $workbook $SHEET_AVD

    if (-not $sheetFleet) {
        Write-Log "ERREUR: Onglet '$SHEET_FLEET' introuvable!" "Red"
        $workbook.Close($false); $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        pause; exit 1
    }

    Write-Log "Lecture onglet STD..." "Yellow"
    $stdData = Read-SheetData $sheetSTD

    Write-Log "Lecture onglet AVD..." "Yellow"
    $avdData = Read-SheetData $sheetAVD

    # ============================================================
    # STEP 3: Read Fleet Overview
    # ============================================================
    Write-Log "Lecture onglet Fleet Overview..." "Yellow"

    $lastRow  = $sheetFleet.UsedRange.Rows.Count
    $lastCol  = $sheetFleet.UsedRange.Columns.Count

    # Find columns
    $colKit = -1; $colPN = -1; $colSN = -1
    $colInstalled = -1; $colLastMaint = -1

    for ($c = 1; $c -le $lastCol; $c++) {
        $h = $sheetFleet.Cells(1, $c).Text.Trim().ToUpper()
        Write-Log "  Col $c : '$h'" "Gray"
        if ($h -match "KIT")                                          { $colKit = $c }
        elseif ($h -match "^P/N$|^PN$|^PART")                        { $colPN = $c }
        elseif ($h -match "^S/N$|^SN$|^SERIAL")                      { $colSN = $c }
        elseif ($h -match "INSTALL|FITTED|Y/N")                       { $colInstalled = $c }
        elseif ($h -match "TSI|LAST.*MAINT|FIRST.*FLIGHT|MAINTENANCE") { $colLastMaint = $c }
    }

    Write-Log "Fleet Overview colonnes: KIT=$colKit PN=$colPN SN=$colSN Installed=$colInstalled LastMaint=$colLastMaint" "Yellow"

    # Build troop seat items list
    $troopItems = @{}

    for ($r = 2; $r -le $lastRow; $r++) {
        $pn        = $sheetFleet.Cells($r, $colPN).Text.Trim().ToUpper()
        $sn        = $sheetFleet.Cells($r, $colSN).Text.Trim()
        $installed = $sheetFleet.Cells($r, $colInstalled).Text.Trim().ToUpper()
        $kit       = if ($colKit -gt 0) { $sheetFleet.Cells($r, $colKit).Text.Trim() } else { "" }

        if (-not $pn -or -not $sn) { continue }

        Write-Log "  Row $r : PN=$pn SN=$sn Installed='$installed' Kit='$kit'" "Gray"

        $hc = ""
        $inspDate = ""
        $nextInsp = ""

        $isInstalled = $installed -match "^Y$|^YES$|^OUI$|^1$"

        if ($isInstalled) {
            # Installed on aircraft - use Fleet Overview data
            $hc = $kit
            $lastMaintRaw = if ($colLastMaint -gt 0) { $sheetFleet.Cells($r, $colLastMaint).Text.Trim() } else { "" }
            $inspDate = Parse-Date $lastMaintRaw
            $nextInsp = Calc-Next3Y $inspDate

        } else {
            # Not installed - look up in STD or AVD
            $hc = "Spare"
            $key = "$pn|$sn"

            if ($pn -eq $PN_STD -and $stdData.ContainsKey($key)) {
                $inspDate = $stdData[$key].inspectionDate
                $nextInsp = $stdData[$key].nextInspection
            } elseif ($pn -eq $PN_AVD -and $avdData.ContainsKey($key)) {
                $inspDate = $avdData[$key].inspectionDate
                $nextInsp = $avdData[$key].nextInspection
            }
        }

        $troopItems["$pn|$sn"] = @{
            pn            = $pn
            sn            = $sn
            hc            = $hc
            inspectionDate = $inspDate
            nextInspection = $nextInsp
            installed     = $isInstalled
        }
    }

    $workbook.Close($false)
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    $excel = $null
    Write-Log "Excel ferme (aucune modification) - $($troopItems.Count) troop seats trouves" "Green"

} catch {
    Write-Log "ERREUR Excel: $($_.Exception.Message)" "Red"
    if ($workbook) { try { $workbook.Close($false) } catch {} }
    if ($excel) { try { $excel.Quit(); [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null } catch {} }
    pause; exit 1
}

# ============================================================
# STEP 4: Load Supabase Troop Seats
# ============================================================
Write-Log "Chargement des Troop Seats depuis Supabase..." "Yellow"

$headers = @{
    "apikey"        = $SUPABASE_KEY
    "Authorization" = "Bearer $SUPABASE_KEY"
    "Content-Type"  = "application/json"
    "Prefer"        = "return=representation"
}

try {
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/troopseats?select=*" -Headers $headers -Method Get
    $supabaseSeats = @()
    if ($response) { $supabaseSeats = @($response) }
    Write-Log "Troop Seats en base: $($supabaseSeats.Count) items" "Green"
} catch {
    Write-Log "ERREUR Supabase GET: $($_.Exception.Message)" "Red"
    pause; exit 1
}

# ============================================================
# STEP 5: Match and update
# ============================================================
Write-Log "Mise a jour des Troop Seats..." "Yellow"

$updated = 0; $skipped = 0; $notFound = 0

foreach ($key in $troopItems.Keys) {
    $item   = $troopItems[$key]
    $pn     = $item.pn
    $sn     = $item.sn
    $pnUp   = $pn.ToUpper()

    # Find in Supabase by P/N + S/N
    $existing = $supabaseSeats | Where-Object {
        $d = $_.data
        if ($d -is [string]) { $d = $d | ConvertFrom-Json }
        ($d.partNumber -and $d.partNumber.ToUpper() -eq $pnUp) -and
        ($d.serialNumber -and $d.serialNumber -eq $sn)
    }

    if ($existing) {
        $existingData = $existing.data
        if ($existingData -is [string]) { $existingData = $existingData | ConvertFrom-Json }

        $changed = $false
        $changes = @()

        # Check H/C
        if ($item.hc -and $existingData.hc -ne $item.hc) {
            $existingData | Add-Member -NotePropertyName "hc" -NotePropertyValue $item.hc -Force
            $changed = $true; $changes += "H/C: $($item.hc)"
        }

        # Check inspectionDate
        if ($item.inspectionDate -and $existingData.inspectionDate -ne $item.inspectionDate) {
            $existingData | Add-Member -NotePropertyName "inspectionDate" -NotePropertyValue $item.inspectionDate -Force
            $changed = $true; $changes += "InspDate: $($item.inspectionDate)"
        }

        # Check nextInspection
        if ($item.nextInspection -and $existingData.nextInspection -ne $item.nextInspection) {
            $existingData | Add-Member -NotePropertyName "nextInspection" -NotePropertyValue $item.nextInspection -Force
            $changed = $true; $changes += "NextInsp: $($item.nextInspection)"
        }

        # Update serviceability based on nextInspection
        if ($item.nextInspection) {
            $now = Get-Date
            $isOverdue = $false
            try { if ([DateTime]::Parse($item.nextInspection) -lt $now) { $isOverdue = $true } } catch {}
            $newSvc = if ($isOverdue) { "Unserviceable" } else { "Serviceable" }
            if ($existingData.serviceability -ne $newSvc) {
                $existingData | Add-Member -NotePropertyName "serviceability" -NotePropertyValue $newSvc -Force
                $changed = $true; $changes += "Status: $newSvc"
            }
        }

        if ($changed) {
            $existingData | Add-Member -NotePropertyName "lastModified" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ") -Force
            $existingData | Add-Member -NotePropertyName "modifiedBy" -NotePropertyValue "TroopSeat-AutoSync" -Force

            $body = @{
                data       = $existingData
                updated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
            } | ConvertTo-Json -Depth 10 -Compress

            try {
                $patchHeaders = $headers.Clone()
                $patchHeaders["Prefer"] = "return=minimal"
                Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/troopseats?id=eq.$($existing.id)" -Headers $patchHeaders -Method Patch -Body $body | Out-Null
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
        $notFound++
        Write-Log "  NOT FOUND: $pn / SN $sn (n'existe pas en base)" "Yellow"
    }
}

# ============================================================
# STEP 6: Summary
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Log "RESUME:" "Cyan"
Write-Log "  Items mis a jour  : $updated" "Green"
Write-Log "  Items inchanges   : $skipped" "Gray"
Write-Log "  Introuvables base : $notFound" "Yellow"
Write-Log "--- Troop Seat Sync Termine ---" "Cyan"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Appuyez sur une touche..." -ForegroundColor Yellow
pause
