$VaultRoot = "C:\0-8-Empire-Vault"
$AgentsDir = Join-Path $VaultRoot "Agents"
$CsvPath   = "C:\Epyon\rollcall.csv"
$MasterCsv = Join-Path $VaultRoot "master_registry.csv"
$MasterJson = Join-Path $VaultRoot "master_registry.json"

Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   OMEGAEMPIRE — Restoring True Reconciliation " -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

$csvRecords = @{}
if (Test-Path $CsvPath) {
    Write-Host "[*] Loading source roll-call: $CsvPath" -ForegroundColor Cyan
    $csvData = Import-Csv -Path $CsvPath
    foreach ($row in $csvData) {
        $key = if ($row.Name) { $row.Name.Trim().ToLower() } elseif ($row.Agent) { $row.Agent.Trim().ToLower() } else { "" }
        if ($key) { $csvRecords[$key] = $row }
    }
    Write-Host "    Loaded $($csvData.Count) records from CSV." -ForegroundColor Green
} else {
    Write-Host "[ERROR] Roll-call CSV not found at $CsvPath!" -ForegroundColor Red
    exit
}

Write-Host "[*] Scanning vault notes in $AgentsDir..." -ForegroundColor Cyan
$notes = Get-ChildItem -Path $AgentsDir -Filter "*.md"
Write-Host "    Found $($notes.Count) notes on disk." -ForegroundColor Green

$rows = @()
$matched = 0

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
    $lookupKey = $agentName.Trim().ToLower()
    $csvMatch = $csvRecords[$lookupKey]

    $status = 'DORMANT'
    if ($csvMatch) {
        $matched++
        $status = if ($frontmatter['status'] -eq 'active') { 'ACTIVE' } else { 'DORMANT' }
    } else {
        $status = 'ORPHAN-NOTE'
    }

    $rows += [PSCustomObject]@{
        Agent     = $agentName
        Planet    = if ($frontmatter['planet']) { $frontmatter['planet'] } else { 'Vault' }
        Job       = if ($frontmatter['job']) { $frontmatter['job'] } else { 'Agent' }
        Status    = $status
        VaultNote = $note.Name
    }
}

foreach ($key in $csvRecords.Keys) {
    $r = $csvRecords[$key]
    $name = if ($r.Name) { $r.Name } else { $r.Agent }
    $found = $false
    foreach ($row in $rows) {
        if ($row.Agent.Trim().ToLower() -eq $key) { $found = $true; break }
    }
    if (-not $found) {
        $rows += [PSCustomObject]@{
            Agent     = $name
            Planet    = if ($r.Planet) { $r.Planet } else { 'External' }
            Job       = if ($r.Job) { $r.Job } else { 'Agent' }
            Status    = 'MISSING-NOTE'
            VaultNote = 'MISSING'
        }
    }
}

$rows | Export-Csv -Path $MasterCsv -NoTypeInformation -Encoding utf8
$rows | ConvertTo-Json -Depth 3 | Set-Content -Path $MasterJson -Encoding utf8

$active = @($rows | Where-Object { $_.Status -eq 'ACTIVE' }).Count
$dormant = @($rows | Where-Object { $_.Status -eq 'DORMANT' }).Count
$orphan = @($rows | Where-Object { $_.Status -eq 'ORPHAN-NOTE' }).Count
$missing = @($rows | Where-Object { $_.Status -eq 'MISSING-NOTE' }).Count

Write-Host ""
Write-Host "Reconciliation Restored:" -ForegroundColor Green
Write-Host "  Matched to roll call: $matched / $($notes.Count)"
Write-Host "  ACTIVE    : $active"
Write-Host "  DORMANT   : $dormant"
Write-Host "  ORPHAN    : $orphan"
Write-Host "  MISSING   : $missing"
Write-Host "  Master CSV: $MasterCsv"
Write-Host ""