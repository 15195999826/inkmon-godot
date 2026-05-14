# cleanup-sessions.ps1
# Delete DevAgent session directories older than N days (default 7).
# Sessions live at %APPDATA%\Godot\app_userdata\<ProjectName>\dev-agent\sessions\<id>\.
# 一次开发循环会累积 screenshots / dumps; lomolib bridge 不会自动清, 由这个脚本兜底。
#
# Usage:
#   pwsh cleanup-sessions.ps1                  # delete sessions older than 7 days
#   pwsh cleanup-sessions.ps1 -Days 14         # custom cutoff
#   pwsh cleanup-sessions.ps1 -DryRun          # preview without deleting
#   pwsh cleanup-sessions.ps1 -Project Inkmon  # override Godot project name (default Inkmon)
#
# Exit code: 0 always (cleanup is best-effort; missing dirs are not an error).

param(
    [int]$Days = 7,
    [switch]$DryRun,
    [string]$Project = "Inkmon"
)

$base = Join-Path $env:APPDATA "Godot\app_userdata\$Project\dev-agent\sessions"
if (-not (Test-Path $base)) {
    Write-Host "No sessions directory at: $base"
    exit 0
}

$cutoff = (Get-Date).AddDays(-$Days)
$old = Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff }

if (-not $old) {
    Write-Host "No sessions older than $Days days under $base"
    exit 0
}

$totalBytes = 0
$deletedCount = 0
foreach ($dir in $old) {
    $size = (Get-ChildItem -Path $dir.FullName -Recurse -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    if ($null -eq $size) { $size = 0 }
    $totalBytes += $size
    $sizeMB = $size / 1MB
    $age = (Get-Date) - $dir.LastWriteTime
    $line = "{0,-40} {1,8:N1} MB   age {2,3:N0}d" -f $dir.Name, $sizeMB, $age.TotalDays
    if ($DryRun) {
        Write-Host "[DRY] would remove $line"
    } else {
        Write-Host "removing      $line"
        Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $dir.FullName)) {
            $deletedCount += 1
        } else {
            Write-Warning "failed to remove $($dir.FullName)"
        }
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host ("DryRun: {0} session(s) totalling {1:N1} MB would be deleted." -f $old.Count, ($totalBytes / 1MB))
} else {
    Write-Host ("Removed {0}/{1} session(s), freed {2:N1} MB." -f $deletedCount, $old.Count, ($totalBytes / 1MB))
}
