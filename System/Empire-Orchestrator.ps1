param(
    [string]$VaultRoot = "C:\0-8-Empire-Vault",
    [switch]$ShowNeedsRuben
)

$LOG_DIR = Join-Path $VaultRoot "System\Logs"
$METRICS = Join-Path $VaultRoot "System\metrics.json"
$AgentsDir = Join-Path $VaultRoot "Agents"

if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
}

function Write-EmpireLog {
    param([string]$message, [string]$node = "Core", [string]$level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$level] [$node]: $message"
    $logFile = Join-Path $LOG_DIR "empire_master.log"
    Add-Content -Path $logFile -Value $entry -Encoding utf8
    Write-Host $entry -ForegroundColor Cyan
}

function Get-AgentFrontmatter {
    param([string]$FilePath)
    $content = Get-Content -Path $FilePath -Raw -Encoding utf8
    if ($content -notmatch '(?s)^---\r?\n(.*?)\r?\n---') {
        return $null
    }
    $yaml = $Matches[1]
    $props = @{}
    foreach ($line in ($yaml -split "\r?\n")) {
        if ($line -match '^\s*([a-zA-Z_]+)\s*:\s*"?(.*?)"?\s*$') {
            $props[$Matches[1]] = $Matches[2].Trim('"')
        }
    }
    return $props
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   OMEGAEMPIRE — Flat Vault Orchestrator v2.3  " -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

Write-EmpireLog "Flat sweep initiated on $AgentsDir" "OmegaEmpire" "INFO"

if (-not (Test-Path $AgentsDir)) {
    Write-Host "[ERROR] Agents directory not found at $AgentsDir" -ForegroundColor Red
    exit
}

$allAgents = @()
foreach ($file in (Get-ChildItem -Path $AgentsDir -Filter "*.md")) {
    $fm = Get-AgentFrontmatter -FilePath $file.FullName
    if ($fm) {
        $allAgents += [PSCustomObject]@{
            Name      = if ($fm['agent']) { $fm['agent'] } else { $file.BaseName }
            Planet    = if ($fm['planet']) { $fm['planet'] } else { "Vault" }
            Job       = if ($fm['job']) { $fm['job'] } else { "Agent" }
            WakeupTag = if ($fm['wakeup_tag']) { $fm['wakeup_tag'] } else { "DORMANT" }
            Status    = if ($fm['status']) { $fm['status'] } else { "dormant" }
            File      = $file.Name
        }
    } else {
        $allAgents += [PSCustomObject]@{
            Name      = $file.BaseName
            Planet    = "Vault"
            Job       = "Archived Agent"
            WakeupTag = "DORMANT"
            Status    = "dormant"
            File      = $file.Name
        }
    }
}

$total   = $allAgents.Count
$active  = ($allAgents | Where-Object { $_.Status -eq 'active' }).Count
$dormant = ($allAgents | Where-Object { $_.Status -eq 'dormant' }).Count
$needsR  = ($allAgents | Where-Object { $_.WakeupTag -eq 'NEEDS-RUBEN' }).Count

Write-Host ""
Write-Host "  Total agents on file:   $total" -ForegroundColor Cyan
Write-Host "  Dormant:                 $dormant" -ForegroundColor Gray
Write-Host "  Active:                  $active" -ForegroundColor Green
Write-Host "  NEEDS-RUBEN (blocked):   $needsR" -ForegroundColor Red
Write-Host ""

Write-EmpireLog "FLAT SWEEP COMPLETE — $total agents loaded, $active active, $needsR blocked" "OmegaEmpire" "SUCCESS"