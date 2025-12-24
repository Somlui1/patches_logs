$RootPath = Split-Path -Parent $PSScriptRoot
. "$RootPath\function.ps1"
$chunks = Chunked -Iterable $avariablePatches -Size 1200
#$chunks = Chunked -Iterable $requests -Size 1200

foreach ($chunk in $chunks) {

    # 1. สร้าง payload (object / hashtable)
    $payload = @{
        host = $env:COMPUTERNAME
        table = "AvailablePatch"
            data  = $chunk
        }

    # 2. แปลงเป็น JSON
    $jsonBody = Formatting -Payload $payload

    # 3. ส่งไป server
    $response = Newsend-JsonPayload `
        -Url "http://localhost:8000/watchguard/patch" `
        -JsonBody $jsonBody

    Write-Host "Response:" $response
}

    

# Output results
exit -1
