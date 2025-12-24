$RootPath = Split-Path -Parent $PSScriptRoot
# import function.ps1
. "$RootPath\function.ps1"
 $WatchguardReqestData =  [PSCustomObject]@{
    segment = "endpoint-security"
    retrive = "tasks"
    tenant = "ah"
    top = 1000
}
# https://api.usa.cloud.watchguard.com/rest/endpoint-security/management/api/v1/accounts/WGC-1-123abc456/tasks?$count=true&$filter=41004%20Eq%201
$res = Fetch-Devices `
    -TenantName "ah" `
    -Segment $WatchguardReqestData.segment `
    -Retrieve $WatchguardReqestData.retrive `
    -QueryString "`$filter=41003%20Eq%206&`$count=true"

$taskid =($res.devices.data | select -First 1 ).id

$taskresult =  Fetch-Devices `
    -TenantName "ah" `
    -Segment $WatchguardReqestData.segment `
    -Retrieve "tasks/{type}/{taskId}/jobs/{jobId}/status" `
    -QueryString "`$filter=41003%20Eq%206&`$count=true"