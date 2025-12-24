Import-Module Microsoft.Graph.Mail

try {
    if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
Set-Location -LiteralPath $PSScriptRoot

$RootPath = Split-Path -Parent $PSScriptRoot
# import function.ps1
. "$RootPath\function.ps1"
#setup environment
$maxSize_Attachfile = 15MB
#sender info
$sender = [PSCustomObject]@{
subject = "history patch"
mail  ="no-reply@pandasecurity.com"
file_name_keyword = "history"
}
#import module
#setup connection to MS Graph
Connect-MicrosoftGraphCert
$today = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
#Test get folder id
$mailfolder = get-mgusermailfolder -userid $Global:userid -IncludeHiddenFolders 'true'
$childfolder = Get-MgUserMailFolderChildFolder -UserId $Global:userid `
-MailFolderId  ($mailfolder | Where-Object { $_.DisplayName -like 'Checklist' }).id`
-All 
$test_massage = Get-MgUserMailFolderMessage `
-UserId $Global:userid `
-MailFolderId ($childfolder | Where-Object { $_.DisplayName -like 'GraphMail' }).Id`
-All
$messages = Get-MgUserMailFolderMessage `
    -UserId $Global:userid `
    -MailFolderId  $Global:mailfolderId `  `
    -Filter "from/emailAddress/address eq 'no-reply@pandasecurity.com' and receivedDateTime ge $today and contains(subject,'history')"`
    -All  `
    | Sort-Object receivedDateTime -Descending | `
    Select-Object -First 1

if (-not $messages) {
    Write-Error "No messages found, exiting script."
    exit
}
$csvContent = $messages | ForEach-Object {
    $message = $_
    if (
        $message.Subject -ne $sender.subject
    ) {
        return
    }
    $attachments = Get-MgUserMessageAttachment `
        -UserId $Global:userid `
        -MessageId $message.Id `
        -All
    $attachments | Where-Object {
        $_.Name -like "*$($sender.file_name_keyword)*"
    } | Select-Object -First 1
} | Select-Object -First 1  
$bytes = [Convert]::FromBase64String(
    $csvContent.AdditionalProperties.contentBytes
)
if ($bytes.Length -gt  $maxSize_Attachfile) {
    Write-Error "File size exceeds 20 MB"
    exit 1
}
$csvText = [Text.Encoding]::Unicode.GetString($bytes)
$rawObjects = $csvText | ConvertFrom-Csv -Delimiter "`t"
if (-not $rawObjects) { return } # Exit if empty
$headerMap = [ordered]@{}
$keyColumns = @()
# We analyze the columns only one time here
$rawObjects[0].PSObject.Properties.Name | ForEach-Object {
    $origName = $_
    # Run the Regex logic here (10-20 times total) instead of (Rows * Cols) times
    $normName = ($origName -replace '\s*\(.*?\)', '' -replace '\s+', '_' -replace '_+', '_').Trim('_')
    $headerMap[$origName] = $normName
    $keyColumns += $origName
}
# ===== AES CONFIG =====
$secret = "AAPICO"
$key = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
    [Text.Encoding]::UTF8.GetBytes($secret)
)
# AES object is created once outside the loop
$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Key = $key
$aes.IV  = [byte[]]::new(16) 
# 2️⃣ Single Pass Processing
# Using a 'foreach' loop is significantly faster than the pipeline (| ForEach-Object) for large datasets
$results = foreach ($row in $rawObjects) {
    # Filter immediately
    if ($row.Installation -ne "Installed") { continue }
    # Create the container for the new row (Ordered dictionary is faster than Add-Member)
    $newRow = [ordered]@{}
    $keyParts = [System.Collections.Generic.List[string]]::new()
    foreach ($col in $headerMap.GetEnumerator()) {
        $origName = $col.Key
        $newName  = $col.Value
        $value    = $row.$origName
        # Date Handling & Key Building
        if ($origName -eq 'Date') {
    $value = Normalize-DateType -Value $value -Type 'datetime'

    if ($value) {
        # ใช้เฉพาะตัวเลขสร้าง key
        $null = $keyParts.Add(($value -replace '\D', ''))
    }
}
        elseif ($value -is [datetime]) {
            $null = $keyParts.Add($value.ToString("yyyyMMddHHmmss"))
        } 
        else {
            $null = $keyParts.Add($value)
        }
        # Add property to the new object (Direct assignment is fast)
        $newRow[$newName] = $value
    }
    # 3️⃣ Encrypt
    # Join the key parts we collected while processing columns
    $keyValueString = $keyParts -join "|"
    $plainBytes = [Text.Encoding]::UTF8.GetBytes($keyValueString)
    # We must create a new encryptor for each block to ensure clean state, 
    # but we reuse the heavy $aes parent object.
    $encryptor = $aes.CreateEncryptor()
    $cipher = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
    # Add the KeyHash to the final object
    $newRow['KeyHash'] = [Convert]::ToBase64String($cipher)
    # Cast to PSCustomObject for final output
    [PSCustomObject]$newRow
}


$chunks = Chunked -Iterable $results -Size 1200
#$chunks = Chunked -Iterable $requests -Size 1200
foreach ($chunk in $chunks) {
    # 1. สร้าง payload (object / hashtable)
    $payload = @{
        host = $env:COMPUTERNAME
        table = "path_history_by_computer"
            data  = $chunk
        }
    # 2. แปลงเป็น JSON
    $jsonBody = Formatting -Payload $payload
    # 3. ส่งไป server
    $response = Newsend-JsonPayload `
        -Url "http://10.10.3.215:8181/watchguard/patch" `
        -JsonBody $jsonBody
    Write-Host "Response:" $response
}
# Output results
}
catch {
    Write-Error $_
}
finally {
    $messages | ForEach-Object{Move-MgUserMessage -UserId $Global:userid -MessageId $_.id -DestinationId $Global:mailfolderId_move}
        Write-Host ""
    Write-Host "Process completed. Window will close in 10 seconds..."
    Start-Sleep 10
}