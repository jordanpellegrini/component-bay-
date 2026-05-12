# Components Bay - Wheel Sync from CARO
# CREATE + MODIFY only - never delete

$CARO_FILE    = "C:\Users\jpellegrini\Desktop\APP 5.5\CARO update\C.A.R.O. 2.6.1.xlsm"
$SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"
$LOG_DIR      = "$env:USERPROFILE\Documents\ComponentsBay_Backups"
$LOG_FILE     = "$LOG_DIR\wheel_sync_log.txt"
$MLG_PN = "S324F1011104"
$NLG_PN = "S324F1111103"

function Get-TirePN([string]$hc) {
    $m = [regex]::Match($hc, "QA(\d+)")
    if (-not $m.Success) { return "S324F1121200" }
    $num = [int]$m.Groups[1].Value
    if ($num -ge 250 -and $num -le 265) { return "S324F1023200" }
    if ($num -ge 266 -and $num -le 277) { return "S324F1022200" }
    return "S324F1121200"
}

function Get-TireMapping([string]$tirePn) {
    switch ($tirePn) {
        "S324F1023200" { return @{ pnWheel="S324F1851861"; type="TTH";     position="MLG"; designation="MLG Wheel TTH" } }
        "S324F1022200" { return @{ pnWheel="S324F1851856"; type="NFH";     position="MLG"; designation="MLG Wheel NFH" } }
        default        { return @{ pnWheel="S324F1852853"; type="TTH/NFH"; position="NLG"; designation="NLG Wheel TTH/NFH" } }
    }
}

function Write-Log([string]$msg, [string]$color = "White") {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8
}

function Invoke-SB([string]$method, [string]$endpoint, $body = $null) {
    $headers = @{
        "apikey"        = $SUPABASE_KEY
        "Authorization" = "Bearer $SUPABASE_KEY"
        "Content-Type"  = "application/json"
        "Prefer"        = "return=representation"
    }
    $params = @{ Method=$method; Uri="$SUPABASE_URL/rest/v1/$endpoint"; Headers=$headers; ErrorAction="Stop" }
    if ($null -ne $body) { $params["Body"] = ($body | ConvertTo-Json -Compress -Depth 5) }
    return Invoke-RestMethod @params
}

New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
Write-Log "=== Wheel Sync Started ===" "Cyan"

if (-not (Test-Path $CARO_FILE)) {
    Write-Log "ERREUR: Fichier introuvable: $CARO_FILE" "Red"
    pause; exit 1
}

Write-Log "Lecture CARO..." "Cyan"
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$caroWheels = [System.Collections.ArrayList]::new()

try {
    $wb = $excel.Workbooks.Open($CARO_FILE)
    $ws = $null
    foreach ($sheet in $wb.Sheets) {
        if ($sheet.Name -match "ardex|Kardex") { $ws = $sheet; break }
    }
    if ($null -eq $ws) { $ws = $wb.Sheets.Item(1) }
    Write-Log "Onglet: $($ws.Name)" "Gray"

    $lastCol = $ws.UsedRange.Columns.Count
    $colHC=0; $colPN=0; $colSN=0; $colFH=0
    for ($c=1; $c -le $lastCol; $c++) {
        $h = ($ws.Cells.Item(1,$c).Text.Trim() -replace "\s","").ToUpper()
        if     ($h -match "^HC$|^H/C$")       { $colHC=$c }
        elseif ($h -match "^P/N$|^PN$")        { $colPN=$c }
        elseif ($h -match "^S/N$|^SN$")        { $colSN=$c }
        elseif ($h -match "ITEMFH|FHATIN")      { $colFH=$c }
    }
    Write-Log "Colonnes HC=$colHC PN=$colPN SN=$colSN FH=$colFH" "Gray"

    $lastRow = $ws.UsedRange.Rows.Count
    for ($r=2; $r -le $lastRow; $r++) {
        $pn = ($ws.Cells.Item($r,$colPN).Text.Trim() -replace "\s","").ToUpper()
        if ($pn -ne $MLG_PN.ToUpper() -and $pn -ne $NLG_PN.ToUpper()) { continue }
        $hc = $ws.Cells.Item($r,$colHC).Text.Trim()
        $sn = $ws.Cells.Item($r,$colSN).Text.Trim()
        $fh = if ($colFH -gt 0) { $ws.Cells.Item($r,$colFH).Text.Trim() } else { "" }
        $tirePn  = Get-TirePN $hc
        $mapping = Get-TireMapping $tirePn
        [void]$caroWheels.Add(@{ hc=$hc; sn=$sn; fh=$fh; pnTire=$tirePn; pnWheel=$mapping.pnWheel; type=$mapping.type; position=$mapping.position; designation=$mapping.designation })
    }
    $wb.Close($false)
    Write-Log "Roues CARO: $($caroWheels.Count)" "Green"
} finally {
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
}

Write-Log "Chargement Supabase..." "Cyan"
$raw = Invoke-SB "GET" "wheels?select=*"
$sbWheels = $raw | ForEach-Object {
    $obj = if ($_.data) { $_.data } else { $_ }
    $obj | Add-Member -NotePropertyName "_id" -NotePropertyValue $_.id -Force
    # Store raw data for merging on update
    $rawCopy = @{}
    if ($_.data) {
        $_.data.PSObject.Properties | ForEach-Object { $rawCopy[$_.Name] = $_.Value }
    }
    $obj | Add-Member -NotePropertyName "_rawData" -NotePropertyValue $rawCopy -Force
    $obj
}
Write-Log "Roues app: $($sbWheels.Count)" "Gray"

$created=0; $modified=0; $removedHC=0
$notifications = [System.Collections.ArrayList]::new()
$caroSNs = $caroWheels | ForEach-Object { $_.sn }

foreach ($caro in $caroWheels) {
    $match = $sbWheels | Where-Object { $_.serialNumber -eq $caro.sn } | Select-Object -First 1
    $itemData = @{
        installedOnHC  = $caro.hc
        serialNumber   = $caro.sn
        flightHours    = $caro.fh
        serviceability = "Serviceable"
        pnTire         = $caro.pnTire
        pnWheel        = $caro.pnWheel
        type           = $caro.type
        position       = $caro.position
        designation    = $caro.designation
    }
    if ($null -ne $match) {
        # Data is stored as JSONB in 'data' column - merge with existing
        $existingData = if ($match._rawData) { $match._rawData } else { @{} }
        foreach ($key in $itemData.Keys) { $existingData[$key] = $itemData[$key] }
        $patchBody = @{ data = $existingData }
        try { Invoke-SB "PATCH" "wheels?id=eq.$($match._id)" $patchBody | Out-Null; Write-Log "  MODIFIE S/N $($caro.sn) HC $($caro.hc)" "Green"; $modified++ }
        catch { Write-Log "  ERREUR PATCH $($caro.sn): $($_.Exception.Message)" "Red" }
    } else {
        $newId = [string][DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $itemData["id"] = $newId
        try { Invoke-SB "POST" "wheels" @{ id=$newId; data=$itemData } | Out-Null; Write-Log "  CREE S/N $($caro.sn) HC $($caro.hc)" "Yellow"; $created++ }
        catch { Write-Log "  ERREUR POST $($caro.sn): $($_.Exception.Message)" "Red" }
    }
}

$wheelsWithHC = $sbWheels | Where-Object { $_.installedOnHC -and $_.installedOnHC.Trim() -ne "" }
foreach ($w in $wheelsWithHC) {
    if ($w.serialNumber -notin $caroSNs) {
        [void]$notifications.Add("S/N $($w.serialNumber) plus dans CARO (etait: $($w.installedOnHC))")
        try { Invoke-SB "PATCH" "wheels?id=eq.$($w._id)" @{ installedOnHC="" } | Out-Null; Write-Log "  HC RETIRE S/N $($w.serialNumber)" "Yellow"; $removedHC++ }
        catch { Write-Log "  ERREUR HC $($w.serialNumber): $($_.Exception.Message)" "Red" }
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Sync Termine: +$created crees, ~$modified modifies, $removedHC HC retires" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

if ($notifications.Count -gt 0) {
    Write-Host ""
    Write-Host "NOTIFICATIONS - Roues plus dans CARO:" -ForegroundColor Yellow
    foreach ($n in $notifications) { Write-Host "  [!] $n" -ForegroundColor Yellow }
}

Write-Log "=== Fin: +$created crees ~$modified modifies $removedHC HC retires ===" "Cyan"
Write-Host ""
pause
