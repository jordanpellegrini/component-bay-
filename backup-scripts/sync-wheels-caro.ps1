# Components Bay - Wheel Sync from CARO
# CREATE + MODIFY only - NEVER delete or touch manual entries

$CARO_FILE    = "C:\Users\jpellegrini\Desktop\APP 5.5\CARO update\C.A.R.O. 2.6.1.xlsm"
$SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"
$LOG_DIR  = "$env:USERPROFILE\Documents\ComponentsBay_Backups"
$LOG_FILE = "$LOG_DIR\wheel_sync_log.txt"

$MLG_FILTER_PN = "S324F1011104"
$NLG_FILTER_PN = "S324F1111103"

# These are the pnTire values for CARO wheels - used to identify CARO entries
$CARO_TIRE_PNS = @("S324F1023200","S324F1022200","S324F1121200")

function Get-TirePN([string]$hc) {
    $m = [regex]::Match($hc, "QA(\d+)")
    if (-not $m.Success) { return "S324F1121200" }
    $num = [int]$m.Groups[1].Value
    if ($num -ge 250 -and $num -le 265) { return "S324F1023200" }
    if ($num -ge 266 -and $num -le 277) { return "S324F1022200" }
    return "S324F1121200"
}

function Get-Mapping([string]$tirePn) {
    switch ($tirePn) {
        "S324F1023200" { return @{ pnWheel="S324F1851861"; type="TTH";     position="MLG"; designation="MLG Wheel TTH" } }
        "S324F1022200" { return @{ pnWheel="S324F1851856"; type="NFH";     position="MLG"; designation="MLG Wheel NFH" } }
        default        { return @{ pnWheel="S324F1852853"; type="TTH/NFH"; position="NLG"; designation="NLG Wheel TTH/NFH" } }
    }
}

function Write-Log([string]$msg, [string]$col = "White") {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Write-Host $line -ForegroundColor $col
    Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8
}

function Invoke-SB([string]$method, [string]$ep, $body = $null) {
    $h = @{
        "apikey"        = $SUPABASE_KEY
        "Authorization" = "Bearer $SUPABASE_KEY"
        "Content-Type"  = "application/json"
        "Prefer"        = "return=representation"
    }
    $p = @{ Method=$method; Uri="$SUPABASE_URL/rest/v1/$ep"; Headers=$h; ErrorAction="Stop" }
    if ($null -ne $body) { $p["Body"] = ($body | ConvertTo-Json -Compress -Depth 10) }
    return Invoke-RestMethod @p
}

New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
Write-Log "=== Wheel Sync Started ===" "Cyan"

if (-not (Test-Path $CARO_FILE)) {
    Write-Log "ERREUR: Fichier introuvable: $CARO_FILE" "Red"
    pause; exit 1
}

# Read CARO Excel
Write-Log "Lecture CARO..." "Cyan"
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
$caroWheels = [System.Collections.ArrayList]::new()

try {
    $wb = $xl.Workbooks.Open($CARO_FILE)
    $ws = $null
    foreach ($s in $wb.Sheets) {
        if ($s.Name -match "ardex|Kardex") { $ws = $s; break }
    }
    if ($null -eq $ws) { $ws = $wb.Sheets.Item(1) }
    Write-Log "Onglet: $($ws.Name)" "Gray"

    $lastCol = $ws.UsedRange.Columns.Count
    $cHC=0; $cPN=0; $cSN=0; $cFH=0
    for ($c=1; $c -le $lastCol; $c++) {
        $h = ($ws.Cells.Item(1,$c).Text.Trim() -replace "\s","").ToUpper()
        if     ($h -match "^HC$|^H/C$")        { $cHC=$c }
        elseif ($h -match "^P/N$|^PN$")         { $cPN=$c }
        elseif ($h -match "^S/N$|^SN$")         { $cSN=$c }
        elseif ($h -match "ITEMFH|FHATIN|ITEM.*FH") { $cFH=$c }
    }
    Write-Log "Colonnes: HC=$cHC PN=$cPN SN=$cSN FH=$cFH" "Gray"

    $lastRow = $ws.UsedRange.Rows.Count
    for ($r=2; $r -le $lastRow; $r++) {
        $pn = ($ws.Cells.Item($r,$cPN).Text.Trim() -replace "\s","").ToUpper()
        if ($pn -ne $MLG_FILTER_PN.ToUpper() -and $pn -ne $NLG_FILTER_PN.ToUpper()) { continue }

        $hc  = $ws.Cells.Item($r,$cHC).Text.Trim()
        $sn  = $ws.Cells.Item($r,$cSN).Text.Trim()
        $fh  = if ($cFH -gt 0) { $ws.Cells.Item($r,$cFH).Text.Trim() } else { "" }
        if (-not $hc -or -not $sn) { continue }

        $tirePn = Get-TirePN $hc
        $map    = Get-Mapping $tirePn

        [void]$caroWheels.Add(@{
            hc          = $hc
            sn          = $sn
            fh          = $fh
            pnTire      = $tirePn
            pnWheel     = $map.pnWheel
            type        = $map.type
            position    = $map.position
            designation = $map.designation
        })
    }
    $wb.Close($false)
    Write-Log "Roues CARO: $($caroWheels.Count)" "Green"
} finally {
    $xl.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
}

# Load Supabase
Write-Log "Chargement Supabase..." "Cyan"
$raw = Invoke-SB "GET" "wheels?select=*" $null
$sbWheels = $raw | ForEach-Object {
    $obj = if ($_.data) { $_.data } else { $_ }
    $obj | Add-Member -NotePropertyName "_id"  -NotePropertyValue $_.id   -Force
    $obj | Add-Member -NotePropertyName "_data" -NotePropertyValue $_.data -Force
    $obj
}
Write-Log "Roues app: $($sbWheels.Count)" "Gray"

$created=0; $modified=0; $removedHC=0
$notifications = [System.Collections.ArrayList]::new()
$caroSNs = $caroWheels | ForEach-Object { $_.sn }

# Process each CARO wheel
foreach ($caro in $caroWheels) {
    $match = $sbWheels | Where-Object { $_.serialNumber -eq $caro.sn } | Select-Object -First 1

    if ($null -ne $match) {
        # MODIFY - merge into existing data object
        $dataObj = @{}
        if ($match._data) {
            $match._data.PSObject.Properties | ForEach-Object { $dataObj[$_.Name] = $_.Value }
        }
        $dataObj["installedOnHC"]  = $caro.hc
        $dataObj["serialNumber"]   = $caro.sn
        $dataObj["flightHours"]    = $caro.fh
        $dataObj["serviceability"] = "Serviceable"
        $dataObj["pnTire"]         = $caro.pnTire
        $dataObj["pnWheel"]        = $caro.pnWheel
        $dataObj["type"]           = $caro.type
        $dataObj["position"]       = $caro.position
        $dataObj["designation"]    = $caro.designation
        $dataObj["fromCaro"]       = $true

        try {
            Invoke-SB "PATCH" "wheels?id=eq.$($match._id)" @{ data=$dataObj } | Out-Null
            Write-Log "  MODIFIE S/N=$($caro.sn) HC=$($caro.hc) FH=$($caro.fh) pnTire=$($caro.pnTire)" "Green"
            $modified++
        } catch {
            Write-Log "  ERREUR PATCH $($caro.sn): $($_.Exception.Message)" "Red"
        }
    } else {
        # CREATE new
        $newId   = [string][DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $newData = @{
            id             = $newId
            installedOnHC  = $caro.hc
            serialNumber   = $caro.sn
            flightHours    = $caro.fh
            serviceability = "Serviceable"
            pnTire         = $caro.pnTire
            pnWheel        = $caro.pnWheel
            type           = $caro.type
            position       = $caro.position
            designation    = $caro.designation
            fromCaro       = $true
        }
        try {
            Invoke-SB "POST" "wheels" @{ id=$newId; data=$newData } | Out-Null
            Write-Log "  CREE S/N=$($caro.sn) HC=$($caro.hc) FH=$($caro.fh) pnTire=$($caro.pnTire)" "Yellow"
            $created++
        } catch {
            Write-Log "  ERREUR POST $($caro.sn): $($_.Exception.Message)" "Red"
        }
    }
}

# Remove H/C from CARO wheels no longer in file
# ONLY touch wheels that came from CARO (fromCaro=true OR pnTire in CARO list)
$caroInApp = $sbWheels | Where-Object {
    ($_.fromCaro -eq $true) -or ($_.pnTire -in $CARO_TIRE_PNS)
} | Where-Object {
    $_.installedOnHC -and $_.installedOnHC.Trim() -ne ""
}

foreach ($w in $caroInApp) {
    if ($w.serialNumber -notin $caroSNs) {
        [void]$notifications.Add("S/N $($w.serialNumber) plus dans CARO (etait HC: $($w.installedOnHC))")

        $dataObj = @{}
        if ($w._data) { $w._data.PSObject.Properties | ForEach-Object { $dataObj[$_.Name] = $_.Value } }
        $dataObj["installedOnHC"] = ""

        try {
            Invoke-SB "PATCH" "wheels?id=eq.$($w._id)" @{ data=$dataObj } | Out-Null
            Write-Log "  HC RETIRE S/N=$($w.serialNumber) (etait $($w.installedOnHC))" "Yellow"
            $removedHC++
        } catch {
            Write-Log "  ERREUR HC $($w.serialNumber): $($_.Exception.Message)" "Red"
        }
    }
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Sync Termine" -ForegroundColor Cyan
Write-Host "  Crees    : $created" -ForegroundColor Yellow
Write-Host "  Modifies : $modified" -ForegroundColor Green
Write-Host "  HC retires (pas de suppression) : $removedHC" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Cyan

if ($notifications.Count -gt 0) {
    Write-Host ""
    Write-Host "NOTIFICATIONS - Plus dans CARO:" -ForegroundColor Yellow
    foreach ($n in $notifications) { Write-Host "  [!] $n" -ForegroundColor Yellow }
}

Write-Log "=== Fin: +$created crees ~$modified modifies $removedHC HC retires ===" "Cyan"
Write-Host ""
pause
