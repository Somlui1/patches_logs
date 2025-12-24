$RootPath = Split-Path -Parent $PSScriptRoot
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
    Write-Host "Imported .env to Global Variables successfully." -ForegroundColor Green
} else {
    Write-Warning "File .env not found at $EnvFilePath"
}