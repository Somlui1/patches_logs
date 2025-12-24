#setup environment
$maxSize_Attachfile = 15MB
#sender info
$sender = [PSCustomObject]@{
subject = "history patch"
mail  ="no-reply@pandasecurity.com"
file_name_keyword = "history"
}
$mailfolder = 'inbox' 
#import module
Import-Module Microsoft.Graph.Mail
#setup connection to MS Graph
$clientId =  "ec1e5f36-4262-4ead-a5d7-9ab8892a950b"
$tenantId =  "a4722e58-ec99-4c3b-a34c-38620f1c4288"
$Thumbprint = "BDE04873ABD2F62E41102076CD5650C91EC7CF78"
Connect-MgGraph -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $Thumbprint 
$today = (Get-Date).ToString("yyyy-MM-dd")
$userid  =  "a5dfb9b7-0534-4314-9081-70e81976227f"
$emailAddress = "WGThreatAlert@pandasecurity.com"

$messages = Get-MgUserMailFolderMessage `
-UserId $userid  `
-MailFolderId $mailfolder `
-Filter "subject eq '$($sender.subject)' and receivedDateTime ge $today"  `
-top 1 
#-Filter "from/emailAddress/address eq '$($sender.mail)' and subject eq '$($sender.subject)' and receivedDateTime ge $today"  `

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
        -UserId $userid `
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
$data = $csvText | ConvertFrom-Csv -Delimiter "`t"
function Normalize-ColumnName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Name
    )

    return (
        (
            $Name `
                -replace '\s*\(.*?\)', '' `
                -replace '\s+', '_' `
                -replace '_+', '_'
        ).Trim('_')
    )
}

# ===== AES CONFIG (สร้างครั้งเดียว) =====
$secret = "AAPICO"
$key = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
    [Text.Encoding]::UTF8.GetBytes($secret)
)
$iv  = [byte[]]::new(16)
$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Key = $key
$aes.IV  = $iv

$key_columns = $data | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

$data = $data |
Where-Object { $_.Installation -eq "Installed" } |
ForEach-Object {
    $object = $_
    # 1️⃣ Convert Date
    if ($object.Date -is [string]) {
        $object.Date = [datetime]::ParseExact(
            $object.Date,
            "yyyy-MM-dd HH:mm:ss",
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    }

    # 2️⃣ Build natural key
    $keyValue = (
        $key_columns | ForEach-Object {
            $v = $object.$_
            if ($v -is [datetime]) {
                $v.ToString("yyyyMMddHHmmss")
            } else {
                $v
            }
        }
    ) -join '|'

    # 3️⃣ Encrypt (สร้าง encryptor ใหม่ทุกครั้ง)
    $plainBytes = [Text.Encoding]::UTF8.GetBytes($keyValue)
    $encryptor = $aes.CreateEncryptor()
    $cipher = $encryptor.TransformFinalBlock(
    $plainBytes, 0, $plainBytes.Length
    )
    $encryptedKey = [Convert]::ToBase64String($cipher)

    # 4️⃣ Add key
    $object | Add-Member `
        -MemberType NoteProperty `
        -Name 'KeyHash' `
        -Value $encryptedKey `
        -Force

    $object
} | foreach-object {
    $obj = $_
    # Normalize column names
    $newObj = [PSCustomObject]@{}
    foreach ($prop in $obj.PSObject.Properties) {
        $normalized_name = Normalize-ColumnName -Name $prop.Name
        $newObj | Add-Member -MemberType NoteProperty -Name $normalized_name -Value $prop.Value
    }
    $newObj
}


#===== FUNCTION FOR DECRYPTION (ถ้าต้องการตรวจสอบข้อมูลเดิม) =====
function Decode-AesKey {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $EncryptedKey,   # Base64 string

        [Parameter(Mandatory)]
        [string] $Secret          # ต้องเป็น secret เดียวกับตอน encrypt
    )
    # Derive key (ต้องเหมือนตอน encrypt)
    $key = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($Secret)
    )
    # IV ต้องเหมือนเดิม
    $iv = [byte[]]::new(16)
    # Create AES
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV  = $iv
    # Decrypt
    $decryptor = $aes.CreateDecryptor()
    $cipherBytes = [Convert]::FromBase64String($EncryptedKey)
    $plainBytes = $decryptor.TransformFinalBlock(
        $cipherBytes, 0, $cipherBytes.Length
    )
    return [Text.Encoding]::UTF8.GetString($plainBytes)
}
#$encrypted = $data[0].KeyHash
#$decoded = Decode-AesKey -EncryptedKey $encryptedKey -Secret $secret
#$decoded

#===== END OF FUNCTION =====
                            
           