#!/usr/bin/env python3
"""Regenerate Handy's committed catalog from pinned, licensed sources."""

from __future__ import annotations

import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Sources/HandyCore/Resources/starter-library.json"

KAOMOJI_COMMIT = "4a11807390f1396d075eccc9715dc467680396f6"
EMOJI_COMMIT = "b4da69426d5dc6e8c8c02c09b163ff3e7160b316"
KAOMOJI_URL = f"https://raw.githubusercontent.com/freysie/kaomoji-palette/{KAOMOJI_COMMIT}/Sources/KaomojiInputMethod/DataSource.swift"
EMOJI_URL = f"https://raw.githubusercontent.com/muan/emojilib/{EMOJI_COMMIT}/dist/emoji-en-US.json"

CATEGORIES = [
    {"id": "kaomoji", "title": "Kaomoji", "symbol": "textformat.characters", "displayGlyph": ";)", "webSymbol": "brackets-curly", "order": 10},
    {"id": "emoji", "title": "Emoji", "symbol": "face.smiling", "webSymbol": "smiley", "order": 20},
    {"id": "snippet", "title": "Snippets", "symbol": "text.quote", "webSymbol": "quotes", "order": 30, "capabilities": ["custom-entry"]},
]

SEED_ITEMS = [
    {"id": "shrug", "text": "¯\\_(ツ)_/¯", "title": "Shrug", "tags": ["confused"], "categoryID": "kaomoji", "isPinned": True, "useCount": 0},
    {"id": "happy", "text": "(◕‿◕)", "title": "Happy", "tags": ["happy"], "categoryID": "kaomoji", "isPinned": True, "useCount": 0},
    {"id": "table-flip", "text": "(╯°□°）╯︵ ┻━┻", "title": "Table flip", "tags": ["angry"], "categoryID": "kaomoji", "isPinned": False, "useCount": 0},
    {"id": "sparkles", "text": "✨", "title": "Sparkles", "tags": ["celebrate"], "categoryID": "emoji", "isPinned": True, "useCount": 0},
    {"id": "wave", "text": "👋", "title": "Wave", "tags": ["hello"], "categoryID": "emoji", "isPinned": False, "useCount": 0},
    {"id": "thanks", "text": "Thank you!", "title": "Quick thank-you", "tags": ["reply", "gratitude"], "categoryID": "snippet", "isPinned": False, "useCount": 0},
]


def download(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "Handy catalog updater"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def parse_kaomoji(source: str) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    mood: str | None = None
    for line in source.splitlines():
        start = re.match(r'^\s*\("([^"]+)", \[\s*$', line)
        if start:
            mood = start.group(1)
            continue
        if mood and re.match(r"^\s*\]\),?\s*$", line):
            mood = None
            continue
        if mood:
            candidate = line.strip().removesuffix(",")
            if candidate.startswith('"') and candidate.endswith('"'):
                entries.append((mood, json.loads(candidate)))
    if not entries:
        raise RuntimeError("No kaomoji were parsed from the pinned source")
    return entries


def make_catalog() -> dict[str, object]:
    items = list(SEED_ITEMS)
    seen = {item["text"] for item in items}

    mood_counts: dict[str, int] = {}
    for mood, text in parse_kaomoji(download(KAOMOJI_URL)):
        if text in seen:
            continue
        seen.add(text)
        mood_id = slug(mood)
        mood_counts[mood_id] = mood_counts.get(mood_id, 0) + 1
        number = mood_counts[mood_id]
        items.append({
            "id": f"kaomoji-{mood_id}-{number:03d}",
            "text": text,
            "title": f"{mood} {number}",
            "tags": [mood_id],
            "categoryID": "kaomoji",
            "isPinned": False,
            "useCount": 0,
        })

    emoji_keywords = json.loads(download(EMOJI_URL))
    for emoji, keywords in emoji_keywords.items():
        if emoji in seen or not keywords:
            continue
        seen.add(emoji)
        title = keywords[0].replace("_", " ").capitalize()
        codepoints = "-".join(f"{ord(character):x}" for character in emoji)
        tags = list(dict.fromkeys(keyword.replace("_", " ") for keyword in keywords[1:]))[:12]
        items.append({
            "id": f"emoji-{codepoints}",
            "text": emoji,
            "title": title,
            "tags": tags,
            "categoryID": "emoji",
            "isPinned": False,
            "useCount": 0,
        })

    return {"version": 2, "catalogRevision": 3, "categories": CATEGORIES, "items": items}


def main() -> None:
    catalog = make_catalog()
    OUTPUT.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(catalog['items'])} items to {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
