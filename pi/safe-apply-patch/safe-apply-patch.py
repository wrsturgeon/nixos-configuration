#!/usr/bin/env python3
"""Validate a Codex apply_patch patch before delegating to Codex.

This wrapper intentionally keeps Codex's patch language and implementation, but
adds a small local safety policy for agent use: paths must stay under the current
working directory, patch operations must not cross symlinks, adds/moves must not
overwrite existing files, and updates must avoid text cases Codex does not
preserve cleanly.
"""

from __future__ import annotations

import os
import stat
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import TypedDict


class RejectedPatch(Exception):
    """The patch is valid enough to inspect but violates the local safety policy."""


class Operation(TypedDict, total=False):
    """One top-level Codex apply_patch operation."""

    kind: str
    path: str
    body: list[str]
    move_to: str


class MoveMode(TypedDict):
    """A successful move should leave the destination with the source mode."""

    destination: Path
    mode: int


MOVE_PREFIX = "*** Move to: "
END_PATCH = "*** End Patch"


def reject(message: str) -> None:
    """Fail with the exact message shown to the model/user."""

    raise RejectedPatch(message)


def read_patch_from_cli() -> tuple[str, str]:
    """Return the Codex executable path and the patch from argv or stdin."""

    if len(sys.argv) < 2:
        raise SystemExit("usage: safe-apply-patch.py CODEX_EXECUTABLE [PATCH]")

    codex_executable = sys.argv[1]
    patch_args = sys.argv[2:]
    if len(patch_args) == 0:
        try:
            patch = sys.stdin.buffer.read().decode("utf-8")
        except UnicodeDecodeError as error:
            reject(f"Patch input must be UTF-8: {error}")
    elif len(patch_args) == 1:
        patch = patch_args[0]
    else:
        reject("apply_patch accepts either one PATCH argument or patch text on stdin.")

    return codex_executable, patch


def parse_patch(patch: str) -> list[Operation]:
    """Parse just enough of Codex's patch structure to enforce path policy."""

    lines = patch.splitlines()
    if not lines or lines[0] != "*** Begin Patch":
        reject("Patch must start with '*** Begin Patch'.")
    if lines[-1] != END_PATCH:
        reject("Patch must end with '*** End Patch'.")

    operations: list[Operation] = []
    current: Operation | None = None

    def finish_current() -> None:
        if current is not None:
            operations.append(current)

    for line in lines[1:-1]:
        if line.startswith("*** Add File: "):
            finish_current()
            current = {"kind": "add", "path": line.removeprefix("*** Add File: "), "body": []}
            continue
        if line.startswith("*** Delete File: "):
            finish_current()
            current = {"kind": "delete", "path": line.removeprefix("*** Delete File: "), "body": []}
            continue
        if line.startswith("*** Update File: "):
            finish_current()
            current = {"kind": "update", "path": line.removeprefix("*** Update File: "), "body": []}
            continue
        if current is None:
            reject(f"Unexpected patch line outside a file operation: {line!r}")
        current["body"].append(line)

    finish_current()
    if not operations:
        reject("Patch must contain at least one file operation.")
    return operations


def relative_parts(raw_path: str) -> tuple[str, ...]:
    """Validate and split one patch path without normalizing away danger."""

    if raw_path == "":
        reject("Patch paths must not be empty.")

    path = PurePosixPath(raw_path)
    if path.is_absolute():
        reject(f"Absolute paths are not allowed in patches: {raw_path}")
    if any(part == ".." for part in path.parts):
        reject(f"Parent-directory traversal is not allowed in patches: {raw_path}")

    return path.parts


def absolute_path(cwd: Path, raw_path: str) -> Path:
    """Convert a validated patch path to a cwd-relative filesystem path."""

    return cwd.joinpath(*relative_parts(raw_path))


def reject_symlink_components(cwd: Path, raw_path: str, *, include_leaf: bool) -> None:
    """Reject paths that are, or pass through, existing symlinks."""

    parts = relative_parts(raw_path)
    checked = parts if include_leaf else parts[:-1]
    current = cwd
    for part in checked:
        current = current / part
        try:
            mode = os.lstat(current).st_mode
        except FileNotFoundError:
            return
        if stat.S_ISLNK(mode):
            reject(f"Symlink paths are not allowed in patches: {raw_path} uses {current}")


def reject_existing_path(path: Path, raw_path: str, action: str) -> None:
    """Reject an operation that would overwrite an existing path or symlink."""

    if os.path.lexists(path):
        reject(f"Refusing to {action} over existing path: {raw_path}")


def read_supported_update_file(path: Path, raw_path: str) -> list[str] | None:
    """Read an update target, rejecting text cases Codex does not preserve."""

    try:
        mode = os.lstat(path).st_mode
    except FileNotFoundError:
        return None

    if not stat.S_ISREG(mode):
        reject(f"Refusing to update non-regular file: {raw_path}")

    data = path.read_bytes()
    if b"\r" in data:
        reject(f"Refusing to update file with CRLF/CR line endings: {raw_path}")
    if data and not data.endswith(b"\n"):
        reject(f"Refusing to update file without a final newline: {raw_path}")
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        reject(f"Refusing to update non-UTF-8 file {raw_path}: {error}")

    return text.splitlines()


def parse_update_body(operation: Operation) -> tuple[str | None, list[list[str]], bool]:
    """Return move destination, old-side context chunks, and whether content changes."""

    move_to: str | None = None
    chunks: list[list[str]] = []
    current_chunk: list[str] = []
    has_content_change = False

    def finish_chunk() -> None:
        nonlocal current_chunk
        if current_chunk:
            chunks.append(current_chunk)
            current_chunk = []

    for line in operation["body"]:
        if line.startswith(MOVE_PREFIX):
            if move_to is not None:
                reject(f"Update for {operation['path']} contains more than one move destination.")
            move_to = line.removeprefix(MOVE_PREFIX)
            continue
        if line.startswith("@@"):
            finish_chunk()
            continue
        if line == "*** End of File":
            continue
        if line == "":
            reject(f"Invalid empty update line in patch for {operation['path']}.")

        marker = line[0]
        text = line[1:]
        if marker not in {" ", "+", "-"}:
            reject(f"Invalid update line marker {marker!r} in patch for {operation['path']}.")
        if marker in {"+", "-"}:
            has_content_change = True
        if marker in {" ", "-"}:
            current_chunk.append(text)

    finish_chunk()
    if has_content_change and not chunks:
        reject(f"Refusing ambiguous update without old-side context: {operation['path']}")

    return move_to, chunks, has_content_change


def count_sequence(haystack: list[str], needle: list[str]) -> int:
    """Count contiguous occurrences of one sequence of lines in another."""

    if not needle or len(needle) > len(haystack):
        return 0
    return sum(1 for index in range(len(haystack) - len(needle) + 1) if haystack[index : index + len(needle)] == needle)


def reject_ambiguous_context(file_lines: list[str], raw_path: str, chunks: list[list[str]]) -> None:
    """Require each old-side update chunk to identify exactly one location."""

    for chunk in chunks:
        matches = count_sequence(file_lines, chunk)
        if matches == 0:
            reject(f"Update context was not found in {raw_path}.")
        if matches > 1:
            reject(f"Refusing ambiguous update context in {raw_path}; matched {matches} locations.")


def validate_operations(cwd: Path, operations: list[Operation]) -> list[MoveMode]:
    """Enforce the local safety policy and return modes to restore after moves."""

    move_modes: list[MoveMode] = []

    for operation in operations:
        raw_path = operation["path"]
        path = absolute_path(cwd, raw_path)
        kind = operation["kind"]

        if kind == "add":
            reject_symlink_components(cwd, raw_path, include_leaf=False)
            reject_existing_path(path, raw_path, "add a file")
            continue

        if kind == "delete":
            reject_symlink_components(cwd, raw_path, include_leaf=True)
            continue

        if kind != "update":
            reject(f"Unknown patch operation: {kind}")

        reject_symlink_components(cwd, raw_path, include_leaf=True)
        move_to, chunks, _has_content_change = parse_update_body(operation)
        file_lines = read_supported_update_file(path, raw_path)
        if file_lines is not None:
            reject_ambiguous_context(file_lines, raw_path, chunks)

        if move_to is None:
            continue

        destination = absolute_path(cwd, move_to)
        reject_symlink_components(cwd, move_to, include_leaf=False)
        reject_existing_path(destination, move_to, "move a file")
        if path.exists():
            move_modes.append({"destination": destination, "mode": stat.S_IMODE(os.stat(path).st_mode)})

    return move_modes


def delegate_to_codex(codex_executable: str, patch: str) -> int:
    """Run Codex's standalone apply_patch mode with inherited stdout/stderr."""

    completed = subprocess.run(
        ["apply_patch"],
        executable=codex_executable,
        input=patch.encode("utf-8"),
        check=False,
    )
    return completed.returncode


def restore_move_modes(move_modes: list[MoveMode]) -> None:
    """Restore source permissions on successful Codex move destinations."""

    for entry in move_modes:
        try:
            os.chmod(entry["destination"], entry["mode"])
        except OSError as error:
            reject(f"Patch succeeded, but preserving mode on {entry['destination']} failed: {error}")


def main() -> int:
    """Validate, delegate, and apply post-success move-mode preservation."""

    try:
        codex_executable, patch = read_patch_from_cli()
        operations = parse_patch(patch)
        move_modes = validate_operations(Path.cwd(), operations)
    except RejectedPatch as error:
        print(f"apply_patch rejected patch: {error}", file=sys.stderr)
        return 1

    returncode = delegate_to_codex(codex_executable, patch)
    if returncode != 0:
        return returncode

    try:
        restore_move_modes(move_modes)
    except RejectedPatch as error:
        print(f"apply_patch rejected patch: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
