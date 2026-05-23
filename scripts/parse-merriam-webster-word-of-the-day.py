"""Parse Merriam-Webster's Word of the Day HTML into terminal-friendly text."""

import html as html_lib
import pathlib
import re
import sys
import textwrap

raw = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
raw = re.sub(r"<!--.*?-->", " ", raw, flags=re.S)


def clean(fragment):
    fragment = re.sub(r"<!--.*?-->", " ", fragment, flags=re.S)
    fragment = re.sub(r"<(script|style)\b.*?</\1>", " ", fragment, flags=re.S | re.I)
    fragment = re.sub(r"<br\s*/?>", "\n", fragment, flags=re.I)
    fragment = re.sub(r"</(?:p|div|li|h[1-6])\s*>", "\n", fragment, flags=re.I)
    fragment = re.sub(r"<[^>]+>", "", fragment)
    text = html_lib.unescape(fragment).replace("\xa0", " ")
    lines = [" ".join(line.split()) for line in text.splitlines()]
    return "\n".join(line for line in lines if line).strip()


def find_text(pattern):
    match = re.search(pattern, raw, flags=re.S | re.I)
    return clean(match.group(1)) if match else ""


def between(start_pattern, end_pattern):
    start = re.search(start_pattern, raw, flags=re.S | re.I)
    if not start:
        return ""
    tail = raw[start.end() :]
    end = re.search(end_pattern, tail, flags=re.S | re.I)
    return tail[: end.start()] if end else ""


def paragraphs(section):
    found = re.findall(r"<p\b[^>]*>(.*?)</p>", section, flags=re.S | re.I)
    if not found:
        text = clean(section)
        return [text] if text else []

    result = []
    for para in found:
        text = clean(para)
        if not text:
            continue
        if text.startswith("See the entry"):
            continue
        result.append(text)
    return result


class_value = r"[\"'][^\"']*\b{}\b[^\"']*[\"']"

date = find_text(
    r"<div\b[^>]*class\s*=\s*"
    + class_value.format("w-a-title")
    + r"[^>]*>.*?<span>\s*:?\s*(.*?)\s*</span>"
)
word = find_text(
    r"<h2\b[^>]*class\s*=\s*"
    + class_value.format("word-header-txt")
    + r"[^>]*>(.*?)</h2>"
)
part_of_speech = find_text(
    r"<span\b[^>]*class\s*=\s*"
    + class_value.format("main-attr")
    + r"[^>]*>(.*?)</span>"
)
pronunciation = find_text(
    r"<span\b[^>]*class\s*=\s*"
    + class_value.format("word-syllables")
    + r"[^>]*>(.*?)</span>"
)

section_end = r"<span\b[^>]*data-eventName=[\"']{}[\"'][^>]*>"
what_html = between(
    r"<h2\b[^>]*>\s*What It Means\s*</h2>",
    section_end.format("wotd-definition"),
)
context_html = between(
    r"<h2\b[^>]*>\s*<span\b[^>]*class\s*=\s*"
    + class_value.format("wotd-example-label")
    + r"[^>]*>.*?</span>\s*in Context\s*</h2>",
    section_end.format("wotd-examples"),
)
if not context_html:
    context_html = between(
        r"<h2\b[^>]*>.*?\bIn\s+Context\b.*?</h2>",
        section_end.format("wotd-examples"),
    )
did_you_know_html = between(
    r"<h2\b[^>]*>\s*Did You Know\?\s*</h2>",
    section_end.format("wotd-did-you-know"),
)

what = paragraphs(what_html)
context = paragraphs(context_html)
did_you_know = paragraphs(did_you_know_html)

if not word or not what or not context or not did_you_know:
    raise SystemExit("Could not parse Merriam-Webster Word of the Day page")


def wrap(text):
    return textwrap.fill(
        text,
        width=76,
        break_long_words=False,
        break_on_hyphens=False,
    )


def add_section(lines, heading, paras):
    lines.append(heading)
    lines.append("-" * len(heading))
    for para in paras:
        lines.append(wrap(para))
        lines.append("")


meta = ", ".join(piece for piece in (part_of_speech, pronunciation) if piece)
lines = []
lines.append(
    f"Merriam-Webster Word of the Day — {date}"
    if date
    else "Merriam-Webster Word of the Day"
)
lines.append(f"{word} ({meta})" if meta else word)
lines.append("")
add_section(lines, "What It Means", what)
add_section(lines, f"{word} In Context", context)
add_section(lines, "Did You Know?", did_you_know)

while lines and lines[-1] == "":
    lines.pop()

print("\n".join(lines))
