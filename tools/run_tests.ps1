# tools/run_tests.ps1 — discovery + parallel runner for Godot smoke tests.
#
# Usage:
#   ./tools/run_tests.ps1 <group> [<group> ...]
#   ./tools/run_tests.ps1 -List
#   ./tools/run_tests.ps1 -Required           # alias for "all-required"
#   ./tools/run_tests.ps1 rts/all             # all groups in rts namespace
#
# Group names: "<namespace>/<group>", "<namespace>/all", "all-required", "all".
# Manifests: addons/logic-game-framework/{tests,example/*/tests}/test_groups.json,
#            addons/sim-nav-map/{tests,examples/*/tests}/test_groups.json
#
# Paths inside each manifest are relative to that manifest's own directory.

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true, Position = 0)]
    [string[]]$Groups,
    [switch]$List,
    [switch]$Required,
    [switch]$SkipImportRefresh,
    [int]$MaxParallel = 5
)

$ErrorActionPreference = "Stop"

# --- Pin CWD to repo root regardless of where the script was invoked from ---
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$GodotExe = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { "godot" }

$LogDir = Join-Path $RepoRoot ".claude\tmp\test-runs"
$WrapperDir = Join-Path $LogDir "_wrappers"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
New-Item -ItemType Directory -Force -Path $WrapperDir | Out-Null
# Wipe any wrapper .bat residue from a previously-killed run so the dir
# always reflects only what's executing right now.
Get-ChildItem -Path $WrapperDir -Filter *.bat -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

if (-not $SkipImportRefresh -and -not $List) {
    $ImportLog = Join-Path $LogDir "_godot_import_refresh.log"
    $ImportBat = Join-Path $WrapperDir "_godot_import_refresh.bat"
    if (Test-Path $ImportLog) { Remove-Item $ImportLog -Force -ErrorAction SilentlyContinue }
    $importBatBody = @"
@echo off
"$GodotExe" --headless --path . --import --quit > "$ImportLog" 2>&1
set GD_EC=%ERRORLEVEL%
(echo __GODOT_EXIT_CODE=%GD_EC%)>> "$ImportLog"
exit /b %GD_EC%
"@
    Set-Content -Path $ImportBat -Value $importBatBody -Encoding ASCII

    $importProc = Start-Process -FilePath $ImportBat -PassThru -NoNewWindow -WorkingDirectory $RepoRoot
    $importProc.WaitForExit()
    $importOutput = if (Test-Path $ImportLog) { Get-Content $ImportLog -Raw -ErrorAction SilentlyContinue } else { "" }
    $importExitCode = if ($importOutput -match "__GODOT_EXIT_CODE=(\d+)") { [int]$matches[1] } else { -1 }
    if (Test-Path $ImportBat) { Remove-Item $ImportBat -Force -ErrorAction SilentlyContinue }

    if ($importExitCode -ne 0) {
        Write-Host "Godot import refresh failed before tests. See: $ImportLog" -ForegroundColor Red
        Get-Content $ImportLog -Tail 40 -ErrorAction SilentlyContinue
        exit $importExitCode
    }
}

# --- Discover manifests ---
$ManifestPatterns = @(
    "addons\logic-game-framework\tests\test_groups.json",
    "addons\logic-game-framework\example\*\tests\test_groups.json",
    "addons\sim-nav-map\tests\test_groups.json",
    "addons\sim-nav-map\examples\*\tests\test_groups.json"
)
$Manifests = @()
foreach ($pat in $ManifestPatterns) {
    Get-ChildItem -Path $pat -ErrorAction SilentlyContinue | ForEach-Object {
        $data = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $Manifests += [pscustomobject]@{
            File = $_.FullName
            Dir  = (Split-Path -Parent $_.FullName)
            Data = $data
        }
    }
}

if ($Manifests.Count -eq 0) {
    Write-Host "No test_groups.json manifests found." -ForegroundColor Red
    exit 2
}

# --- Build group registry ---
$AllGroups = [ordered]@{}
foreach ($m in $Manifests) {
    $ns = $m.Data.namespace
    $nsTimeout = if ($m.Data.default_timeout_ms) { [int]$m.Data.default_timeout_ms } else { 30000 }
    foreach ($prop in $m.Data.groups.PSObject.Properties) {
        $groupName = $prop.Name
        $g = $prop.Value
        $gTimeout = if ($g.default_timeout_ms) { [int]$g.default_timeout_ms } else { $nsTimeout }
        $scenes = @()
        foreach ($s in $g.scenes) {
            if ($s -is [string]) {
                $scenes += [pscustomobject]@{
                    Path      = (Join-Path $m.Dir $s)
                    TimeoutMs = $gTimeout
                }
            } else {
                $tm = if ($s.timeout_ms) { [int]$s.timeout_ms } else { $gTimeout }
                $scenes += [pscustomobject]@{
                    Path      = (Join-Path $m.Dir $s.path)
                    TimeoutMs = $tm
                }
            }
        }
        $AllGroups["$ns/$groupName"] = [pscustomobject]@{
            Scenes   = $scenes
            Required = [bool]$g.required
        }
    }
}

# --- List mode ---
if ($List) {
    $namespaces = $AllGroups.Keys | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique
    foreach ($ns in $namespaces) {
        Write-Host ""
        Write-Host "[$ns]" -ForegroundColor Cyan
        $AllGroups.GetEnumerator() | Where-Object { $_.Key.StartsWith("$ns/") } | Sort-Object Key | ForEach-Object {
            $req = if ($_.Value.Required) { " (required)" } else { "" }
            Write-Host ("  {0,-32} {1,3} scenes{2}" -f $_.Key, $_.Value.Scenes.Count, $req)
        }
    }
    Write-Host ""
    Write-Host "Aliases: <ns>/all, all-required, all" -ForegroundColor DarkGray
    exit 0
}

if ($Required) { $Groups = @("all-required") }
if (-not $Groups -or $Groups.Count -eq 0) {
    Write-Host "Usage: ./tools/run_tests.ps1 <group> [<group> ...]" -ForegroundColor Yellow
    Write-Host "       ./tools/run_tests.ps1 -List         # list all groups"
    Write-Host "       ./tools/run_tests.ps1 -Required     # all groups marked required"
    exit 2
}

# --- Resolve group names -> deduped scene set ---
$resolved = [ordered]@{}
function Add-Scene($s) {
    if ($resolved.Contains($s.Path)) {
        if ($s.TimeoutMs -gt $resolved[$s.Path].TimeoutMs) {
            $resolved[$s.Path].TimeoutMs = $s.TimeoutMs
        }
    } else {
        $resolved[$s.Path] = [pscustomobject]@{ TimeoutMs = $s.TimeoutMs }
    }
}

foreach ($g in $Groups) {
    if ($g -eq "all-required") {
        $AllGroups.GetEnumerator() | Where-Object { $_.Value.Required } | ForEach-Object {
            $_.Value.Scenes | ForEach-Object { Add-Scene $_ }
        }
    } elseif ($g -eq "all") {
        $AllGroups.Values | ForEach-Object { $_.Scenes | ForEach-Object { Add-Scene $_ } }
    } elseif ($g -match "^([^/]+)/all$") {
        $ns = $matches[1]
        $hit = $false
        $AllGroups.GetEnumerator() | Where-Object { $_.Key.StartsWith("$ns/") } | ForEach-Object {
            $hit = $true
            $_.Value.Scenes | ForEach-Object { Add-Scene $_ }
        }
        if (-not $hit) {
            Write-Host "No groups in namespace: $ns" -ForegroundColor Red; exit 2
        }
    } elseif ($AllGroups.Contains($g)) {
        $AllGroups[$g].Scenes | ForEach-Object { Add-Scene $_ }
    } else {
        Write-Host "Unknown group: $g" -ForegroundColor Red
        Write-Host "Run with -List to see available groups." -ForegroundColor DarkGray
        exit 2
    }
}

if ($resolved.Count -eq 0) {
    Write-Host "No scenes resolved." -ForegroundColor Yellow; exit 0
}

Write-Host ""
Write-Host "Running $($resolved.Count) scene(s) across groups: $($Groups -join ', ')" -ForegroundColor Cyan
Write-Host "Logs: $LogDir" -ForegroundColor DarkGray
Write-Host "Parallelism: $MaxParallel" -ForegroundColor DarkGray
Write-Host ""

# --- Spawn each scene via a per-scene .bat wrapper (bulletproof redirection) ---
function Start-Scene($scene) {
    $relScene = (Resolve-Path $scene.Path -Relative)
    # Unique log basename derived from the relative path (avoids collisions
    # between scenes that share a filename across namespaces, e.g. both
    # rts/regression and hex/regression reference smoke_frontend_main.tscn).
    $relForName = $relScene.TrimStart('.', '\', '/').Replace('\', '__').Replace('/', '__')
    $sceneFile = [System.IO.Path]::GetFileNameWithoutExtension($scene.Path)
    $sceneParent = Split-Path -Leaf (Split-Path -Parent $scene.Path)
    $base = "$sceneParent/$sceneFile"
    $uniqueKey = $relForName -replace '\.tscn$', ''
    $logFile = Join-Path $LogDir "$uniqueKey.log"
    $batFile = Join-Path $WrapperDir "$uniqueKey.bat"
    if (Test-Path $logFile) { Remove-Item $logFile -Force -ErrorAction SilentlyContinue }

    $batBody = @"
@echo off
"$GodotExe" --headless --path . "$relScene" > "$logFile" 2>&1
set GD_EC=%ERRORLEVEL%
(echo __GODOT_EXIT_CODE=%GD_EC%)>> "$logFile"
exit /b %GD_EC%
"@
    Set-Content -Path $batFile -Value $batBody -Encoding ASCII

    $proc = Start-Process -FilePath $batFile -PassThru -NoNewWindow -WorkingDirectory $RepoRoot
    return [pscustomobject]@{
        Process    = $proc
        Scene      = $scene.Path
        SceneName  = $base
        LogFile    = $logFile
        BatFile    = $batFile
        Started    = Get-Date
        Deadline   = (Get-Date).AddMilliseconds($scene.TimeoutMs)
        TimeoutMs  = $scene.TimeoutMs
        TimedOut   = $false
    }
}

function Finish-Scene($r) {
    $r.Process.WaitForExit()
    $elapsed = ((Get-Date) - $r.Started).TotalSeconds
    $log = if (Test-Path $r.LogFile) { Get-Content $r.LogFile -Raw -ErrorAction SilentlyContinue } else { "" }
    # Pull exit code from the log marker emitted by the .bat wrapper.
    # Start-Process -PassThru .bat in PS 7+ on Windows can leave Process.ExitCode null
    # even after WaitForExit, so we don't trust the Process object for this.
    $exitCode = if ($log -match "__GODOT_EXIT_CODE=(\d+)") { [int]$matches[1] } else { -1 }

    $status = "PASS"
    $reason = ""
    if ($r.TimedOut) {
        $status = "TIMEOUT"; $reason = "exceeded $($r.TimeoutMs)ms"
    } elseif ($log -match "SMOKE_TEST_RESULT:\s*FAIL\s*-?\s*(.*)") {
        $status = "FAIL"; $reason = $matches[1].Trim()
    } elseif ($exitCode -ne 0) {
        $status = "FAIL"; $reason = "exit=$exitCode"
    } elseif ($log -match "SMOKE_TEST_RESULT:\s*PASS") {
        $status = "PASS"
    }
    # else: exit=0, no marker (e.g. LGF run_tests) -> PASS

    if (Test-Path $r.BatFile) { Remove-Item $r.BatFile -Force -ErrorAction SilentlyContinue }

    $color = switch ($status) { "PASS" { "Green" } "FAIL" { "Red" } default { "Yellow" } }
    $line = "  [{0,-7}] {1,-52} {2,5:N1}s  {3}" -f $status, $r.SceneName, $elapsed, $reason
    Write-Host $line -ForegroundColor $color

    return [pscustomobject]@{
        Scene      = $r.SceneName
        Status     = $status
        Reason     = $reason
        ElapsedSec = $elapsed
        LogFile    = $r.LogFile
    }
}

# --- Scheduler loop ---
$queue = New-Object System.Collections.Generic.Queue[object]
foreach ($k in $resolved.Keys) {
    $queue.Enqueue([pscustomobject]@{ Path = $k; TimeoutMs = $resolved[$k].TimeoutMs })
}

$results = @()
$running = @()

while ($queue.Count -gt 0 -or $running.Count -gt 0) {
    while ($running.Count -lt $MaxParallel -and $queue.Count -gt 0) {
        $running += Start-Scene $queue.Dequeue()
    }

    Start-Sleep -Milliseconds 200

    $still = @()
    foreach ($r in $running) {
        if ($r.Process.HasExited) {
            $results += Finish-Scene $r
        } elseif ((Get-Date) -gt $r.Deadline) {
            try {
                # Kill the bat process tree (godot is a child of cmd.exe)
                Get-CimInstance Win32_Process -Filter "ParentProcessId = $($r.Process.Id)" -ErrorAction SilentlyContinue |
                    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
                Stop-Process -Id $r.Process.Id -Force -ErrorAction SilentlyContinue
            } catch {}
            $r.TimedOut = $true
            Start-Sleep -Milliseconds 200
            $results += Finish-Scene $r
        } else {
            $still += $r
        }
    }
    $running = $still
}

# --- Summary ---
$pass = ($results | Where-Object Status -eq "PASS").Count
$fail = ($results | Where-Object Status -eq "FAIL").Count
$tmo  = ($results | Where-Object Status -eq "TIMEOUT").Count
$total = $results.Count

Write-Host ""
$summaryColor = if ($fail -eq 0 -and $tmo -eq 0) { "Green" } else { "Red" }
Write-Host ("PASS {0} / FAIL {1} / TIMEOUT {2}  (total {3})" -f $pass, $fail, $tmo, $total) -ForegroundColor $summaryColor

if ($fail -gt 0 -or $tmo -gt 0) {
    Write-Host ""
    Write-Host "--- Failure tails (last 30 lines per failing log) ---" -ForegroundColor Red
    foreach ($r in $results | Where-Object { $_.Status -ne "PASS" }) {
        Write-Host ""
        Write-Host (">>> {0} [{1}] {2}" -f $r.Scene, $r.Status, $r.Reason) -ForegroundColor Red
        Write-Host ("    log: {0}" -f $r.LogFile) -ForegroundColor DarkGray
        if (Test-Path $r.LogFile) {
            Get-Content $r.LogFile -Tail 30 -ErrorAction SilentlyContinue | ForEach-Object {
                Write-Host ("    {0}" -f $_) -ForegroundColor DarkGray
            }
        }
    }
    exit 1
}

exit 0
