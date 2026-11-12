# Data Migration Test Plan

**Scope:** Patient demographics and problem list, moving from the legacy EHR to the target EHR
**Approach:** Three mock conversions (Mock 1 → Mock 2 → Dress rehearsal), then the production cutover

## 1. Objectives

- Every in-scope legacy record is either loaded or logged in the error queue with a reason
- Required fields are populated and conform to the target formats
- Clinical codes are mapped to valid ICD-10-CM codes, with clinical sign-off on every crosswalk entry
- No duplicate patient identities are created in the target system

## 2. Test levels

| Level | What is tested | Owner | Tool |
|---|---|---|---|
| Unit | Each transformation rule in the mapping spec | Data analyst | SQL (`01_transform.sql`) |
| Reconciliation | Source vs. target row counts and value distributions | Data analyst | SQL (`02_validation_checks.sql` V01, V09) |
| Data quality | Required fields, formats, orphans, duplicates | Data analyst + HIM | SQL (V02–V08) |
| Clinical validation | Code crosswalk accuracy; sample chart review | Clinical informaticist | Crosswalk review, 30-chart sample |
| UAT | End users find and use migrated data in their workflows | Clinical/registration super users | Scripted test cases |

## 3. Validation checks

| ID | Check | Pass criteria |
|---|---|---|
| V01 | Row count reconciliation | Source = target + error queue |
| V02 | Required fields populated | 0 failures, or failures routed to error queue |
| V03 | MRN uniqueness | 0 duplicates |
| V04 | Probable duplicate patients | All pairs reviewed by HIM and merged or cleared |
| V05 | Unmapped diagnosis codes | 0 unmapped, or each one has a clinically approved mapping |
| V06 | Orphan child records | 0 |
| V07 | Format conformance | 0 |
| V08 | Values nulled by cleansing | Reviewed and accepted by data owner |
| V09 | Value distribution | Source and target categories reconcile |

## 4. Mock 1 results (synthetic data)

| ID | Result | Count | Status |
|---|---|---|---|
| V01 | 2,512 patients and 3,991 problem rows in source and staging | — | ✅ Pass |
| V02 | Birth date missing or invalid (`00/00/0000`, blank) | 138 | ❌ Defect DEF-001 |
| V02 | Sex mapped to Unknown | 111 | ⚠️ Review DEF-002 |
| V03 | Duplicate MRN | 0 | ✅ Pass |
| V04 | Probable duplicate patient pairs | 10 | ❌ Defect DEF-003 |
| V05 | Unmapped ICD-9 780.79 / 799.9 | 132 / 92 | ❌ Defect DEF-004 |
| V06 | Orphan problem-list rows | 6 | ❌ Defect DEF-005 |
| V07 | Format conformance | 0 | ✅ Pass |
| V08 | Phone nulled / ZIP nulled | 105 / 424 | ⚠️ Review DEF-006 |

See [`defect_log.csv`](defect_log.csv) for root cause and resolution.

## 5. Entry and exit criteria

**Entry:** Mapping spec signed off · crosswalk reviewed · test environment refreshed
**Exit (go-live readiness):** All Critical/High defects closed · reconciliation balances · UAT sign-off from Registration, Nursing, and Providers · rollback plan approved

## 6. Roles

| Role | Responsibility |
|---|---|
| Project manager | Schedule, go/no-go decision, status reporting |
| Data analyst | Build and run transformations and validations, log defects |
| HIM | Duplicate patient review and merge decisions |
| Clinical informaticist | Code crosswalk approval, chart sampling |
| Super users | UAT execution |
