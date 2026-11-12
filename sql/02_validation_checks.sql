/* =====================================================================
   Migration validation checks (SQL Server / T-SQL)
   Run after 01_transform.sql. Each check returns a count; any non-zero
   count in a "must be 0" check is logged as a defect (see
   test-plan/defect_log.csv).
   ===================================================================== */

/* V01 - Record count reconciliation: source vs. staged */
SELECT 'V01 Patient row count' AS check_name,
       (SELECT COUNT(*) FROM legacy_patients) AS source_rows,
       (SELECT COUNT(*) FROM stg_patient)     AS target_rows;

SELECT 'V01 Problem row count' AS check_name,
       (SELECT COUNT(*) FROM legacy_problems) AS source_rows,
       (SELECT COUNT(*) FROM stg_problem_list) AS target_rows;

/* V02 - Required fields populated (must be 0) */
SELECT 'V02 Missing/invalid birth_date' AS check_name, COUNT(*) AS failures
FROM stg_patient WHERE birth_date IS NULL
UNION ALL
SELECT 'V02 Missing last_name', COUNT(*)
FROM stg_patient WHERE last_name IS NULL OR last_name = ''
UNION ALL
SELECT 'V02 Sex = Unknown (review)', COUNT(*)
FROM stg_patient WHERE sex = 'Unknown';

/* V03 - Unique MRN (must be 0) */
SELECT 'V03 Duplicate MRN' AS check_name, COUNT(*) AS failures
FROM (SELECT mrn FROM stg_patient GROUP BY mrn HAVING COUNT(*) > 1) AS d;

/* V04 - Probable duplicate patients: same name + DOB + phone under
         different MRNs (must be reviewed by HIM before go-live) */
SELECT 'V04 Probable duplicate patient pairs' AS check_name, COUNT(*) AS failures
FROM stg_patient AS a
JOIN stg_patient AS b
    ON  a.last_name  = b.last_name
    AND a.first_name = b.first_name
    AND a.birth_date = b.birth_date
    AND a.phone      = b.phone
    AND a.mrn        < b.mrn;

/* V05 - Unmapped diagnosis codes (must be 0) */
SELECT CONCAT('V05 Unmapped ICD-9 code: ', legacy_icd9_cd) AS check_name,
       COUNT(*) AS failures
FROM stg_problem_list
WHERE icd10_code IS NULL
GROUP BY legacy_icd9_cd;

/* V06 - Orphan problem rows: no matching patient (must be 0) */
SELECT 'V06 Orphan problem-list rows' AS check_name, COUNT(*) AS failures
FROM stg_problem_list AS pl
WHERE NOT EXISTS (SELECT 1 FROM stg_patient AS p WHERE p.mrn = pl.mrn);

/* V07 - Format checks after transformation (must be 0) */
SELECT 'V07 Phone not in (XXX) XXX-XXXX format' AS check_name, COUNT(*) AS failures
FROM stg_patient WHERE phone IS NOT NULL AND LEN(phone) <> 14
UNION ALL
SELECT 'V07 Name has leading/trailing spaces', COUNT(*)
FROM stg_patient WHERE last_name <> LTRIM(RTRIM(last_name))
UNION ALL
SELECT 'V07 Birth date in the future or age > 120', COUNT(*)
FROM stg_patient
WHERE birth_date > CAST(GETDATE() AS DATE)
   OR birth_date < DATEADD(YEAR, -120, CAST(GETDATE() AS DATE));

/* V08 - Fields set to NULL by cleansing (informational) */
SELECT 'V08 Phone nulled (invalid/placeholder)' AS check_name, COUNT(*) AS affected
FROM stg_patient WHERE phone IS NULL
UNION ALL
SELECT 'V08 ZIP nulled (fewer than 5 digits)', COUNT(*)
FROM stg_patient WHERE zip_code IS NULL;

/* V09 - Value distribution: source vs. target (should reconcile) */
SELECT 'Source' AS side, gender_cd AS value, COUNT(*) AS n
FROM legacy_patients GROUP BY gender_cd
UNION ALL
SELECT 'Target', sex, COUNT(*)
FROM stg_patient GROUP BY sex
ORDER BY side, value;
