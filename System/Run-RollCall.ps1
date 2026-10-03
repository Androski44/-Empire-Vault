$VaultRoot = "C:\0-8-Empire-Vault"
$AgentsDir = Join-Path $VaultRoot "Agents"
$CsvPath   = "C:\Epyon\rollcall.csv"

Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   OMEGAEMPIRE — Roll-Call Generator           " -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

if (-not (Test-Path $AgentsDir)) {
    Write-Host "[ERROR] Agents directory not found at $AgentsDir" -ForegroundColor Red
    exit
}

$notes = Get-ChildItem -Path $AgentsDir -Filter "*.md"
Write-Host "[*] Scanning $($notes.Count) vault notes to generate roll-call..." -ForegroundColor Cyan

$rollCallData = @()

foreach ($note in $notes) {
    $content = Get-Content -Path $note.FullName -Raw -Encoding utf8
    $frontmatter = @{}
    if ($content -match '(?s)^---\r?\n(.*?)\r?\n---') {
        foreach ($line in ($Matches[1] -split '\r?\n')) {
            if ($line -match '^\s*([a-zA-Z_]+)\s*:\s*"?([^"]*)"?\s*$') {
                $frontmatter[$Matches[1].ToLower()] = $Matches[2].Trim()
            }
        }
    }

    $agentName = if ($frontmatter['agent']) { $frontmatter['agent'] } else { $note.BaseName }
    
    $rollCallData += [PSCustomObject]@{
        Name   = $agentName
        Planet = if ($frontmatter['planet']) { $frontmatter['planet'] } else { 'Vault' }
        Job    = if ($frontmatter['job']) { $frontmatter['job'] } else { 'Agent' }
        Status = if ($frontmatter['status']) { $frontmatter['status'] } else { 'dormant' }
    }
}

$csvDir = Split-Path $CsvPath
if (-not (Test-Path $csvDir)) { New-Item -ItemType Directory -Path $csvDir -Force | Out-Null }

$rollCallData | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding utf8

Write-Host ""
Write-Host "[SUCCESS] Roll-call generated successfully!" -ForegroundColor Green
Write-Host "  Total Recorded : $($rollCallData.Count)"
Write-Host "  Output CSV     : $CsvPath"
Write-Host ""