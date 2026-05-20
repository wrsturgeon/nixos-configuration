# Pi Python tool

This Pi package provides a `python` tool. It is a freeform tool: call it with the raw Python source as the tool body, not with JSON.

Optional dependencies are declared with a PEP 723-style header at the beginning of the script:

```python
# /// script
# dependencies = [
#   "requests",
# ]
# ///

import requests
print(requests.get("https://example.com").status_code)
```

The `dependencies` values are interpreted as Nix `python3Packages` attribute names and installed with `python3.withPackages`. They are not pip/uv requirement specifiers, so use names like `"requests"`, `"numpy"`, or `"beautifulsoup4"` rather than version constraints. If the header or `dependencies` field is absent, the script runs with the standard library only.
