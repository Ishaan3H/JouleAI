#!/usr/bin/env python3
"""Summarise JouleAI tester exports (Settings -> Your data -> Export my data).

Usage:
    scripts/stats.py JouleAI-export-*.json
    scripts/stats.py exports/*.json --csv stats.csv

Each export file counts as one tester (named after the file). Prints a block of
numbers per tester and one for everyone together; --csv also writes one row per
tester plus an "ALL" row. Standard library only: no installs needed.

Events from the Debug menu's test overlay ("isTest": true) are ignored.
"""

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

# The columns, in the order they're printed and written to the CSV.
# Counts first; the rates are worked out from them in add_rates().
COUNT_FIELDS = [
    "commitments", "committed",
    "fired", "started", "cancelled_from_card", "rescheduled_from_card",
    "cancelled_total", "rescheduled_total",
    "headsup_shown", "headsup_ready", "headsup_push", "headsup_not_today",
    "completed", "broke_early",
    "outcome_done", "outcome_partly", "outcome_didnt", "outcome_none",
    "lock_shown", "back_to_task", "parked_items",
    "focus_ok", "focus_missing", "focus_failed",
]
RATE_FIELDS = ["start_rate", "skip_rate", "broke_early_rate", "locks_per_session"]


def count(export):
    """Turns one export file's contents into a dict of counts."""
    c = Counter()
    commitments = export.get("commitments", [])
    sessions = export.get("sessions", [])
    events = [e for e in export.get("events", []) if not e.get("isTest")]

    c["commitments"] = len(commitments)
    c["committed"] = sum(1 for x in commitments if x.get("isCommitted"))

    for e in events:
        kind, detail = e.get("kind"), e.get("detail") or ""
        if kind == "overlayShown":
            c["fired"] += 1          # the full-screen Start card appeared
        elif kind == "started":
            c["started"] += 1
        elif kind == "cancelled":
            c["cancelled_total"] += 1
            if "overlay" in detail:
                c["cancelled_from_card"] += 1
        elif kind == "rescheduled":
            c["rescheduled_total"] += 1
            if "overlay" in detail:
                c["rescheduled_from_card"] += 1
        elif kind == "headsUpShown":
            c["headsup_shown"] += 1
        elif kind == "respondedReady":
            c["headsup_ready"] += 1
        elif kind == "respondedPush":
            c["headsup_push"] += 1
        elif kind == "respondedNotToday":
            c["headsup_not_today"] += 1
        elif kind == "completed":
            c["completed"] += 1
        elif kind == "brokeOut":
            c["broke_early"] += 1
        elif kind in ("lockShown", "lockOverlayShown"):
            c["lock_shown"] += 1
        elif kind == "backToTask":
            c["back_to_task"] += 1
        elif kind == "focusShortcut":
            # Detail looks like 'Focus on via "Name": ran (exit 0)'.
            if detail.endswith("ran (exit 0)"):
                c["focus_ok"] += 1
            elif "not found" in detail:
                c["focus_missing"] += 1
            else:
                c["focus_failed"] += 1

    # Outcomes come from sessions.json, which holds the final answer.
    for s in sessions:
        outcome = s.get("outcome")
        if outcome in ("done", "partly", "didnt"):
            c["outcome_" + outcome] += 1
        elif outcome is None and s.get("endedAt"):
            c["outcome_none"] += 1   # finished but the end window wasn't answered
        # Parked thoughts are stored one per line.
        c["parked_items"] += sum(1 for line in (s.get("parkedNotes") or "").splitlines() if line.strip())

    return c


def ratio(a, b):
    return round(a / b, 2) if b else None


def add_rates(c):
    """Adds the rate columns to a dict of counts."""
    row = {f: c.get(f, 0) for f in COUNT_FIELDS}
    row["start_rate"] = ratio(c["started"], c["fired"])
    row["skip_rate"] = ratio(c["fired"] - c["started"], c["fired"])
    row["broke_early_rate"] = ratio(c["broke_early"], c["started"])
    row["locks_per_session"] = ratio(c["lock_shown"], c["started"])
    return row


def pct(x):
    return "n/a" if x is None else f"{x:.0%}"


def print_block(name, row, meta=""):
    """One human-readable summary."""
    print(f"== {name} {meta}".rstrip())
    print(f"  Commitments made:     {row['commitments']} ({row['committed']} committed)")
    print(f"  Sessions fired:       {row['fired']}")
    print(f"  Start vs skip:        {row['started']} started ({pct(row['start_rate'])}), "
          f"{row['fired'] - row['started']} not started ({pct(row['skip_rate'])}): "
          f"{row['cancelled_from_card']} cancelled, {row['rescheduled_from_card']} rescheduled on the card")
    print(f"  Heads-up responses:   {row['headsup_shown']} shown → ready {row['headsup_ready']}, "
          f"push {row['headsup_push']}, not today {row['headsup_not_today']}")
    print(f"  Reschedules:          {row['rescheduled_total']} (cancels overall: {row['cancelled_total']})")
    print(f"  Broke early:          {row['broke_early']} of {row['started']} started ({pct(row['broke_early_rate'])}); "
          f"{row['completed']} ran to the end")
    print(f"  Outcomes:             done {row['outcome_done']}, partly {row['outcome_partly']}, "
          f"didn't {row['outcome_didnt']}, unanswered {row['outcome_none']}")
    locks = row["locks_per_session"]
    print(f"  Lock shows:           {row['lock_shown']} ({'n/a' if locks is None else locks} per session), "
          f"Back to task {row['back_to_task']}")
    print(f"  Parking-lot items:    {row['parked_items']}")
    print(f"  Focus shortcut:       {row['focus_ok']} worked, "
          f"{row['focus_missing'] + row['focus_failed']} failed "
          f"({row['focus_missing']} missing, {row['focus_failed']} errors)")
    print()


def main():
    parser = argparse.ArgumentParser(description="Summarise JouleAI tester exports.")
    parser.add_argument("exports", nargs="+", type=Path, help="JouleAI-export-*.json files")
    parser.add_argument("--csv", type=Path, help="also write the numbers to this CSV file")
    args = parser.parse_args()

    total = Counter()
    rows = []
    for path in args.exports:
        try:
            export = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            print(f"Skipping {path}: {error}", file=sys.stderr)
            continue
        c = count(export)
        total.update(c)
        row = add_rates(c)
        meta = f"(app {export.get('appVersion', '?')}, {export.get('macOSVersion', '?')})"
        print_block(path.stem, row, meta)
        rows.append({"tester": path.stem, **row})

    if not rows:
        sys.exit("No readable export files.")
    overall = add_rates(total)
    print_block(f"ALL ({len(rows)} testers)", overall)

    if args.csv:
        with args.csv.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=["tester"] + COUNT_FIELDS + RATE_FIELDS)
            writer.writeheader()
            writer.writerows(rows)
            writer.writerow({"tester": "ALL", **overall})
        print(f"CSV written to {args.csv}")


if __name__ == "__main__":
    main()
