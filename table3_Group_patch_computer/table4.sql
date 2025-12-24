SELECT
    t3.*,   -- 👈 ดึงทุก column จาก table 3

    /* จำนวน patch ใน table 1 */
    (
        SELECT COUNT(*)
        FROM "Patch_logs".available_patches t1
        WHERE t1.patch_name = t3.patch
    ) AS total_available_patch,

    /* จำนวน patch ใน table 2 */
    (
        SELECT COUNT(*)
        FROM "Patch_logs".path_history_by_computers t2
        WHERE t2."Patch" = t3.patch
    ) AS total_installed_patch,

    /* รวมทั้งหมด */
    (
        SELECT COUNT(*)
        FROM "Patch_logs".available_patches t1
        WHERE t1.patch_name = t3.patch
    )
    +
    (
        SELECT COUNT(*)
        FROM "Patch_logs".path_history_by_computers t2
        WHERE t2."Patch" = t3.patch
    ) AS total_patch_exist

FROM "Patch_logs".available_patches_computers t3;
