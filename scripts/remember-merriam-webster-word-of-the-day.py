"""Persist a displayed Word of the Day entry and keep a small random-access history."""

import hashlib
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
history_dir = pathlib.Path(sys.argv[2])
history_index = pathlib.Path(sys.argv[3])

body = source.read_bytes()
if not body:
    raise SystemExit(0)

history_dir.mkdir(parents=True, exist_ok=True)
digest = hashlib.sha256(body).hexdigest()
(history_dir / f"{digest}.txt").write_bytes(body)

items = []
if history_index.exists():
    for line in history_index.read_text(encoding="ascii", errors="ignore").splitlines():
        line = line.strip()
        if line and line != digest and line not in items:
            items.append(line)

items.insert(0, digest)
items = items[:100]
history_index.write_text("\n".join(items) + "\n", encoding="ascii")

kept = set(items)
for path in history_dir.glob("*.txt"):
    name = path.stem
    if len(name) == 64 and all(char in "0123456789abcdef" for char in name):
        if name not in kept:
            path.unlink()
