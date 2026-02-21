# Auto-compact WSL2 VHDX files using diskpart
# Must be run as Administrator

# Check for admin rights
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Restarting..." -ForegroundColor Yellow
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Host "Shutting down all WSL instances..." -ForegroundColor Cyan
wsl --shutdown

# Define search paths
$searchPaths = @(
    "$env:LOCALAPPDATA\wsl",          # new path (WSL from Store)
    "$env:LOCALAPPDATA\Packages"      # old path (classic WSL)
)

$vhdFiles = @()

foreach ($basePath in $searchPaths) {
    if (Test-Path $basePath) {
        Write-Host "Searching in $basePath ..." -ForegroundColor Gray
        $files = Get-ChildItem -Path $basePath -Recurse -Filter "ext4.vhdx" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        $vhdFiles += $files
    }
}

if ($vhdFiles.Count -eq 0) {
    Write-Host "No ext4.vhdx files found. Exiting." -ForegroundColor Red
    exit
}

Write-Host "`nFound the following VHDX files:" -ForegroundColor Green
$vhdFiles | ForEach-Object { Write-Host "  $_" }

$confirm = Read-Host "`nProceed with compaction? (y/n)"
if ($confirm -ne 'y') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit
}

$total = $vhdFiles.Count
$current = 0
$successCount = 0
$failCount = 0

foreach ($vhd in $vhdFiles) {
    $current++
    Write-Progress -Activity "Compacting VHDX" -Status "Processing $([System.IO.Path]::GetFileName($vhd))" -PercentComplete (($current / $total) * 100)
    Write-Host "`n[$current/$total] Compacting: $vhd" -ForegroundColor Cyan

    # Create temporary diskpart script
    $diskpartScript = @"
select vdisk file="$vhd"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@
    $scriptPath = "$env:TEMP\compact_$([System.IO.Path]::GetRandomFileName()).txt"
    $diskpartScript | Out-File -FilePath $scriptPath -Encoding ascii

    # Run diskpart
    $output = diskpart /s $scriptPath 2>&1
    Remove-Item $scriptPath -Force

    # Check for success (diskpart returns exit code 0 on success)
    if ($LASTEXITCODE -eq 0 -and ($output -match "DiskPart successfully compacted the disk file" -or $output -notmatch "error")) {
        Write-Host "  -> Compacted successfully." -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "  -> Failed. Error output:" -ForegroundColor Red
        $output | ForEach-Object { Write-Host "     $_" }
        $failCount++
    }
}

Write-Progress -Activity "Compacting VHDX" -Completed
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total files found: $total"
Write-Host "Successfully compacted: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })