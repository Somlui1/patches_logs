function insertHtml {
   param (
      [string]$htmlContent,
      [string]$insertObject
   )
   $htmlDoc = New-Object 'HtmlAgilityPack.HtmlDocument'
$htmlDoc.LoadHtml($htmlContent)
$nodes = $htmlDoc.DocumentNode.SelectNodes("//h2[1]/following-sibling::table[1]//tbody")
$node = $nodes[0]
$newRow = $htmlDoc.CreateElement("tr")

foreach($ob in $insertObject.PSObject.Properties.name)
{
$newRow.InnerHtml += @"
 <th style='font-weight:normal; font-family:Campton,Century Gothic,Helvetica,Arial,sans-serif; text-align:left; font-size:15px!important; width:30%'>$($ob):</th>
 <td style='font-family:Campton,Century Gothic,Helvetica,Arial,sans-serif; font-size:15px!important'>$($insertObject.$ob)</td>
"@
}
$node.AppendChild($newRow)
return $htmlDoc.DocumentNode.OuterHtml
}



function Get-WatchGuardAccessToken {
    param (
        [string]$credentials,
        [string]$url
    )

    # Step 1: Encode the combined string into Base64
    $encoded_credentials = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($credentials))

    # Step 2: Create the Authorization header
    $authorization_header = "Basic $encoded_credentials"

    # Step 3: Set up headers
    $headers = @{
        "accept" = "application/json"
        "Authorization" = $authorization_header
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    # Step 4: Set up data
    $data = @{
        "grant_type" = "client_credentials"
        "scope" = "api-access"
    }

    # Step 5: Get the access token
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $data

    # Step 6: Return the access token
    return $response.access_token
}
function Get-WatchGuardAPI {
    param (
        [string]$credentials,
        [string]$url,
        [string]$deviceid,
        [string]$apiKey,
        [string]$Pathurl 
    )

    $access_token = Get-WatchGuardAccessToken -credentials $credentials -url $url

    $Pathheaders = @{
        "accept" = "application/json"
        "Content-Type" = "application/json"
        "WatchGuard-API-Key" = $apiKey
        "Authorization" = "Bearer $access_token"
    }

return $response = Invoke-RestMethod -Uri $Pathurl -Method Get -Headers $Pathheaders -TimeoutSec 120
}
function Get-ADUserInfo {
    param (
        [string]$user,
        [string]$domain
    )

    # Define domain-specific credentials
    switch ($domain.ToLower()) 
    {
        'aapico' {
            $domainController = 'aapico.com'
            $username = "aapico\ahroot"
            $password = ConvertTo-SecureString "A@pic0it@min" -AsPlainText -Force
        }
        'asico' {
            $domainController = 'asico.co.th'
            $username = "asico\it"
            $password = ConvertTo-SecureString "support" -AsPlainText -Force
        }
        default {
            return [PSCustomObject]@{
                SamAccountName = $user
                Department     = $null
                Company        = $null
        }
    }
}
    # Create the PSCredential object
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
    # Retrieve the user from the specified domain
    try {
        $user1 = Get-ADUser -Identity $user -Server $domainController -Credential $credential -Properties department, company | Select-Object department,company
        if ($user) {
            # Return the user information
            return [PSCustomObject]@{
                SamAccountName = $user
                Department     = $user1.Department
                Company        = $user1.Company
            }
        } else {
            Write-Output "User not found"
        }
    } catch {
        Write-Error "An error occurred: $_"
    }
}

function sendmail {
    param (
        [string]$texthtml,
        [string]$subject,
        [string]$sendto
    )
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$smtpUser = "itsupport@aapico.com"
#$smtpPassword = "zyhkkcprwtyhtctv"
$smtpPassword ="support"
# สร้างออบเจ็กต์ SmtpClient
$smtp = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort)
$smtp.EnableSsl = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPassword)
# สร้างออบเจ็กต์ MailMessage
$mailMessage = New-Object System.Net.Mail.MailMessage
$mailMessage.From = $smtpUser
#$itsupport = "itsupport@aapico.com"
#$mailMessage.To.Add("wachira.y@aapico.com")
#$mailMessage.To.Add("wajeepradit.p@aapico.com")
foreach($account in  $sendto)
{$mailMessage.To.Add($account)}

$mailMessage.Body = $texthtml
$mailMessage.IsBodyHtml = $true
$mailMessage.Subject = $subject
$smtp.Send($mailMessage)
}
function Invoke-MySqlQuery {
    param (
        [string]$Query
    )
    # MySQL connection details
    $DBUser = "wajeepradit.p"
    $DBPassword = ConvertTo-SecureString -String "Az_123456" -AsPlainText -Force
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DBUser, $DBPassword
    $Server = "10.10.10.196"
    $Database = "glpi"
    $Port = 3306
    # Open MySQL connection
    $sqlConnect = Open-MySqlConnection -ConnectionName MyDBCon -Server $Server -Database $Database -Port $Port -Credential $creds -WarningAction SilentlyContinue
    # Execute the query
    $data = Invoke-SqlQuery -ConnectionName MyDBCon -Query $Query
    # Close the connection
    Close-SqlConnection -ConnectionName MyDBCon
    # Return the data
    return $data
}
function FunctionName {
    param (
        [string]$htmlContent
    )
}
function Get-BlockedItemDetails {
    param (
        [string]$htmlContent
    )
# Load the HTML content into an HtmlDocument object
    $htmlDoc = New-Object 'HtmlAgilityPack.HtmlDocument'
    $htmlDoc.LoadHtml($htmlContent)
    # Function to extract Blocked item details
    $details = @{
        BlockedItemDetails = @{}
        BlockedItemLife = @()
        OccurrencesOnTheNetwork = @()
    }
# Extract Blocked item details
    $blockedItemDetailsTable = $htmlDoc.DocumentNode.SelectSingleNode("//h2[text()='Blocked item details']/following-sibling::table[1]")
    #$firstH2 = $htmlDoc.DocumentNode.SelectSingleNode("//h2[1]/following-sibling::table")
    $rows = $blockedItemDetailsTable.SelectNodes(".//tr")
    foreach ($row in $rows) {
        $cells = $row.SelectNodes("th|td")
        if ($cells.Count -eq 2) {
            $key = $cells[0].InnerText.TrimEnd(':')
            $value = $cells[1].InnerText
            $details.BlockedItemDetails[$key] = $value
        }
    }
# Extract Blocked item life cycle
    $blockedItemLifeTable = $htmlDoc.DocumentNode.SelectSingleNode("//h2[text()='Blocked item life cycle']/following-sibling::table[1]")
    $trNodes = $blockedItemLifeTable.SelectNodes(".//tr")
    if ($trNodes -ne $null) {
        for ($index = 1; $index -lt $trNodes.Count; $index++) {
            $Detail = $trNodes[$index].SelectNodes(".//td")
            $object = [PSCustomObject]@{
                Date = if ($Detail[0] -ne $null) { $Detail[0].InnerText.Trim() } else { "" }
                Action =if ($Detail[1] -ne $null) { $Detail[1].InnerText.Trim() } else { "" }
                PathURLRegistryKey = if ($Detail[2] -ne $null) { $Detail[2].InnerText.Trim() } else { "" }
                FileHashRegistryValue = if ($Detail[3] -ne $null) { $Detail[3].InnerText.Trim() } else { "" }
                Trusted = if ($Detail[4] -ne $null) { $Detail[4].InnerText.Trim() } else { "" } 
            }
            $details.BlockedItemLife += $object
        }
    }
# Extract Occurrences on the network
    $occurrencesTable = $htmlDoc.DocumentNode.SelectSingleNode("//h2[text()='Occurrences on the network']/following-sibling::table[1]")
    $trNodes = $occurrencesTable.SelectNodes(".//tr")
    if ($trNodes -ne $null) {
        for ($index = 1; $index -lt $trNodes.Count; $index++) {
            $Detail = $trNodes[$index].SelectNodes(".//td")
            $object = [PSCustomObject]@{
                Computer =if ($Detail[0] -ne $null) { $Detail[0].InnerText.Trim() } else { "" }
                Firstseen =if ($Detail[1] -ne $null) { $Detail[1].InnerText.Trim() } else { "" }
                Filepath =if ($Detail[2] -ne $null) { $Detail[2].InnerText.Trim() } else { "" }
            }
            $details.OccurrencesOnTheNetwork += $object
        }
    }
    return $details
}
function WatchGuard-tableD1
{
    param (
        [string]$htmlContent
    )
    # Load the HTML content into an HtmlDocument object
    $htmlDoc = New-Object 'HtmlAgilityPack.HtmlDocument'
    $htmlDoc.LoadHtml($htmlContent)
    # Hashtable to store the details
    $details = @{}
    # Extract Blocked item details
    $blockedItemDetailsTable = $htmlDoc.DocumentNode.SelectSingleNode("//h2[1]/following-sibling::table")    
    if ($blockedItemDetailsTable -ne $null) {
        $rows = $blockedItemDetailsTable.SelectNodes(".//tr")

        foreach ($row in $rows) {
            $cells = $row.SelectNodes("th|td")
            if ($cells.Count -eq 2) {
                $key = $cells[0].InnerText.TrimEnd(':')
                $value = $cells[1].InnerText
                $details[$key] = $value
            }
        }
    }
    return $details
}

function Save-HTMLToFile {
    param (
        [string]$filePath,
        [string]$htmlContent
    )
    try {
        Set-Content -Path $filePath -Value $htmlContent -Force
        Write-Host "HTML content successfully saved to $filePath"
    } catch {
        Write-Error "Failed to save HTML content to file: $_"
    }
}
