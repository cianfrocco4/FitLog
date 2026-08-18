#!/usr/bin/env python3
"""Build living-users/INBOX.md from persona review JSONL (and optional tick log)."""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

CATEGORIES = ("likes", "dislikes", "bugs", "improvements")


def load_jsonl(path: Path) -> list[dict]:
    if not path.is_file():
        return []
    rows: list[dict] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def note_lines(notes: list) -> list[str]:
    if not notes:
        return ["_None reported._"]
    out: list[str] = []
    for note in notes:
        area = note.get("area", "App")
        nid = note.get("id", "")
        detail = note.get("detail", "")
        out.append(f"- **{area}** (`{nid}`): {detail}")
    return out


def render_review(review: dict) -> str:
    persona = review.get("persona", "unknown")
    name = review.get("displayName", persona)
    day = review.get("dayKey", "")
    premium = "Premium" if review.get("isPremium") else "Free"
    training = "training day" if review.get("isTrainingDay") else "rest day"
    tick = review.get("tickOutcome") or "none"
    lines = [
        f"## {name} (`{persona}`) — {day}",
        "",
        f"{premium} · {training} · tick: `{tick}` · "
        f"sessions: {review.get('sessionCount', 0)} · library: {review.get('libraryCount', 0)}",
    ]
    if review.get("lastWorkoutName"):
        lines.append(f"Last workout: {review['lastWorkoutName']}")
    if review.get("oldestSessionDaysAgo") is not None:
        lines.append(f"Oldest session: {review['oldestSessionDaysAgo']} day(s) ago")
    lines.append("")
    for title, key in (
        ("Likes", "likes"),
        ("Dislikes", "dislikes"),
        ("Bugs", "bugs"),
        ("Improvements", "improvements"),
    ):
        lines.append(f"### {title}")
        lines.append("")
        lines.extend(note_lines(review.get(key) or []))
        lines.append("")
    lines.append("### Workflow")
    lines.append("")
    lines.append(review.get("workflow") or "_No workflow note._")
    lines.append("")
    return "\n".join(lines)


def assemble(store_dir: Path, max_chars: int) -> str:
    reviews = load_jsonl(store_dir / "fitlog-living-reviews.jsonl")
    ticks = load_jsonl(store_dir / "fitlog-living-ticks.jsonl")
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    parts = [
        "# Living user inbox",
        "",
        f"Generated {generated}. {len(reviews)} review(s), {len(ticks)} tick(s).",
        "",
        "These are simulated gym-goers reporting from their **real SwiftData stores** "
        "(likes, dislikes, bugs, UI/workflow improvements). Screenshots from the same "
        "run are on the workflow artifact `living-user-screenshots`.",
        "",
    ]

    if not reviews:
        parts.append("_No reviews yet. Run `scripts/run-daily-living-users.sh` with write-review enabled._")
        parts.append("")
        text = "\n".join(parts)
        return text[:max_chars]

    counts: Counter[str] = Counter()
    by_id_example: dict[str, str] = {}
    by_day: dict[str, list[dict]] = defaultdict(list)
    for review in reviews:
        by_day[str(review.get("dayKey") or "unknown")].append(review)
        for key in CATEGORIES:
            for note in review.get(key) or []:
                nid = note.get("id")
                if not nid:
                    continue
                counts[f"{key}:{nid}"] += 1
                by_id_example.setdefault(f"{key}:{nid}", note.get("detail") or nid)

    parts.append("## Recurring notes")
    parts.append("")
    parts.append("Stable ids across days (highest first). Use these when picking product work.")
    parts.append("")
    for key, n in counts.most_common(20):
        parts.append(f"- `{key}` ×{n} — {by_id_example.get(key, '')}")
    parts.append("")

    latest_day = max(by_day)
    parts.append(f"## Latest day ({latest_day})")
    parts.append("")
    for review in by_day[latest_day]:
        parts.append(render_review(review))
        parts.append("---")
        parts.append("")

    if ticks:
        parts.append("## Recent ticks")
        parts.append("")
        parts.append("```")
        for row in ticks[-15:]:
            parts.append(json.dumps(row, sort_keys=True))
        parts.append("```")
        parts.append("")

    text = "\n".join(parts)
    if len(text) > max_chars:
        text = text[: max_chars - 80].rstrip() + "\n\n_Truncated for GitHub comment size._\n"
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "store_dir",
        nargs="?",
        default="living-users",
        help="Folder with fitlog-living-reviews.jsonl (default: living-users)",
    )
    parser.add_argument(
        "--max-chars",
        type=int,
        default=60000,
        help="Truncate INBOX.md to this many characters (GitHub comment limit)",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Print markdown instead of writing INBOX.md",
    )
    args = parser.parse_args()
    store_dir = Path(args.store_dir)
    store_dir.mkdir(parents=True, exist_ok=True)
    text = assemble(store_dir, args.max_chars)
    if args.stdout:
        sys.stdout.write(text)
        if not text.endswith("\n"):
            sys.stdout.write("\n")
        return 0
    out = store_dir / "INBOX.md"
    out.write_text(text, encoding="utf-8")
    print(f"Wrote {out} ({len(text)} chars, {text.count(chr(10))} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
