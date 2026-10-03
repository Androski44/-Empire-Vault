$VaultRoot = "C:\0-8-Empire-Vault"
$AgentsDir = Join-Path $VaultRoot "Agents"

Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   OMEGAEMPIRE — Smart Agent Activation Engine " -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

if (-not (Test-Path $AgentsDir)) { 
    Write-Host "[ERROR] Agents directory not found at $AgentsDir" -ForegroundColor Red
    exit 
}

$wokenCount = 0
$notes = Get-ChildItem -Path $AgentsDir -Filter "*.md"
Write-Host "[*] Scanning $($notes.Count) vault notes for activation criteria..." -ForegroundColor Cyan

foreach ($note in $notes) {
    $content = Get-Content -Path $note.FullName -Raw -Encoding utf8
    
    # Flexible match for VERIFY-ON-PC and dormant status
    if ($content -match 'wakeup_tag\s*:\s*[''"]?VERIFY-ON-PC[''"]?' -and $content -match 'status\s*:\s*[''"]?dormant[''"]?') {
        $newContent = $content -replace 'status\s*:\s*[''"]?dormant[''"]?', 'status: "active"'
        [System.IO.File]::WriteAllText($note.FullName, $newContent, [System.Text.Encoding]::UTF8)
        Write-Host "  [WOKEN] $($note.BaseName)" -ForegroundColor Green
        $wokenCount++
    }
}

Write-Host ""
Write-Host "[SUCCESS] Successfully activated $wokenCount agents on disk." -ForegroundColor Green

$activeCount = 0
$dormantCount = 0
foreach ($file in $notes) {
    $text = Get-Content -Path $file.FullName -Raw -Encoding utf8
    if ($text -match 'status\s*:\s*[''"]?active[''"]?') {
        $activeCount++
    } else {
        $dormantCount++
    }
}

Write-Host ""
Write-Host "  Updated Roster Telemetry:" -ForegroundColor Cyan
Write-Host "  -------------------------" -ForegroundColor DarkGray
Write-Host "  ACTIVE:  $activeCount" -ForegroundColor Green
Write-Host "  DORMANT: $dormantCount" -ForegroundColor Gray
Write-Host ""