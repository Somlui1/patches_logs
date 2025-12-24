# =============================================================================
# Initial Setup & Imports
# =============================================================================
# นำเข้า Module สำหรับจัดการ Mail ผ่าน Microsoft Graph
Import-Module Microsoft.Graph.Mail
try {
    # ===== script หลักทั้งหมด =====
    if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
Set-Location -LiteralPath $PSScriptRoot
$RootPath = Split-Path -Parent $PSScriptRoot
# กำหนด Path ปัจจุบันและโหลด Function เสริม
$RootPath = Split-Path -Parent $PSScriptRoot
. "$RootPath\function.ps1"
# =============================================================================
# Configuration
# =============================================================================
# กำหนดค่าจำกัดขนาดไฟล์ (20MB)
$MaxFileSize = 20MB
# กำหนด User ID เป้าหมาย (แยกออกมาให้เห็นชัดเจน)
$TargetUserId = "a5dfb9b7-0534-4314-9081-70e81976227f"
# กำหนดโฟลเดอร์ที่จะอ่าน
$MailFolder = 'inbox'
# กำหนดข้อมูลผู้ส่ง (Sender Configuration)
$SenderConfig = [PSCustomObject]@{
    Subject      = "report available patch"
    EmailAddress = "no-reply@pandasecurity.com"
}
# เชื่อมต่อกับ Microsoft Graph ด้วย Certificate
Connect-MicrosoftGraphCert
# =============================================================================
# Mail Retrieval
# =============================================================================
# กำหนดวันที่สำหรับ Filter (วันนี้)
$TodayDate = (Get-Date).ToString("yyyy-MM-dd")
# ดึงอีเมลจาก Inbox ตามเงื่อนไข (ผู้ส่ง, หัวข้อ, วันที่)
$Messages = Get-MgUserMailFolderMessage `
    -UserId $TargetUserId  `
    -MailFolderId $MailFolder `
    -Filter "from/emailAddress/address eq '$($SenderConfig.EmailAddress)' and subject eq '$($SenderConfig.Subject)' and receivedDateTime ge $TodayDate"  `
    -Top 1 

# ตรวจสอบว่ามีอีเมลหรือไม่ ถ้าไม่มีให้จบการทำงาน
if (-not $Messages) {
    Write-Error "No messages found, exiting script."
    exit
}
# =============================================================================
# Attachment Processing
# =============================================================================

# วนลูปเพื่อหาไฟล์แนบที่ถูกต้อง (.csv)
$TargetAttachment = $Messages | ForEach-Object {
    $msg = $_

    # ตรวจสอบ Sender และ Subject อีกครั้งเพื่อความปลอดภัย (Double Check)
    if ($msg.From.EmailAddress.Address -ne $SenderConfig.EmailAddress -or 
        $msg.Subject -ne $SenderConfig.Subject) {
        return
    }

    # ดึงไฟล์แนบทั้งหมด
    $attachments = Get-MgUserMessageAttachment `
        -UserId $TargetUserId `
        -MessageId $msg.Id `
        -All

    # เลือกไฟล์ CSV ที่ชื่อขึ้นต้นด้วย Available_patches_
    $attachments | Where-Object {
        $_.Name -like "Available_patches_*.csv"
    } | Select-Object -First 1

} | Select-Object -First 1  

# ตรวจสอบว่าพบไฟล์แนบหรือไม่
if (-not $TargetAttachment) {
    Write-Error "Attachment not found."
    exit
}

# แปลงข้อมูลไฟล์แนบ (Base64) กลับเป็น Byte Array
$FileBytes = [Convert]::FromBase64String($TargetAttachment.AdditionalProperties.contentBytes)

# ตรวจสอบขนาดไฟล์
if ($FileBytes.Length -gt $MaxFileSize) {
    Write-Error "File size exceeds limit ($MaxFileSize bytes)"
    exit 1
}

# แปลง Byte Array เป็นข้อความ CSV (Unicode)
$CsvContentString = [Text.Encoding]::Unicode.GetString($FileBytes)

# แปลง CSV เป็น Object (Delimiter คือ Tab)
$RawData = $CsvContentString | ConvertFrom-Csv -Delimiter "`t"

# =============================================================================
# Data Grouping & Transformation
# =============================================================================

# จัดกลุ่มข้อมูลตาม Patch และรวมข้อมูล (Aggregation)
$GroupedPatches = $RawData | Group-Object -Property Patch | ForEach-Object {
    $rowGroup = $_.Group
    
    # ดึง Release Date จากรายการแรกในกลุ่มมาแปลงเป็น DateTime
    $dateString = $rowGroup | Select-Object -ExpandProperty 'Release date' | Select-Object -First 1
    
    # *Note: Logic การแปลงวันที่ใส่เตรียมไว้ แต่ตาม Requirement เดิมให้ค่า release_date เป็น $null
    try {
        $releaseDateObj = Normalize-DateType -Value $dateString -Type 'date'
    } catch {
        $releaseDateObj = $null
    }
    # สร้าง Properties ใหม่ที่รวมผลลัพธ์แล้ว
    $properties = [ordered]@{
        patch           = $_.Name
        computers       = ($rowGroup | Measure-Object Computers -Sum).Sum
        criticality     = ($rowGroup | Select-Object -ExpandProperty Criticality | Sort-Object -Unique) -join ','
        cves            = ($rowGroup | Select-Object -ExpandProperty 'CVEs (Common Vulnerabilities and Exposures)' | Sort-Object -Unique) -join ','
        kb_id           = ($rowGroup | Select-Object -ExpandProperty 'KB ID' | Sort-Object -Unique) -join ','
        platform        = ($rowGroup | Select-Object -ExpandProperty Platform | Sort-Object -Unique) -join ','
        product_family  = ($rowGroup | Select-Object -ExpandProperty 'Product family' | Sort-Object -Unique) -join ','
        program         = ($rowGroup | Select-Object -ExpandProperty Program | Sort-Object -Unique) -join ','
        program_version = ($rowGroup | Select-Object -ExpandProperty 'Program version' | Sort-Object -Unique) -join ','
        version         = ($rowGroup | Select-Object -ExpandProperty Version | Sort-Object -Unique) -join ','
        vendor          = ($rowGroup | Select-Object -ExpandProperty Vendor | Sort-Object -Unique) | Select-Object -First 1
        release_date    = $releaseDateObj
    }
    # ส่งออกเป็น PSObject
    [PSCustomObject]$properties
}
# =============================================================================
# Data Transmission (Chunk & Send)
# =============================================================================

# แบ่งข้อมูลเป็น Chunk ขนาด 1200 แถว
# (ใช้ Logic เดียว จัดการได้ทั้งข้อมูลน้อยกว่าและมากกว่า 1200)
$GroupedPatchesArray = @($GroupedPatches)

if ($GroupedPatchesArray.Count -lt 1200) {
    $payload = @{
        host  = $env:COMPUTERNAME
        table = "available_patches_computer"
        data  = $GroupedPatchesArray  # array อยู่แล้ว
    }
    # แปลง Payload เป็น JSON
    $jsonBody = Formatting -Payload $payload
    # ส่งข้อมูลไปยัง API
    $response = Newsend-JsonPayload `
        -Url "http://10.10.3.215:8181/watchguard/patch" `
        -JsonBody $jsonBody
    Write-Host "Response: $response"
    exit -1
}

$Chunks = Chunked -Iterable $GroupedPatches -Size 1200
Write-Host "Total Chunks to send: $($Chunks.Count)"
foreach ($chunk in $Chunks) {
    Write-Host "Processing chunk with $($chunk.Count) items..."
    # 1. สร้าง Payload
    $payload = @{
        host  = $env:COMPUTERNAME
        table = "available_patches_computer"
        data  = @($chunk) # Force array
    }

    # 2. แปลง Payload เป็น JSON
    $jsonBody = Formatting -Payload $payload

    # 3. ส่งข้อมูลไปยัง API Endpoint
    $response = Newsend-JsonPayload `
        -Url "http://localhost:8000/watchguard/patch" `
        -JsonBody $jsonBody

    # แสดงผลลัพธ์
    Write-Host "Response: $response"
}

}
catch {
    Write-Error $_
}
finally {
    Write-Host ""
    Write-Host "Process completed. Window will close in 10 seconds..."
    Start-Sleep 10
}
