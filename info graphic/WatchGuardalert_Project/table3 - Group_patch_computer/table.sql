-- 1. สร้าง Schema: Patch_logs (ถ้ายังไม่มี)
CREATE SCHEMA IF NOT EXISTS "Patch_logs";

--- --------------------------------------------------------------------------------
-- 2. ตาราง: available_patches_computers
--- --------------------------------------------------------------------------------

-- **แก้ไข:** เพิ่ม IF NOT EXISTS ที่นี่
CREATE TABLE IF NOT EXISTS "Patch_logs"."available_patches_computers" (
    -- Primary Key
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    
    -- Data Fields
    patch TEXT UNIQUE,
    computers INTEGER,
    criticality TEXT,
    cves TEXT,
    kb_id TEXT,
    platform TEXT,
    product_family TEXT,
    program TEXT,
    program_version TEXT,
    version TEXT,
    vendor TEXT,
    release_date DATE,
    
    -- Metadata
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);

-- สร้าง UNIQUE INDEX สำหรับการทำ UPSERT (มี IF NOT EXISTS อยู่แล้ว)
CREATE UNIQUE INDEX IF NOT EXISTS ix_patch_logs_available_patches_computers_patch
    ON "Patch_logs"."available_patches_computers" (patch);


--- --------------------------------------------------------------------------------
-- 3. ตาราง: path_history_by_computers
--- --------------------------------------------------------------------------------

-- **แก้ไข:** เพิ่ม IF NOT EXISTS ที่นี่
CREATE TABLE IF NOT EXISTS "Patch_logs"."path_history_by_computers" (
    -- Primary Key
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    
    -- Identifiers
    Client TEXT NOT NULL,
    Computer_type TEXT,
    Computer TEXT NOT NULL,
    IP_address TEXT,
    Domain TEXT,
    Platform TEXT,
    "Group" TEXT,
    
    -- Patch Alert Details
    "Date" TIMESTAMP WITHOUT TIME ZONE,
    Program TEXT,
    Version TEXT,
    Patch TEXT,
    Criticality TEXT,
    KB_ID TEXT,
    Release_date TIMESTAMP WITHOUT TIME ZONE,
    
    -- Status Details
    Installation TEXT,
    Installation_error TEXT,
    Download_URL TEXT,
    Result_code TEXT,
    Description TEXT,
    CVEs TEXT,
    KeyHash TEXT,
    
    -- Metadata
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);

-- สร้าง UNIQUE INDEX สำหรับการทำ UPSERT (มี IF NOT EXISTS อยู่แล้ว)
CREATE UNIQUE INDEX IF NOT EXISTS ix_patch_logs_path_history_by_computers_keyhash
    ON "Patch_logs"."path_history_by_computers" (KeyHash);


-- 4. ตาราง: available_patches (ปรับให้ยืดหยุ่นสูงสุด)

CREATE TABLE IF NOT EXISTS "Patch_logs"."available_patches" (
    -- Primary Key (ยังคงเป็นตัวเลขสำหรับ Indexing)
    id BIGINT PRIMARY KEY,
    
    -- 1. Identifiers: เปลี่ยน VARCHAR(36) เป็น TEXT ทั้งหมด
    account_id TEXT NOT NULL, 
    site_id TEXT NOT NULL,
    site_name TEXT,
    device_id TEXT NOT NULL,
    host_name TEXT NOT NULL,
    
    -- 2. Device & Vendor IDs: เปลี่ยน INTEGER เป็น TEXT ทั้งหมด
    device_type TEXT,
    platform_id TEXT,
    vendor_id TEXT,
    family_id TEXT,
    version_id TEXT,
    vendor_name TEXT,
    family_name TEXT,
    
    -- 3. Patch Details: เปลี่ยน INTEGER เป็น TEXT ทั้งหมด
    patch_id TEXT NOT NULL,
    patch_name TEXT,
    program_name TEXT,
    program_version TEXT,
    patch_criticality TEXT, -- เปลี่ยน INTEGER เป็น TEXT
    patch_type TEXT,        -- เปลี่ยน INTEGER เป็น TEXT
    
    -- 4. Status & Dates: เปลี่ยน INTEGER เป็น TEXT
    patch_management_status TEXT, -- เปลี่ยน INTEGER เป็น TEXT
    custom_group_folder_id TEXT, -- เปลี่ยน VARCHAR(36) เป็น TEXT
    isolation_state TEXT,        -- เปลี่ยน INTEGER เป็น TEXT
    license_status TEXT,         -- เปลี่ยน INTEGER เป็น TEXT
    patch_installation_availability TEXT, -- เปลี่ยน INTEGER เป็น TEXT
    
    patch_release_date TIMESTAMP WITHOUT TIME ZONE, -- คงไว้เพื่อให้เรียงวันที่ได้
    
    -- 5. Booleans: คงไว้เพื่อความชัดเจน (ใช้ค่า True/False ใน DB)
    is_downloadable BOOLEAN,
    is_allowed_manual_installation BOOLEAN,
    automatic_reboot BOOLEAN,
    
    -- 6. File Paths/URLs: คงไว้เป็น TEXT
    download_url TEXT,
    local_filename TEXT,
    
    -- Metadata
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);