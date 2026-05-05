# ============================================================
# Components Bay - Daily Email Report
# Envoie un recap par email via Outlook tous les matins
# Destinataire : jpellegrini@advanced-sm.com
# ============================================================

$SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"
$TO_EMAIL     = "jpellegrini@advanced-sm.com"
$LOG_DIR      = "$env:USERPROFILE\Documents\ComponentsBay_Backups"
$LOG_FILE     = "$LOG_DIR\daily_report_log.txt"

function Write-Log { param([string]$Msg,[string]$Col="White"); $line="[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Msg"; Write-Host $line -ForegroundColor $Col; Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8 }

New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
Write-Log "--- Daily Report Started ---" "Cyan"

# ============================================================
# Verification : mail deja envoye aujourd'hui ?
# ============================================================
$todayStr = (Get-Date -Format 'yyyy-MM-dd')
$alreadySent = $false
if (Test-Path $LOG_FILE) {
    $alreadySent = (Get-Content $LOG_FILE -Encoding UTF8 | Where-Object { $_ -match $todayStr -and $_ -match "Email envoye" }) -ne $null
}
if ($alreadySent) {
    Write-Log "Email deja envoye aujourd hui ($todayStr) - script arrete." "Yellow"
    exit 0
}
Write-Log "Aucun envoi detecte aujourd hui - on continue." "Green"

$hdrs = @{
    "apikey"        = $SUPABASE_KEY
    "Authorization" = "Bearer $SUPABASE_KEY"
    "Content-Type"  = "application/json"
}

# All modules to check
$MODULES = @(
    @{ name="EFS Float";     table="efs";          dateFields=@("next18M","next36M") },
    @{ name="EFS Cylinders"; table="efs_cylinders"; dateFields=@("next18M","next60M") },
    @{ name="Life Raft";     table="liferafts";    dateFields=@("nextInspection") },
    @{ name="Wheel";         table="wheels";       dateFields=@("nextInspection") },
    @{ name="Troop Seat";    table="troopseats";   dateFields=@("nextInspection") },
    @{ name="Avionic";       table="avionic";      dateFields=@("nextInspection","next1Y","next2Y") },
    @{ name="Engine";        table="engine";       dateFields=@("nextInspection") },
    @{ name="Rotor Bay";     table="rotorbay";     dateFields=@("nextInspection") },
    @{ name="Composite";     table="composite";    dateFields=@("nextInspection") },
    @{ name="Maintenance";   table="maintenance";  dateFields=@("nextInspection") },
    @{ name="IAFT/EAFT";     table="iafteaft";     dateFields=@("nextInspection","next24M","next60M") },
    @{ name="POL";           table="pol";          dateFields=@("nextInspection") },
    @{ name="Tools";         table="tools";        dateFields=@("nextInspection") }
)

$today      = (Get-Date).Date
$in90       = $today.AddDays(90)
$allUS      = @()
$allWithin90 = @()
$totalItems = 0

foreach ($mod in $MODULES) {
    try {
        $resp = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/$($mod.table)?select=*" -Headers $hdrs -Method Get
        $items = @(); if ($resp) { $items = @($resp) }
        $totalItems += $items.Count

        foreach ($row in $items) {
            $d = $row.data
            if ($d -is [string]) { $d = $d | ConvertFrom-Json }

            # Unserviceable
            if ($d.serviceability -eq "Unserviceable") {
                $allUS += [PSCustomObject]@{
                    Module      = $mod.name
                    Designation = $d.designation
                    PN          = if ($d.pnWheel) { $d.pnWheel } else { $d.partNumber }
                    SN          = $d.serialNumber
                    Reason      = $d.reason
                }
            }

            # Within 90 days (serviceable only)
            if ($d.serviceability -ne "Unserviceable") {
                foreach ($field in $mod.dateFields) {
                    $dateVal = $d.$field
                    # Also check inspectionData for avionic sonar
                    if (-not $dateVal -and $d.inspectionData) {
                        $dateVal = $d.inspectionData.$field
                    }
                    if ($dateVal) {
                        try {
                            $dt = [DateTime]::Parse($dateVal)
                            if ($dt -ge $today -and $dt -le $in90) {
                                $daysLeft = [int]($dt - $today).TotalDays
                                $allWithin90 += [PSCustomObject]@{
                                    Module      = $mod.name
                                    Designation = $d.designation
                                    PN          = if ($d.pnWheel) { $d.pnWheel } else { $d.partNumber }
                                    SN          = $d.serialNumber
                                    DueDate     = $dateVal
                                    DaysLeft    = $daysLeft
                                }
                            }
                        } catch {}
                    }
                }
            }
        }
        Write-Log "  $($mod.name): $($items.Count) items" "Gray"
    } catch {
        Write-Log "  ERREUR $($mod.name): $($_.Exception.Message)" "Red"
    }
}

# Sort within90 by days left
$allWithin90 = $allWithin90 | Sort-Object DaysLeft

Write-Log "Total: $totalItems items, $($allUS.Count) U/S, $($allWithin90.Count) within 90d" "Green"

# Always send email even if nothing to report

# ============================================================
# Build HTML email body
# ============================================================
$dateStr = Get-Date -Format "dddd dd MMMM yyyy"

# US table rows
$usRows = ""
if ($allUS.Count -gt 0) {
    foreach ($item in $allUS) {
        $usRows += "<tr><td style='padding:8px 12px;border-bottom:1px solid #fee2e2;'>$($item.Module)</td><td style='padding:8px 12px;border-bottom:1px solid #fee2e2;'>$($item.Designation)</td><td style='padding:8px 12px;border-bottom:1px solid #fee2e2;font-family:monospace;'>$($item.PN)</td><td style='padding:8px 12px;border-bottom:1px solid #fee2e2;'>$($item.SN)</td><td style='padding:8px 12px;border-bottom:1px solid #fee2e2;color:#dc2626;'>$($item.Reason)</td></tr>"
    }
}

# Within 90 table rows
$w90Rows = ""
if ($allWithin90.Count -gt 0) {
    foreach ($item in $allWithin90) {
        $color = if ($item.DaysLeft -le 30) { "#dc2626" } elseif ($item.DaysLeft -le 60) { "#d97706" } else { "#059669" }
        $bg    = if ($item.DaysLeft -le 30) { "#fef2f2" } elseif ($item.DaysLeft -le 60) { "#fffbeb" } else { "#f0fdf4" }
        $w90Rows += "<tr><td style='padding:8px 12px;border-bottom:1px solid #e5e7eb;'>$($item.Module)</td><td style='padding:8px 12px;border-bottom:1px solid #e5e7eb;'>$($item.Designation)</td><td style='padding:8px 12px;border-bottom:1px solid #e5e7eb;font-family:monospace;'>$($item.PN)</td><td style='padding:8px 12px;border-bottom:1px solid #e5e7eb;'>$($item.SN)</td><td style='padding:8px 12px;border-bottom:1px solid #e5e7eb;'>$($item.DueDate)</td><td style='padding:8px 12px;border-bottom:1px solid #e5e7eb;background:$bg;color:$color;font-weight:700;'>$($item.DaysLeft)d</td></tr>"
    }
}

$htmlBody = @"
<html><body style='font-family:Arial,sans-serif;background:#f8fafc;margin:0;padding:0;'>
<div style='max-width:900px;margin:0 auto;padding:20px;'>

  <!-- Header -->
  <div style='background:linear-gradient(135deg,#1a1a2e,#0f3460);color:white;border-radius:12px;padding:24px 28px;margin-bottom:20px;'>
    <div style='font-size:22px;font-weight:700;'>Components Bay Components Bay - Daily Report</div>
    <div style='font-size:13px;opacity:0.7;margin-top:4px;'>$dateStr</div>
  </div>

  <!-- Stats -->
  <div style='display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:20px;'>
    <div style='background:white;border-radius:10px;padding:16px 20px;border-left:4px solid #2563eb;'>
      <div style='font-size:28px;font-weight:700;color:#2563eb;'>$totalItems</div>
      <div style='font-size:12px;color:#94a3b8;text-transform:uppercase;'>Total Items</div>
    </div>
    <div style='background:white;border-radius:10px;padding:16px 20px;border-left:4px solid #dc2626;'>
      <div style='font-size:28px;font-weight:700;color:#dc2626;'>$($allUS.Count)</div>
      <div style='font-size:12px;color:#94a3b8;text-transform:uppercase;'>Unserviceable</div>
    </div>
    <div style='background:white;border-radius:10px;padding:16px 20px;border-left:4px solid #d97706;'>
      <div style='font-size:28px;font-weight:700;color:#d97706;'>$($allWithin90.Count)</div>
      <div style='font-size:12px;color:#94a3b8;text-transform:uppercase;'>Due Within 90 Days</div>
    </div>
  </div>

  <!-- Unserviceable -->
  $(if ($allUS.Count -gt 0) {
  "<div style='background:white;border-radius:10px;padding:20px;margin-bottom:20px;border:1px solid #e5e7eb;'>
    <div style='font-size:15px;font-weight:700;color:#dc2626;margin-bottom:14px;'>!! Unserviceable Items ($($allUS.Count))</div>
    <table style='width:100%;border-collapse:collapse;font-size:13px;'>
      <thead><tr style='background:#fef2f2;'>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>Module</th>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>Designation</th>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>P/N</th>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>S/N</th>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>Reason</th>
      </tr></thead>
      <tbody>$usRows</tbody>
    </table>
  </div>"
  })

  <!-- Within 90 Days -->
  $(if ($allWithin90.Count -gt 0) {
  "<div style='background:white;border-radius:10px;padding:20px;margin-bottom:20px;border:1px solid #e5e7eb;'>
    <div style='font-size:15px;font-weight:700;color:#d97706;margin-bottom:14px;'>>> Inspections Due Within 90 Days ($($allWithin90.Count))</div>
    <table style='width:100%;border-collapse:collapse;font-size:13px;'>
      <thead><tr style='background:#fffbeb;'>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>Module</th>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>Designation</th>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>P/N</th>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>S/N</th>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>Due Date</th>
        <th style='padding:10px 12px;text-align:left;font-size:11px;text-transform:uppercase;color:#6b7280;'>Days Left</th>
      </tr></thead>
      <tbody>$w90Rows</tbody>
    </table>
  </div>"
  })

  <!-- All Good banner -->
  $(if ($allUS.Count -eq 0 -and $allWithin90.Count -eq 0) {
  "<div style='background:#f0fdf4;border:1px solid #86efac;border-radius:10px;padding:20px;margin-bottom:20px;text-align:center;'><div style='font-size:28px;'>OK</div><div style='font-size:16px;font-weight:700;color:#15803d;margin-top:8px;'>All Good - No issues to report</div><div style='font-size:12px;color:#166534;margin-top:4px;'>All components are serviceable and no inspections due within 90 days</div></div>"
  })

  <!-- Footer -->
  <div style='text-align:center;font-size:11px;color:#94a3b8;padding:10px;'>
    Components Bay - ASM Maintenance | Generated automatically $(Get-Date -Format 'HH:mm')
  </div>

</div></body></html>
"@

# ============================================================
# Send via Outlook COM (sans elevation admin)
# ============================================================
Write-Log "Envoi email via Outlook..." "Yellow"
try {
    $outlook = New-Object -ComObject Outlook.Application
    $mail = $outlook.CreateItem(0)
    $mail.To = $TO_EMAIL
    $statusLabel = if ($allUS.Count -eq 0 -and $allWithin90.Count -eq 0) { "OK ALL GOOD" } else { "$($allUS.Count) U/S | $($allWithin90.Count) within 90d" }
    $mail.Subject = "Components Bay - Daily Report $(Get-Date -Format 'dd/MM/yyyy') | $statusLabel"
    $mail.HTMLBody = $htmlBody
    $mail.Send()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($mail) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
    Write-Log "Email envoye a $TO_EMAIL" "Green"
} catch {
    Write-Log "ERREUR envoi email: $($_.Exception.Message)" "Red"
}

Write-Log "--- Daily Report Done ---" "Cyan"
