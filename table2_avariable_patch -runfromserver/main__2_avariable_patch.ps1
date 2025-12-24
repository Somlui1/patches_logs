$RootPath = Split-Path -Parent $PSScriptRoot
. "$RootPath\function.ps1"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$WatchguardReqestData = [PSCustomObject]@{
    segment  = "endpoint-security"
    retrive  = "patchavailability"
    tenant   = "ah"
    top      = 1000   # ⭐ ลดขนาด page
}
# 🔹 First request
$first = Fetch-Devices `
    -TenantName $WatchguardReqestData.tenant `
    -Segment $WatchguardReqestData.segment `
    -Retrieve $WatchguardReqestData.retrive `
    -QueryString "`$top=$($WatchguardReqestData.top)&`$skip=0&`$count=true"

$total = $first.devices.total_items
$avariablePatches = @($first.devices.data)
Write-Host "Fetched $($avariablePatches.Count) / $total"
# 🔹 Prepare skips
$skips = for ($i = $WatchguardReqestData.top; $i -lt $total; $i += $WatchguardReqestData.top) { $i }
# 🔹 Parallel fetch with throttle
$maxConcurrent = 4
$jobs = @()
foreach ($skip in $skips) {
    $jobs += Start-ThreadJob -ScriptBlock {
        param($skip, $req, $root)
        . "$root\function.ps1"

        Fetch-Devices `
            -TenantName $req.tenant `
            -Segment $req.segment `
            -Retrieve $req.retrive `
            -QueryString "`$top=$($req.top)&`$skip=$skip"
    } -ArgumentList $skip, $WatchguardReqestData, $RootPath

    # ⭐ Throttle
    if ($jobs.Count -ge $maxConcurrent) {
        $done = Receive-Job -Job $jobs -Wait -AutoRemoveJob
        foreach ($r in $done) {
            if ($r.devices.data) {
                $avariablePatches += $r.devices.data
            }
        }
        Write-Host "Progress: $($avariablePatches.Count) / $total"
        $jobs = @()
    }
}
# 🔹 Collect remaining
if ($jobs.Count -gt 0) {
    $done = Receive-Job -Job $jobs -Wait -AutoRemoveJob
    foreach ($r in $done) {
        if ($r.devices.data) {
            $avariablePatches += $r.devices.data
        }
    }
}
$sw.Stop()
Write-Host -ForegroundColor Green (
    "✔ Fetch completed in {0:N2}s | Total patches: {1}" -f `
    $sw.Elapsed.TotalSeconds, $avariablePatches.Count
)
