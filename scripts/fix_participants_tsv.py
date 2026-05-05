#!/usr/bin/env python3
"""
fix_participants_tsv.py
───────────────────────
Add `sub-` prefix to the participant_id column in participants.tsv if missing.

Some OpenNeuro datasets (including ds000174) store participant_id as bare
numeric strings ("101", "103") while BIDS directories are named with the
`sub-` prefix ("sub-101", "sub-103"). This causes silent lookup failures
in scripts that match TSV rows to BIDS directories.

This script is idempotent: it backs up the original on first run only,
and is a no-op if all participant_id values already have the prefix.

Environment variables (optional):
    PROJ_DIR   — project root (default: parent of this script's dir)
    DATASET_ID — BIDS dataset ID (default: ds000174)
"""
import os
import shutil
from pathlib import Path

import pandas as pd

PROJ_DIR = Path(os.environ.get("PROJ_DIR", Path(__file__).resolve().parent.parent))
DATASET_ID = os.environ.get("DATASET_ID", "ds000174")
BIDS_DIR = PROJ_DIR / "data" / "bids" / DATASET_ID
tsv_path = BIDS_DIR / "participants.tsv"

if not tsv_path.exists():
    print(f"[fix-tsv] ERROR: participants.tsv not found at {tsv_path}")
    raise SystemExit(1)

df = pd.read_csv(tsv_path, sep="\t")
print(f"[fix-tsv] Loaded {len(df)} rows")
print(f"[fix-tsv] Columns: {list(df.columns)}")
print(f"[fix-tsv] First 3 participant_id values: {df['participant_id'].head(3).tolist()}")

df["participant_id"] = df["participant_id"].astype(str)
needs_fix = ~df["participant_id"].str.startswith("sub-")
n_to_fix = int(needs_fix.sum())

if n_to_fix == 0:
    print("[fix-tsv] ✓ All participant_ids already have sub- prefix — nothing to do")
else:
    print(f"[fix-tsv] {n_to_fix} rows need sub- prefix added")

    backup = tsv_path.with_suffix(".tsv.original")
    if not backup.exists():
        shutil.copy(tsv_path, backup)
        print(f"[fix-tsv] Backed up original to {backup.name}")

    df.loc[needs_fix, "participant_id"] = "sub-" + df.loc[needs_fix, "participant_id"]
    df.to_csv(tsv_path, sep="\t", index=False)
    print(f"[fix-tsv] ✓ Updated {tsv_path}")
    print(f"[fix-tsv] First 3 participant_id values now: {df['participant_id'].head(3).tolist()}")
