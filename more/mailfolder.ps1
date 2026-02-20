$clientId = "ec1e5f36-4262-4ead-a5d7-9ab8892a950b"
$tenantId = "a4722e58-ec99-4c3b-a34c-38620f1c4288"
#$graphScopes = "User.Read.All mail.read mail.send Mail.ReadWrite"
$Thumbprint = "E3FDF1DED66114B7A013313CF40B6FFDF2552193"
#$Thumbprint = "45CFC1E3740950B8C62982DA5B3213BC13119DCE"       # --> Host GLPI
$userid = "a5dfb9b7-0534-4314-9081-70e81976227f"
Connect-MgGraph -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $Thumbprint 
$today = (Get-Date).ToString("yyyy-MM-dd")
$checklist_folderId = "AAMkADg0ZGMxNWJhLTEwYmYtNGZlOC1iZTNhLThkMDA1MjlkZDJkZAAuAAAAAABgMXAAPDLQT4HfJxmfhRG8AQBkvK5jCAHYT6tzQpMQ0K-pAAAAABK0AAA="
$subfolder = Get-MgUserMailFolderChildFolder -MailFolderId $checklist_folderId -UserId $userid -All

Get-MgUserMailFolderChildFolder -UserId $userid -MailFolderId 'AAMkADg0ZGMxNWJhLTEwYmYtNGZlOC1iZTNhLThkMDA1MjlkZDJkZAAuAAAAAABgMXAAPDLQT4HfJxmfhRG8AQBkvK5jCAHYT6tzQpMQ0K-pAACbQHE8AAA=' -All
