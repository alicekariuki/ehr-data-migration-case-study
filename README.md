# EHR Data Migration Case Study

**Moving patient demographics and problem lists from a legacy EHR to a new EHR, without losing, duplicating, or corrupting clinical data.**

![SQL](https://img.shields.io/badge/SQL_Server-T--SQL-CC2927?logo=microsoftsqlserver&logoColor=white)
![Excel](https://img.shields.io/badge/Excel-mapping_spec-217346?logo=microsoftexcel&logoColor=white)
![Data](https://img.shields.io/badge/data-100%25_synthetic-lightgrey)

---

## Scenario

A health system is retiring its legacy EHR. Before go-live, the migration team has to prove that every patient and problem-list record either migrated correctly or was logged with a reason. This case study covers the analyst's part of that work: **mapping, transformation, validation, and defect management.**

## What's in this repo

| Deliverable | File |
|---|---|
| Source-to-target mapping spec | [`mapping/source_to_target_mapping.csv`](mapping/source_to_target_mapping.csv) |
| ICD-9 → ICD-10 crosswalk | [`mapping/icd9_to_icd10_crosswalk.csv`](mapping/icd9_to_icd10_crosswalk.csv) |
| Transformation SQL | [`sql/01_transform.sql`](sql/01_transform.sql) |
| Validation checks (V01–V09) | [`sql/02_validation_checks.sql`](sql/02_validation_checks.sql) |
| Test plan with Mock 1 results | [`test-plan/test_plan.md`](test-plan/test_plan.md) |
| Defect log | [`test-plan/defect_log.csv`](test-plan/defect_log.csv) |
| Synthetic legacy extract | [`data/`](data/) (built by `scripts/generate_legacy_data.py`) |

## Mock 1 results

The legacy extract held **2,512 patients** and **3,991 problem-list rows**. Row counts reconciled, and the validation checks found these issues:

| Issue | Records | Action |
|---|---|---|
| Missing or placeholder birth dates (`00/00/0000`) | 138 | Error queue → Registration verification |
| Probable duplicate patients (same name, DOB, and phone) | 10 pairs | HIM review and merge before load |
| ICD-9 codes missing from the crosswalk | 224 rows (2 codes) | Clinical informaticist approved new mappings |
| Orphan problem-list rows | 6 | Excluded and reported |
| Phones or ZIPs nulled by cleansing | 529 | Accepted by data owner |

**6 defects logged. 2 resolved and 2 accepted before Mock 2; 2 high-severity items still open, with owners assigned.**

## Transformation highlights

- **Dates:** `TRY_CONVERT` with styles 101 and 23 handles mixed formats, and `NULLIF` stops blank strings from silently becoming `1900-01-01` in SQL Server.
- **Code sets:** Legacy gender codes (`M/F/U/1/2/blank`) are standardized to `Male/Female/Unknown`.
- **Phones:** Punctuation is stripped and numbers are reformatted to `(XXX) XXX-XXXX`. Placeholder numbers are nulled.
- **Diagnoses:** ICD-9 codes are mapped to ICD-10-CM through a crosswalk. Unmapped codes are routed for clinical review rather than dropped.
- **Duplicates:** A self-join on name, DOB, and phone finds probable duplicate identities before they reach the new system.

## Skills demonstrated

- Writing a mapping spec that developers, HIM, and clinicians can all review
- Defensive SQL for messy legacy data
- Reconciliation and data-quality testing across multiple mock conversions
- Defect triage with severity, root cause, owner, and resolution
- Working across Registration, HIM, and clinical informatics

## About the data

All data is **synthetic**. Names, IDs, and phone numbers are randomly generated, and data-quality problems were planted on purpose.

---

**Alice Kariuki** · Healthcare Data Analyst | PMP | CSM · [LinkedIn](https://www.linkedin.com/in/alice-kariuki-195a843a6)
