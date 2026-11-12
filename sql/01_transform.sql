/* =====================================================================
   Legacy EHR -> Target EHR transformation (SQL Server / T-SQL)
   Implements the rules in mapping/source_to_target_mapping.csv
   Source tables: legacy_patients, legacy_problems, icd9_to_icd10_crosswalk
   ===================================================================== */

/* ---------- Patient ---------- */
CREATE VIEW stg_patient AS
WITH cleaned AS (
    SELECT
        lp.pat_no,
        LTRIM(RTRIM(lp.last_nm))  AS last_nm_trim,
        LTRIM(RTRIM(lp.first_nm)) AS first_nm_trim,
        /* NULLIF: in SQL Server an empty string converts to 1900-01-01 */
        COALESCE(TRY_CONVERT(DATE, NULLIF(lp.birth_dt, ''), 101),  -- MM/DD/YYYY
                 TRY_CONVERT(DATE, NULLIF(lp.birth_dt, ''), 23))   -- YYYY-MM-DD
                                  AS birth_date,
        lp.gender_cd,
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(lp.phone_no,
            '(', ''), ')', ''), '-', ''), '.', ''), ' ', '') AS phone_digits,
        lp.zip_cd,
        lp.status_cd
    FROM legacy_patients AS lp
)
SELECT
    CONCAT('L', pat_no)                                       AS mrn,
    CONCAT(UPPER(LEFT(last_nm_trim, 1)),
           LOWER(SUBSTRING(last_nm_trim, 2, 60)))             AS last_name,
    first_nm_trim                                             AS first_name,
    birth_date,
    CASE WHEN gender_cd IN ('M', '1') THEN 'Male'
         WHEN gender_cd IN ('F', '2') THEN 'Female'
         ELSE 'Unknown' END                                   AS sex,
    CASE WHEN LEN(phone_digits) = 10 AND phone_digits <> '0000000000'
         THEN CONCAT('(', SUBSTRING(phone_digits, 1, 3), ') ',
                     SUBSTRING(phone_digits, 4, 3), '-',
                     SUBSTRING(phone_digits, 7, 4))
         END                                                  AS phone,
    CASE WHEN LEN(zip_cd) >= 5 THEN LEFT(zip_cd, 5) END       AS zip_code,
    CASE WHEN status_cd = 'A' THEN 1 ELSE 0 END               AS active_flag
FROM cleaned;

/* ---------- Problem list ---------- */
CREATE VIEW stg_problem_list AS
SELECT
    CONCAT('L', pr.pat_no)                         AS mrn,
    pr.icd9_cd                                     AS legacy_icd9_cd,
    cw.icd10_cd                                    AS icd10_code,
    cw.icd10_description,
    TRY_CONVERT(DATE, pr.onset_dt, 101)            AS onset_date,
    CASE pr.problem_status WHEN 'ACTIVE'   THEN 'Active'
                           WHEN 'RESOLVED' THEN 'Resolved' END AS status
FROM legacy_problems AS pr
LEFT JOIN icd9_to_icd10_crosswalk AS cw
    ON cw.icd9_cd = pr.icd9_cd;
