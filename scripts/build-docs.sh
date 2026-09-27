#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# One Pages artifact, two independently localized sites; no new localization plugin dependency.
mkdocs build --strict --site-dir site
mkdocs build --strict --config-file mkdocs.fi.yml --site-dir site/fi
python3 scripts/check-site.py
