"""
Generate a synthetic LEGACY EHR extract with realistic data-quality problems,
for practicing migration mapping and validation. All data is fictional.

Usage:  python scripts/generate_legacy_data.py [--seed 42]
"""
import argparse
import csv
import random
from datetime import date, timedelta
from pathlib import Path

FIRST = ["Grace", "Peter", "Mary", "John", "Faith", "David", "Ann", "James", "Ruth",
         "Daniel", "Joy", "Samuel", "Esther", "Paul", "Linda", "Mark", "Susan", "Brian"]
LAST = ["Wanjiru", "Kamau", "Smith", "Johnson", "Ochieng", "Brown", "Garcia", "Muthoni",
        "Lee", "Walker", "Njoroge", "Hall", "Young", "King", "Wright", "Scott"]

# ICD-9 codes in the legacy system -> description (crosswalk lives in /mapping)
LEGACY_DX = [("250.00", 14), ("401.9", 18), ("272.4", 12), ("296.32", 6), ("300.02", 6),
             ("493.90", 7), ("428.0", 5), ("496", 5), ("244.9", 6), ("714.0", 3),
             ("V58.67", 4), ("780.79", 3),   # 780.79 intentionally missing from crosswalk
             ("799.9", 2)]                   # 799.9 intentionally missing from crosswalk


def main(out: Path, seed: int, n: int):
    random.seed(seed)
    out.mkdir(parents=True, exist_ok=True)
    patients, problems = [], []
    for i in range(1, n + 1):
        pat_no = f"{100000 + i}"
        dob = date(1935, 1, 1) + timedelta(days=random.randint(0, 365 * 85))
        r = random.random()
        if r < 0.03:
            birth = "00/00/0000"                       # invalid placeholder
        elif r < 0.05:
            birth = ""                                  # missing
        elif r < 0.10:
            birth = dob.strftime("%Y-%m-%d")            # inconsistent format
        else:
            birth = dob.strftime("%m/%d/%Y")
        gender = random.choices(["M", "F", "U", "", "1", "2"], [44, 46, 2, 3, 2, 3])[0]
        digits = f"{random.choice([240, 301, 410, 443])}{random.randint(2000000, 9999999)}"
        phone = random.choice([digits, f"({digits[:3]}) {digits[3:6]}-{digits[6:]}",
                               f"{digits[:3]}-{digits[3:6]}-{digits[6:]}", f"{digits[:3]}.{digits[3:6]}.{digits[6:]}"])
        if random.random() < 0.04:
            phone = "000-000-0000"
        first, last = random.choice(FIRST), random.choice(LAST)
        if random.random() < 0.05:
            last = " " + last.upper() + " "            # whitespace / casing issues
        patients.append({"pat_no": pat_no, "last_nm": last, "first_nm": first, "birth_dt": birth,
                         "gender_cd": gender, "phone_no": phone,
                         "zip_cd": random.choice(["20874", "20876", "20850", "20877", "208741234", "2087"]),
                         "status_cd": random.choices(["A", "I"], [88, 12])[0]})
        for _ in range(random.choices([0, 1, 2, 3, 4], [20, 30, 25, 15, 10])[0]):
            code = random.choices([c for c, _ in LEGACY_DX], [w for _, w in LEGACY_DX])[0]
            problems.append({"pat_no": pat_no, "icd9_cd": code,
                             "onset_dt": (date(2005, 1, 1) + timedelta(days=random.randint(0, 6000))).strftime("%m/%d/%Y"),
                             "problem_status": random.choices(["ACTIVE", "RESOLVED"], [80, 20])[0]})
    # Seed duplicates: same person entered twice under different pat_no
    for dup in random.sample(patients, 12):
        clone = dict(dup)
        clone["pat_no"] = f"{900000 + len(patients)}"
        patients.append(clone)
    # Seed orphan problem rows (patient not in extract)
    for k in range(6):
        problems.append({"pat_no": f"{800000 + k}", "icd9_cd": "401.9",
                         "onset_dt": "01/15/2015", "problem_status": "ACTIVE"})

    for name, rows in (("legacy_patients.csv", patients), ("legacy_problems.csv", problems)):
        with open(out / name, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)
        print(f"  {name:<22} {len(rows):>6,} rows")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(Path(__file__).resolve().parent.parent / "data"))
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--patients", type=int, default=2500)
    a = ap.parse_args()
    main(Path(a.out), a.seed, a.patients)
