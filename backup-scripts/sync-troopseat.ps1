# ============================================================
# Components Bay - Troop Seat Sync
# Source : Troop Seat LifingV1.0.xlsm (READ-ONLY)
# Logique :
#   - Lire STD (P/N S252M20A1007) et AVD (P/N S252M20A2002)
#   - Pour chaque ligne : chercher P/N + S/N dans Fleet Overview
#   - Si INSTALLED = Y -> H/C = KIT, date = Fleet Overview
#   - Si INSTALLED = N ou pas trouve -> H/C = Spare, date = STD/AVD
#   - nextInspection = inspectionDate + 3 ans
# RUN MANUEL UNIQUEMENT
# ============================================================

$SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"
$TROOP_FILE  = "C:\Users\jpellegrini\Desktop\APP 5.5\CARO update\Troop Seat LifingV1.0.xlsm"
$SHEET_FLEET = "Fleet overview"
$SHEET_STD   = "STD"
$SHEET_AVD   = "AVD"
$LOG_DIR     = "$env:USERPROFILE\Documents\ComponentsBay_Backups"
$LOG_FILE    = "$LOG_DIR\troopseat_sync_log.txt"

function Write-Log { param([string]$Msg,[string]$Col="White"); $line="[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Msg"; Write-Host $line -ForegroundColor $Col; Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8 }

function Parse-Date([string]$raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return "" }
    $raw = $raw.Trim()
    if ($raw -match "N/C|#VALUE|#REF|#NAME|\?|Not Fitted|N/A|TBC") { return "" }
    if ($raw.Length -lt 4) { return "" }
    foreach ($f in @("dd-MM-yy","dd-MM-yyyy","dd/MM/yy","dd/MM/yyyy","yyyy-MM-dd","MM/dd/yyyy")) {
        try { $d=[DateTime]::ParseExact($raw,$f,[System.Globalization.CultureInfo]::InvariantCulture); if($d.Year -lt 2000){$d=$d.AddYears(100)}; return $d.ToString("yyyy-MM-dd") } catch { continue }
    }
    try { $d=[DateTime]::Parse($raw); if($d.Year -lt 2000){$d=$d.AddYears(100)}; return $d.ToString("yyyy-MM-dd") } catch { return "" }
}

function Calc-Next3Y([string]$base) {
    if ([string]::IsNullOrWhiteSpace($base)) { return "" }
    try { return ([DateTime]::Parse($base)).AddYears(3).ToString("yyyy-MM-dd") } catch { return "" }
}

function Find-Col($ws,[string[]]$patterns) {
    $last=$ws.UsedRange.Columns.Count
    for($c=1;$c -le $last;$c++){$h=$ws.Cells(1,$c).Text.Trim().ToUpper(); foreach($p in $patterns){if($h -match $p){return $c}}}
    return -1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Troop Seat Sync - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
Write-Log "--- Troop Seat Sync Started ---" "Cyan"

if (-not (Test-Path $TROOP_FILE)) { Write-Log "ERREUR: Fichier introuvable: $TROOP_FILE" "Red"; pause; exit 1 }
Write-Log "Fichier: $TROOP_FILE" "Green"

$excel=$null; $workbook=$null
try {
    $excel=New-Object -ComObject Excel.Application
    $excel.Visible=$false; $excel.DisplayAlerts=$false
    $workbook=$excel.Workbooks.Open($TROOP_FILE,0,$true)
    Write-Log "Excel ouvert en lecture seule" "Green"

    $sheetFleet=$null; $sheetSTD=$null; $sheetAVD=$null
    foreach($ws in $workbook.Worksheets){
        if($ws.Name -eq $SHEET_FLEET){$sheetFleet=$ws}
        if($ws.Name -eq $SHEET_STD)  {$sheetSTD=$ws}
        if($ws.Name -eq $SHEET_AVD)  {$sheetAVD=$ws}
    }
    if(-not $sheetFleet){Write-Log "ERREUR: Onglet '$SHEET_FLEET' introuvable" "Red"; throw "missing"}
    if(-not $sheetSTD)  {Write-Log "ERREUR: Onglet '$SHEET_STD' introuvable" "Red"; throw "missing"}
    if(-not $sheetAVD)  {Write-Log "ERREUR: Onglet '$SHEET_AVD' introuvable" "Red"; throw "missing"}

    # --- FLEET OVERVIEW -> lookup table ---
    Write-Log "Lecture Fleet Overview..." "Yellow"
    $cFPN  = Find-Col $sheetFleet @("^P/N$","^PN$")
    $cFSN  = Find-Col $sheetFleet @("^S/N$","^SN$")
    $cFIns = Find-Col $sheetFleet @("INSTALL","Y/N")
    $cFKit = Find-Col $sheetFleet @("^KIT$")
    $cFDt  = Find-Col $sheetFleet @("FIRST.FLIGHT","LAST.MAINT","TSI")
    Write-Log "  Fleet cols -> PN=$cFPN SN=$cFSN Installed=$cFIns KIT=$cFKit Date=$cFDt" "Gray"

    $fleetLookup=@{}
    for($r=2;$r -le $sheetFleet.UsedRange.Rows.Count;$r++){
        $pn=$sheetFleet.Cells($r,$cFPN).Text.Trim().ToUpper()
        $sn=$sheetFleet.Cells($r,$cFSN).Text.Trim()
        if(-not $pn -or -not $sn){continue}
        $ins=$sheetFleet.Cells($r,$cFIns).Text.Trim().ToUpper()
        $kit=if($cFKit -gt 0){$sheetFleet.Cells($r,$cFKit).Text.Trim()}else{""}
        $dt =if($cFDt  -gt 0){$sheetFleet.Cells($r,$cFDt ).Text.Trim()}else{""}
        $fleetLookup["$pn|$sn"]=@{installed=($ins -match "^Y$|^YES$");kit=$kit;lastMaint=$dt}
    }
    Write-Log "  $($fleetLookup.Count) entrees Fleet chargees" "Green"

    # --- STD + AVD -> build items ---
    $troopItems=@{}
    foreach($si in @(@{ws=$sheetSTD;name=$SHEET_STD},@{ws=$sheetAVD;name=$SHEET_AVD})){
        $ws=$si.ws; $nm=$si.name
        Write-Log "Lecture $nm..." "Yellow"
        $cPN=Find-Col $ws @("^P/N$","^PN$")
        $cSN=Find-Col $ws @("^S/N$","^SN$")
        $cDt=Find-Col $ws @("TSI","LAST.MAINT","FIRST.FLIGHT","MAINTENANCE")
        Write-Log "  $nm cols -> PN=$cPN SN=$cSN Date=$cDt" "Gray"

        for($r=2;$r -le $ws.UsedRange.Rows.Count;$r++){
            $pn=$ws.Cells($r,$cPN).Text.Trim().ToUpper()
            $sn=$ws.Cells($r,$cSN).Text.Trim()
            if(-not $pn -or -not $sn){continue}

            $dtRaw=if($cDt -gt 0){$ws.Cells($r,$cDt).Text.Trim()}else{""}
            $inspDate=Parse-Date $dtRaw
            $hc="Spare"

            $key="$pn|$sn"
            if($fleetLookup.ContainsKey($key)){
                $fl=$fleetLookup[$key]
                if($fl.installed){
                    $hc=$fl.kit
                    $flDate=Parse-Date $fl.lastMaint
                    if($flDate){$inspDate=$flDate}
                }
            }

            $nextInsp=Calc-Next3Y $inspDate
            $troopItems[$key]=@{pn=$pn;sn=$sn;hc=$hc;inspectionDate=$inspDate;nextInspection=$nextInsp}
            Write-Log "  $nm r$r : PN=$pn SN=$sn HC='$hc' Insp=$inspDate Next=$nextInsp" "Gray"
        }
    }

    $workbook.Close($false); $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel)|Out-Null; $excel=$null
    Write-Log "Excel ferme - $($troopItems.Count) seats trouves" "Green"

} catch {
    Write-Log "ERREUR Excel: $($_.Exception.Message)" "Red"
    if($workbook){try{$workbook.Close($false)}catch{}}
    if($excel){try{$excel.Quit();[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel)|Out-Null}catch{}}
    pause; exit 1
}

# --- SUPABASE LOAD ---
Write-Log "Chargement Supabase..." "Yellow"
$hdrs=@{"apikey"=$SUPABASE_KEY;"Authorization"="Bearer $SUPABASE_KEY";"Content-Type"="application/json";"Prefer"="return=representation"}
try {
    $resp=Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/troopseats?select=*" -Headers $hdrs -Method Get
    $seats=@(); if($resp){$seats=@($resp)}
    Write-Log "Supabase: $($seats.Count) seats en base" "Green"
} catch { Write-Log "ERREUR Supabase GET: $($_.Exception.Message)" "Red"; pause; exit 1 }

# --- MATCH & UPDATE ---
Write-Log "Mise a jour..." "Yellow"
$updated=0;$skipped=0;$notFound=0

foreach($key in $troopItems.Keys){
    $item=$troopItems[$key]
    $pnUp=$item.pn.ToUpper(); $sn=$item.sn

    $existing=$seats|Where-Object{
        $d=$_.data; if($d -is [string]){$d=$d|ConvertFrom-Json}
        ($d.partNumber -and $d.partNumber.ToUpper() -eq $pnUp) -and ($d.serialNumber -and $d.serialNumber.ToString().Trim() -eq $sn)
    }|Select-Object -First 1

    if(-not $existing){$notFound++; Write-Log "  NOT FOUND: $($item.pn) / SN $sn" "Yellow"; continue}

    $d=$existing.data; if($d -is [string]){$d=$d|ConvertFrom-Json}
    $changed=$false; $changes=@()

    $curHC=if($d.hc){$d.hc}else{""}
    if($item.hc -and $curHC -ne $item.hc){$d|Add-Member -NotePropertyName "hc" -NotePropertyValue $item.hc -Force;$changed=$true;$changes+="H/C:'$curHC'->'$($item.hc)'"}

    $curInsp=if($d.inspectionDate){$d.inspectionDate}else{""}
    if($item.inspectionDate -and $curInsp -ne $item.inspectionDate){$d|Add-Member -NotePropertyName "inspectionDate" -NotePropertyValue $item.inspectionDate -Force;$changed=$true;$changes+="InspDate:$($item.inspectionDate)"}

    $curNext=if($d.nextInspection){$d.nextInspection}else{""}
    if($item.nextInspection -and $curNext -ne $item.nextInspection){$d|Add-Member -NotePropertyName "nextInspection" -NotePropertyValue $item.nextInspection -Force;$changed=$true;$changes+="NextInsp:$($item.nextInspection)"}

    if($item.nextInspection){
        try{$isOD=[DateTime]::Parse($item.nextInspection) -lt (Get-Date); $svc=if($isOD){"Unserviceable"}else{"Serviceable"}
            if($d.serviceability -ne $svc){$d|Add-Member -NotePropertyName "serviceability" -NotePropertyValue $svc -Force;$changed=$true;$changes+="Status:$svc"}}catch{}
    }

    if($changed){
        $d|Add-Member -NotePropertyName "lastModified" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ") -Force
        $d|Add-Member -NotePropertyName "modifiedBy" -NotePropertyValue "TroopSeat-AutoSync" -Force
        $body=@{data=$d;updated_at=(Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")}|ConvertTo-Json -Depth 10 -Compress
        try{
            $ph=$hdrs.Clone();$ph["Prefer"]="return=minimal"
            Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/troopseats?id=eq.$($existing.id)" -Headers $ph -Method Patch -Body $body|Out-Null
            $updated++;Write-Log "  UPDATED: $($item.pn)/SN $sn -> $($changes -join ', ')" "Green"
        }catch{Write-Log "  ERREUR update $($item.pn)/SN $sn : $($_.Exception.Message)" "Red"}
    }else{$skipped++;Write-Log "  SKIP: $($item.pn)/SN $sn (pas de changement)" "Gray"}
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Log "RESUME:" "Cyan"
Write-Log "  Mis a jour  : $updated" "Green"
Write-Log "  Inchanges   : $skipped" "Gray"
Write-Log "  Introuvables: $notFound" "Yellow"
Write-Log "--- Troop Seat Sync Termine ---" "Cyan"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
pause
