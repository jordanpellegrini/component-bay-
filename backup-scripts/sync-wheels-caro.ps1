# Components Bay - Wheel Sync from CARO + Kardex
# Logique: CARO = source principale, Kardex = cross-check par HC

$CARO_FILE    = "C:\Users\jpellegrini\Desktop\APP 5.5\CARO update\C.A.R.O. 2.6.1.xlsm"
$KARDEX_DIR   = "C:\Users\jpellegrini\Desktop\APP 5.5\CARO update"
$SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"
$LOG_DIR      = "$env:USERPROFILE\Documents\ComponentsBay_Backups"
$LOG_FILE     = "$LOG_DIR\wheel_sync_log.txt"

$MLG_FILTER_PN = "S324F1011104"
$NLG_FILTER_PN = "S324F1111103"
$CARO_TIRE_PNS = @("S324F1023200","S324F1022200","S324F1121200")

# ── HELPERS ───────────────────────────────────────────────────────────────────

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

function Parse-InstalledDate([string]$dateStr) {
    if (-not $dateStr -or $dateStr.Trim() -eq "") { return [datetime]::MinValue }
    try { return [datetime]::Parse($dateStr, [System.Globalization.CultureInfo]::InvariantCulture) }
    catch { try { return [datetime]::Parse($dateStr) } catch { return [datetime]::MinValue } }
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

# ── LECTURE CARO ──────────────────────────────────────────────────────────────

function Read-Caro([string]$file) {
    $xl = New-Object -ComObject Excel.Application
    $xl.Visible = $false; $xl.DisplayAlerts = $false
    $wheels = [System.Collections.ArrayList]::new()
    try {
        $wb = $xl.Workbooks.Open($file)
        $ws = $null
        foreach ($s in $wb.Sheets) { if ($s.Name -match "ardex|Kardex") { $ws = $s; break } }
        if ($null -eq $ws) { $ws = $wb.Sheets.Item(1) }
        Write-Log "CARO onglet: $($ws.Name)" "Gray"

        $lastCol = $ws.UsedRange.Columns.Count
        $cHC=0; $cPN=0; $cSN=0; $cFH=0; $cIN=0
        for ($c=1; $c -le $lastCol; $c++) {
            $h = ($ws.Cells.Item(1,$c).Text.Trim() -replace "\s","").ToUpper()
            if     ($h -match "^HC$|^H/C$")            { $cHC=$c }
            elseif ($h -match "^P/N$|^PN$")             { $cPN=$c }
            elseif ($h -match "^S/N$|^SN$")             { $cSN=$c }
            elseif ($h -match "ITEMFH|FHATIN|ITEM.*FH") { $cFH=$c }
            elseif ($h -match "INSTALL")                 { $cIN=$c }
        }
        if ($cIN -eq 0) { $cIN=9 }

        $lastRow = $ws.UsedRange.Rows.Count
        for ($r=2; $r -le $lastRow; $r++) {
            $pn = ($ws.Cells.Item($r,$cPN).Text.Trim() -replace "\s","").ToUpper()
            if ($pn -ne $MLG_FILTER_PN.ToUpper() -and $pn -ne $NLG_FILTER_PN.ToUpper()) { continue }
            $hc      = $ws.Cells.Item($r,$cHC).Text.Trim()
            $sn      = $ws.Cells.Item($r,$cSN).Text.Trim()
            $fh      = if ($cFH -gt 0) { $ws.Cells.Item($r,$cFH).Text.Trim() } else { "" }
            $instStr = $ws.Cells.Item($r,$cIN).Text.Trim()
            if (-not $hc -or -not $sn) { continue }
            $tirePn = if ($pn -eq $NLG_FILTER_PN.ToUpper()) { "S324F1121200" } else { Get-TirePN $hc }
            $map = Get-Mapping $tirePn
            [void]$wheels.Add(@{
                hc=($hc -replace "/.*",""); sn=$sn; fh=$fh; pnTire=$tirePn
                pnWheel=$map.pnWheel; type=$map.type; position=$map.position
                designation=$map.designation; installedDate=Parse-InstalledDate $instStr
                installedStr=$instStr; source="CARO"
            })
        }
        $wb.Close($false)
    } finally {
        $xl.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
    }
    return $wheels
}

# ── LECTURE KARDEX (tous les CAIMAN-QA*.xlsx) ─────────────────────────────────

function Read-AllKardex([string]$rootDir) {
    $files = Get-ChildItem -Path $rootDir -Filter "CAIMAN-QA*.xlsx" -File -ErrorAction SilentlyContinue
    Write-Log "Fichiers Kardex trouves: $($files.Count)" "Gray"
    # kardexByHC = hashtable HC -> liste de roues dans ce fichier
    $kardexByHC  = @{}
    # kardexBySN  = hashtable SN -> roue (toutes sources confondues)
    $kardexBySN  = @{}

    $xl2 = New-Object -ComObject Excel.Application
    $xl2.Visible = $false; $xl2.DisplayAlerts = $false
    try {
        foreach ($file in $files) {
            $hcMatch = [regex]::Match($file.BaseName, "QA\d+")
            if (-not $hcMatch.Success) { continue }
            $hc = $hcMatch.Value
            if (-not $kardexByHC.ContainsKey($hc)) { $kardexByHC[$hc] = [System.Collections.ArrayList]::new() }

            try {
                $wb2 = $xl2.Workbooks.Open($file.FullName, 0, $true)
                $ws2 = $null
                foreach ($s in $wb2.Sheets) { if ($s.Name -match "ardex|Kardex") { $ws2 = $s; break } }
                if ($null -eq $ws2) { $wb2.Close($false); continue }

                $lastCol2 = $ws2.UsedRange.Columns.Count
                $cPN2=0; $cSN2=0; $cFH2=0; $cIN2=0
                for ($c=1; $c -le $lastCol2; $c++) {
                    $h = ($ws2.Cells.Item(1,$c).Text.Trim() -replace "\s","").ToUpper()
                    if     ($h -match "^P/N$|^PN$|PARTNUMBER")          { $cPN2=$c }
                    elseif ($h -match "^S/N$|^SN$|SERIALNUMBER")        { $cSN2=$c }
                    elseif ($h -match "CURRENTLY|CURRENTFH|CURRENTLYF") { $cFH2=$c }
                    elseif ($h -match "INSTALL")                          { $cIN2=$c }
                }
                if ($cPN2 -eq 0) { $cPN2=3 }
                if ($cSN2 -eq 0) { $cSN2=4 }
                if ($cFH2 -eq 0) { $cFH2=7 }
                if ($cIN2 -eq 0) { $cIN2=9 }

                $lastRow2 = $ws2.UsedRange.Rows.Count
                for ($r=2; $r -le $lastRow2; $r++) {
                    $pn = ($ws2.Cells.Item($r,$cPN2).Text.Trim() -replace "\s","").ToUpper()
                    if ($pn -ne $MLG_FILTER_PN.ToUpper() -and $pn -ne $NLG_FILTER_PN.ToUpper()) { continue }
                    $sn      = $ws2.Cells.Item($r,$cSN2).Text.Trim()
                    $fh      = $ws2.Cells.Item($r,$cFH2).Text.Trim()
                    $instStr = $ws2.Cells.Item($r,$cIN2).Text.Trim()
                    if (-not $sn) { continue }
                    $tirePn = if ($pn -eq $NLG_FILTER_PN.ToUpper()) { "S324F1121200" } else { Get-TirePN $hc }
                    $map = Get-Mapping $tirePn
                    $wheel = @{
                        hc=$hc; sn=$sn; fh=$fh; pnTire=$tirePn
                        pnWheel=$map.pnWheel; type=$map.type; position=$map.position
                        designation=$map.designation; installedDate=Parse-InstalledDate $instStr
                        installedStr=$instStr; source=$file.Name
                    }
                    [void]$kardexByHC[$hc].Add($wheel)
                    # Pour recherche par SN dans tous les fichiers
                    if (-not $kardexBySN.ContainsKey($sn)) {
                        $kardexBySN[$sn] = [System.Collections.ArrayList]::new()
                    }
                    [void]$kardexBySN[$sn].Add($wheel)
                }
                $wb2.Close($false)
                Write-Log "  $($file.Name) -> $($kardexByHC[$hc].Count) roues" "Gray"
            } catch {
                Write-Log "  ERREUR $($file.Name): $($_.Exception.Message)" "Red"
                try { $wb2.Close($false) } catch {}
            }
        }
    } finally {
        $xl2.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl2) | Out-Null
    }
    return @{ byHC=$kardexByHC; bySN=$kardexBySN }
}

# ── MAIN ──────────────────────────────────────────────────────────────────────

New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
Write-Log "=== Wheel Sync Started ===" "Cyan"

if (-not (Test-Path $CARO_FILE)) { Write-Log "ERREUR: $CARO_FILE introuvable" "Red"; exit 1 }

Write-Log "Lecture CARO..." "Cyan"
$caroWheels = Read-Caro $CARO_FILE
Write-Log "Roues CARO: $($caroWheels.Count)" "Green"

Write-Log "Lecture fichiers Kardex..." "Cyan"
$kardex = Read-AllKardex $KARDEX_DIR
$kardexByHC = $kardex.byHC
$kardexBySN = $kardex.bySN
Write-Log "Kardex charge: $($kardexBySN.Count) S/N uniques" "Green"

# ── CROSS-CHECK CARO vs KARDEX ────────────────────────────────────────────────
# Pour chaque roue CARO, verifier dans le fichier Kardex du meme HC
# Resultat: liste de roues "actives" avec flag snMismatch si besoin

$activeWheels   = [System.Collections.ArrayList]::new()  # roues a mettre Serviceable
$mismatchReport = [System.Collections.ArrayList]::new()  # mismatches a signaler

$caroSNs = $caroWheels | ForEach-Object { $_.sn }

foreach ($caro in $caroWheels) {
    $hc = $caro.hc
    $sn = $caro.sn

    # Chercher les roues Kardex pour ce meme HC et meme type
    $kardexForHC = @()
    if ($kardexByHC.ContainsKey($hc)) {
        $kardexForHC = $kardexByHC[$hc] | Where-Object { $_.pnWheel -eq $caro.pnWheel }
    }

    if ($kardexForHC.Count -eq 0) {
        # Pas de fichier Kardex pour ce HC -> on fait confiance au CARO
        $caro["snMismatch"] = $false
        [void]$activeWheels.Add($caro)
        continue
    }

    # Chercher si le S/N CARO existe dans le Kardex de ce HC
    $kardexMatch = $kardexForHC | Where-Object { $_.sn -eq $sn } | Select-Object -First 1

    if ($null -ne $kardexMatch) {
        # S/N identique -> OK, on garde CARO
        $caro["snMismatch"] = $false
        [void]$activeWheels.Add($caro)
    } else {
        # S/N different entre CARO et Kardex pour ce HC
        # Comparer les dates INSTALLED - prendre le plus recent
        $kardexBest = $kardexForHC | Sort-Object { $_.installedDate } -Descending | Select-Object -First 1

        # Verifier si le S/N CARO existe dans un AUTRE fichier Kardex
        $caroSnInOtherKardex = $null
        if ($kardexBySN.ContainsKey($sn)) {
            $caroSnInOtherKardex = $kardexBySN[$sn] | Where-Object { $_.hc -ne $hc } | Select-Object -First 1
        }

        if ($caro.installedDate -ge $kardexBest.installedDate) {
            # CARO plus recent -> garder CARO, signaler mismatch
            $caro["snMismatch"] = $true
            [void]$activeWheels.Add($caro)
            [void]$mismatchReport.Add("HC=$hc TYPE=$($caro.type): CARO SN=$sn ($($caro.installedStr)) vs Kardex SN=$($kardexBest.sn) ($($kardexBest.installedStr)) -> CARO retenu$(if ($caroSnInOtherKardex) { ' | SN CARO aussi dans ' + $caroSnInOtherKardex.source + ' HC=' + $caroSnInOtherKardex.hc })")
        } else {
            # Kardex plus recent -> prendre Kardex, signaler mismatch
            $kardexBest["snMismatch"] = $true
            [void]$activeWheels.Add($kardexBest)
            [void]$mismatchReport.Add("HC=$hc TYPE=$($caro.type): Kardex SN=$($kardexBest.sn) ($($kardexBest.installedStr)) > CARO SN=$sn ($($caro.installedStr)) -> Kardex retenu$(if ($caroSnInOtherKardex) { ' | SN CARO aussi dans ' + $caroSnInOtherKardex.source + ' HC=' + $caroSnInOtherKardex.hc })")
        }
    }
}

# Dedup par S/N (au cas ou un meme S/N apparait deux fois dans CARO)
$activeWheelsBySN = @{}
foreach ($w in $activeWheels) {
    if (-not $activeWheelsBySN.ContainsKey($w.sn)) {
        $activeWheelsBySN[$w.sn] = $w
    }
}
$activeSNs = $activeWheelsBySN.Keys

Write-Log "Roues actives apres cross-check: $($activeWheelsBySN.Count)" "Cyan"
if ($mismatchReport.Count -gt 0) {
    Write-Log "MISMATCHES detectes: $($mismatchReport.Count)" "Yellow"
    foreach ($m in $mismatchReport) { Write-Log "  >> $m" "Yellow" }
}

# ── LOAD SUPABASE ─────────────────────────────────────────────────────────────

Write-Log "Chargement Supabase..." "Cyan"
$raw = Invoke-SB "GET" "wheels?select=*" $null
$sbWheels = $raw | ForEach-Object {
    $obj = if ($_.data) { $_.data } else { $_ }
    $obj | Add-Member -NotePropertyName "_id"   -NotePropertyValue $_.id   -Force
    $obj | Add-Member -NotePropertyName "_data"  -NotePropertyValue $_.data -Force
    $obj
}
Write-Log "Roues Supabase: $($sbWheels.Count)" "Gray"

# ── PHASE 1 : CALCUL DU PLAN ──────────────────────────────────────────────────

$planCreate = [System.Collections.ArrayList]::new()
$planModify = [System.Collections.ArrayList]::new()
$planDepose = [System.Collections.ArrayList]::new()

foreach ($sn in $activeSNs) {
    $wheel = $activeWheelsBySN[$sn]
    $match = $sbWheels | Where-Object { $_.serialNumber -eq $sn } | Select-Object -First 1
    if ($null -ne $match) {
        [void]$planModify.Add(@{ wheel=$wheel; match=$match })
    } else {
        [void]$planCreate.Add(@{ wheel=$wheel })
    }
}

$caroInApp = $sbWheels | Where-Object {
    ($_.fromCaro -eq $true) -or ($_.pnTire -in $CARO_TIRE_PNS)
} | Where-Object {
    $_.installedOnHC -and $_.installedOnHC.Trim() -ne ""
}
foreach ($w in $caroInApp) {
    if ($w.serialNumber -notin $activeSNs) {
        [void]$planDepose.Add($w)
    }
}

# ── AFFICHAGE DU PLAN ─────────────────────────────────────────────────────────

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PLAN DE SYNCHRONISATION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "  CREES    : $($planCreate.Count)" -ForegroundColor Yellow
foreach ($p in $planCreate) {
    $flag = if ($p.wheel.snMismatch) { " [!MISMATCH]" } else { "" }
    Write-Host "    + S/N=$($p.wheel.sn)  HC=$($p.wheel.hc)  FH=$($p.wheel.fh)  [$($p.wheel.source)]$flag" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  MODIFIES : $($planModify.Count)" -ForegroundColor Green
foreach ($p in $planModify) {
    $flag = if ($p.wheel.snMismatch) { " [!MISMATCH]" } else { "" }
    Write-Host "    ~ S/N=$($p.wheel.sn)  HC=$($p.wheel.hc)  FH=$($p.wheel.fh)  [$($p.wheel.source)]$flag" -ForegroundColor Green
}

Write-Host ""
Write-Host "  DEPOSES  : $($planDepose.Count)" -ForegroundColor Magenta
foreach ($w in $planDepose) {
    Write-Host "    ! S/N=$($w.serialNumber)  HC=$($w.installedOnHC)  -> Unserviceable" -ForegroundColor Magenta
}

if ($mismatchReport.Count -gt 0) {
    Write-Host ""
    Write-Host "  MISMATCHES S/N CARO vs KARDEX :" -ForegroundColor Red
    foreach ($m in $mismatchReport) { Write-Host "    >> $m" -ForegroundColor Red }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan

# ── CONFIRMATION ──────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  Confirmer et appliquer ces modifications ? (O/N) : " -ForegroundColor White -NoNewline
$confirm = Read-Host
if ($confirm -notmatch "^[Oo]$") {
    Write-Host ""
    Write-Host "  Annule - aucune modification effectuee." -ForegroundColor Red
    Write-Host ""
    Write-Host "Appuyez sur une touche pour fermer..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 0
}

# ── PHASE 2 : EXECUTION ───────────────────────────────────────────────────────

Write-Host ""
Write-Log "Execution du plan..." "Cyan"
$created=0; $modified=0; $removedHC=0

foreach ($p in $planCreate) {
    $w = $p.wheel
    $newId = [string][DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $newData = @{
        id=($newId); installedOnHC=($w.hc); serialNumber=($w.sn); flightHours=($w.fh)
        serviceability="Serviceable"; pnTire=($w.pnTire); pnWheel=($w.pnWheel)
        type=($w.type); position=($w.position); designation=($w.designation)
        fromCaro=$true; source=($w.source); snMismatch=($w.snMismatch -eq $true)
    }
    try {
        Invoke-SB "POST" "wheels" @{ id=$newId; data=$newData } | Out-Null
        Write-Log "  CREE S/N=$($w.sn) HC=$($w.hc) [$($w.source)]$(if ($w.snMismatch) { ' [MISMATCH]' })" "Yellow"
        $created++
    } catch { Write-Log "  ERREUR POST $($w.sn): $($_.Exception.Message)" "Red" }
}

foreach ($p in $planModify) {
    $w = $p.wheel; $match = $p.match
    $dataObj = @{}
    if ($match._data) { $match._data.PSObject.Properties | ForEach-Object { $dataObj[$_.Name] = $_.Value } }
    $dataObj["installedOnHC"]  = $w.hc
    $dataObj["serialNumber"]   = $w.sn
    $dataObj["flightHours"]    = $w.fh
    $dataObj["serviceability"] = "Serviceable"
    $dataObj["pnTire"]         = $w.pnTire
    $dataObj["pnWheel"]        = $w.pnWheel
    $dataObj["type"]           = $w.type
    $dataObj["position"]       = $w.position
    $dataObj["designation"]    = $w.designation
    $dataObj["fromCaro"]       = $true
    $dataObj["source"]         = $w.source
    $dataObj["snMismatch"]     = ($w.snMismatch -eq $true)
    try {
        Invoke-SB "PATCH" "wheels?id=eq.$($match._id)" @{ data=$dataObj } | Out-Null
        Write-Log "  MODIFIE S/N=$($w.sn) HC=$($w.hc) [$($w.source)]$(if ($w.snMismatch) { ' [MISMATCH]' })" "Green"
        $modified++
    } catch { Write-Log "  ERREUR PATCH $($w.sn): $($_.Exception.Message)" "Red" }
}

foreach ($w in $planDepose) {
    $dataObj = @{}
    if ($w._data) { $w._data.PSObject.Properties | ForEach-Object { $dataObj[$_.Name] = $_.Value } }
    $dataObj["installedOnHC"]  = ""
    $dataObj["removeFromHC"]   = $w.installedOnHC
    $dataObj["serviceability"] = "Unserviceable"
    $dataObj["snMismatch"]     = $false
    try {
        Invoke-SB "PATCH" "wheels?id=eq.$($w._id)" @{ data=$dataObj } | Out-Null
        Write-Log "  DEPOSE S/N=$($w.serialNumber) (etait $($w.installedOnHC)) -> Unserviceable" "Yellow"
        $removedHC++
    } catch { Write-Log "  ERREUR DEPOSE $($w.serialNumber): $($_.Exception.Message)" "Red" }
}

# ── SUMMARY ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Sync Termine" -ForegroundColor Cyan
Write-Host "  Crees    : $created" -ForegroundColor Yellow
Write-Host "  Modifies : $modified" -ForegroundColor Green
Write-Host "  Deposes  : $removedHC" -ForegroundColor Magenta
Write-Host "  Mismatches signales : $($mismatchReport.Count)" -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Cyan

Write-Log "=== Fin: +$created crees ~$modified modifies $removedHC deposes $($mismatchReport.Count) mismatches ===" "Cyan"
Write-Host ""
Write-Host "Appuyez sur une touche pour fermer..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
