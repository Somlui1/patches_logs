#$RootPath = Split-Path -Parent $PSScriptRoot
$RootPath = $PSScriptRoot
$EnvFilePath = Join-Path -Path $RootPath -ChildPath ".env"

if (Test-Path $EnvFilePath) {
    Get-Content $EnvFilePath | ForEach-Object {
        $line = $_.Trim()
        # กรองเอาเฉพาะบรรทัดที่มีข้อมูล (ไม่เอา Comment หรือบรรทัดว่าง)
        if ($line -notmatch "^#" -and $line -ne "") {
            # แยก Key และ Value ด้วยเครื่องหมาย =
            # การใช้ Trim() จะช่วยตัดช่องว่างรอบๆ = ที่คุณมีในไฟล์ออกให้เองครับ
            $key, $value = $line -split '=', 2
            # ทำความสะอาดข้อมูล
            $key = $key.Trim() 
            $value = $value.Trim().Trim('"').Trim("'") # ตัด space และตัด " หรือ ' ออก
            # สร้างตัวแปร Global
            if ($key) {
                # ใช้คำสั่งนี้เพื่อสร้างตัวแปรระดับ Global
                Set-Variable -Name $key -Value $value -Scope Global
                # (Option) แสดงผลเพื่อ debug ดูว่าค่าเข้าไหม
                # Write-Host "Set Global Variable: `$$key = $value" -ForegroundColor Gray
            }
        }
    }
   #Write-Host "Imported .env to Global Variables successfully." -ForegroundColor Green
} else {
    Write-Warning "File .env not found at $EnvFilePath"
}
function Connect-MicrosoftGraphCert {
    [CmdletBinding()]
    param (
        #[Parameter(Mandatory)]
        [string] $ClientId = $global:clientId,
        #[Parameter(Mandatory)]
        [string] $TenantId = $global:tenantId,
        #[Parameter(Mandatory)]
        [string] $CertificateThumbprint  = $global:Thumbprint
    )
    try {
        Write-Verbose "📦 Import Microsoft.Graph.Mail module"
        Import-Module Microsoft.Graph.Mail -ErrorAction Stop
        Write-Verbose "🔐 Connecting to Microsoft Graph (App-only Certificate)"
        Connect-MgGraph `
            -ClientId $ClientId `
            -TenantId $TenantId `
            -CertificateThumbprint $CertificateThumbprint `
            -ErrorAction Stop

        Write-Host "✅ Connected to Microsoft Graph successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Failed to connect Microsoft Graph: $($_.Exception.Message)"
        throw
    }
}

$TENANTS_LOADED = @{}
# ดึงตัวแปรทั้งหมดที่ลงท้ายด้วย _CREDENTIAL, _APIKEY, _ACCOUNT
Get-Variable | Where-Object { $_.Name -match "^(AH|AS|AR)_" } | ForEach-Object {
    $parts = $_.Name -split '_' # แยกชื่อ เช่น AH_CREDENTIAL เป็น 'AH', 'CREDENTIAL'
    $tenant = $parts[0].ToLower()
    $prop = $parts[1]
    
    # สร้าง Nested Hash Table ถ้ายังไม่มี
    if (-not $TENANTS_LOADED.ContainsKey($tenant)) {
        $TENANTS_LOADED[$tenant] = @{}
    }
    
    # ยัดค่าใส่กลับเข้าไป
    $TENANTS_LOADED[$tenant][$prop] = $_.Value
}
$TENANTS = $TENANTS_LOADED
$TENANTS = @{
   "ah" = @{
       Credential = "583db905e5af13cd_r_id:it@minAPI1WGant!"
       APIKey     = "FfSghSoNzPlloALCK9LN5E46rzGnAYqxJ+mgirtf"
       Account    = "WGC-3-981e96282dcc4ad0856c"
   }
   "as" = @{
       Credential = "8f6543f42f463fc6_r_id:5QG+M=H+)3iL)Fw"
       APIKey     = "yujbaVOGmOi5rzxU2wBwcCJMLrkKyxU7Fbw8rQgj"
       Account    = "WGC-3-50b8aa46e31d448698c7"
   }
   "ar" = @{
       Credential = "7be27fa3e7cc352a_r_id:^^K7Uc~7PYruSek"
       APIKey     = "66eMRiegSh7EhWQh6C9S5hAnQ75OScy6T9kx+VKo"
       Account    = "WGC-3-048294f7f1ed497981c8"
   }
}
 function Fetch-Devices {
    param(
        [Parameter(Mandatory)]
        [string]$TenantName,

        [Parameter(Mandatory)]
        [string]$Segment,

        [Parameter(Mandatory)]
        [string]$Retrieve,

        [string]$QueryString
    )
    # ใช้แทน defaultdict(list)
    $results = @{}
    $errors  = @{}
    # ---------------------------
    # 1) เตรียม TENANTS_KEYS
    # ---------------------------
    if ($TenantName.ToLower() -eq 'all') {
        $TENANTS_KEYS = $TENANTS.Keys
    }
    elseif (-not $TENANTS.ContainsKey($TenantName)) {
        return @{
            Results = @{}
            Errors  = @{ $TenantName = "Tenant does not exist." }
        }
    }
    else {
        $TENANTS_KEYS = @($TenantName)
    }

    # ---------------------------
    # 2) Loop ทุก tenant
    # ---------------------------
    foreach ($key in $TENANTS_KEYS) {
        $tenant = $TENANTS[$key]

        try {
            # --------------------- GET TOKEN ---------------------
            $credBytes = [System.Text.Encoding]::UTF8.GetBytes($tenant.Credential)
            $credB64   = [Convert]::ToBase64String($credBytes)

            $tokenResp = Invoke-RestMethod `
                -Uri "https://api.jpn.cloud.watchguard.com/oauth/token" `
                -Method Post `
                -Headers @{
                    Accept        = "application/json"
                    Authorization = "Basic $credB64"
                    "Content-Type"= "application/x-www-form-urlencoded"
                } `
                -Body @{
                    grant_type = "client_credentials"
                    scope      = "api-access"
                }

            $token = $tokenResp.access_token
            if (-not $token) {
                throw "Token is null"
            }

            # --------------------- GET DEVICES ---------------------
          $baseUrl = "https://api.jpn.cloud.watchguard.com/rest/$Segment/management/api/v1/accounts/$($tenant.Account)/$Retrieve"

            if (![string]::IsNullOrWhiteSpace($QueryString)) {
                $qs  = $QueryString.Trim().TrimStart('?')
                $url = "$baseUrl`?$qs"
            }
            else {
                $url = $baseUrl
            }

            #Write-Host "[$key] URL => [$url]"

            $data = Invoke-RestMethod `
                -Uri $url `
                -Method Get `
                -TimeoutSec 120 `
                -Headers @{
                    Accept               = "application/json"
                    "Content-Type"       = "application/json"
                    "WatchGuard-API-Key" = $tenant.APIKey
                    Authorization        = "Bearer $token"
                }

            # --------------------- MERGE DATA ---------------------
        }
        catch {
            $errors[$key] = $_.Exception.Message
        }
    }
    # ---------------------------
    # 3) Return
    # ---------------------------
    return @{
        devices = $data
        error   = $errors
    }
}

function Get-UniqueByKey {
    param (
        [Parameter(Mandatory)]
        [array]$Objects,

        [Parameter(Mandatory)]
        [string]$Key
    )

    $Objects |
        Group-Object -Property $Key |
        ForEach-Object { $_.Group | Select-Object -First 1 }
}

function Chunked {
    param (
        [Parameter(Mandatory=$true)]
        [array]$Iterable,

        [Parameter(Mandatory=$true)]
        [int]$Size
    )

    for ($i = 0; $i -lt $Iterable.Count; $i += $Size) {
        $chunk = $Iterable[$i..([Math]::Min($i + $Size - 1, $Iterable.Count - 1))]
        ,$chunk   # comma operator ทำให้ return เป็น array เดียว ไม่ flatten
    }
}

function Get-ChunkedSafe {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject,  # รับเป็น object ทั่วไปก่อน เพื่อป้องกันการ Cast ผิด

        [Parameter(Mandatory = $true)]
        [int]$Size
    )
    begin {
        # สร้าง ArrayList รอไว้ (ทำงานเร็วกว่า Array ปกติมาก)
        $Global:BufferList = [System.Collections.ArrayList]::new()
    }
    process {
        # ไม่ว่าข้อมูลจะมาแบบก้อนเดียว หรือมาทีละตัว (Pipe) เราจับยัดลง ArrayList ให้หมดก่อน
        foreach ($item in $InputObject) {
            $null = $Global:BufferList.Add($item)
        }
    }
    end {
        # เริ่มตัดแบ่งเมื่อได้รับข้อมูลครบแล้ว
        $total = $Global:BufferList.Count
        $offset = 0

        while ($offset -lt $total) {
            # คำนวณจำนวนที่จะตัด (ถ้าเหลือน้อยกว่า Size ก็เอาเท่าที่เหลือ)
            $count = [Math]::Min($Size, ($total - $offset))
            
            # ใช้ .GetRange ตัดออกมา (เสถียรกว่าการ Slice Array)
            $chunk = $Global:BufferList.GetRange($offset, $count)
            
            # ส่งออกเป็น Array ก้อนเดียว (ใส่เครื่องหมาย , นำหน้าสำคัญมาก!)
            , $chunk.ToArray()
            
            $offset += $Size
        }
        
        # คืนค่าแรม
        $Global:BufferList.Clear()
        $Global:BufferList = $null
    }
}


#class LicenseInput(BaseModel):
#    host    : int                                 
#    table   : str                             
#    data    : List[Any]                         
#    base64  : Optional[List[Any]] = None  

function Formatting {
    param (
        [Parameter(Mandatory)]
        [object]$Payload
    )

    return $Payload | ConvertTo-Json -Depth 10
}

function Newsend-JsonPayload {
    param (
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$JsonBody,

        [string]$ContentType = "application/json"
    )

    try {
        Write-Host "Sending JSON to $Url..."

        $response = Invoke-RestMethod `
            -Uri $Url `
            -Method Post `
            -Body $JsonBody `
            -ContentType $ContentType `
            -ErrorAction Stop

        return $response
    }
    catch {
        if ($_.Exception.Response) {
            return $_.Exception.Response.StatusCode.Value__
        }
        else {
            Write-Error "Error sending data: $_"
            return -1
        }
    }
}

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