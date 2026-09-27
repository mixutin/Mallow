# SPDX-License-Identifier: 0BSD
"""Check actual generated English/Finnish output, not a claimed deployment."""
from pathlib import Path
import re

root = Path('site')
english = (root / 'index.html').read_text(encoding='utf-8')
finnish = (root / 'fi/index.html').read_text(encoding='utf-8')
assert re.search(r'<html[^>]+lang="en"', english)
assert re.search(r'<html[^>]+lang="fi"', finnish)
assert 'mallow-page-loader' in english and 'mallow-page-loader' in finnish
assert 'Ladataan sivua' in finnish
assert 'prefers-reduced-motion' in (root / 'stylesheets/loader.css').read_text()
for slug in ['getting-started', 'development-preview', 'how-it-works', 'roadmap', 'faq', 'security', 'contributing']:
    page = root / 'fi' / slug / 'index.html'
    assert page.is_file(), page
    assert re.search(r'<html[^>]+lang="fi"', page.read_text(encoding='utf-8')), page
assert (root / 'fi/search/search_index.json').is_file()
assert (root / 'assets/logo.svg').is_file()
print('English/Finnish pages, language metadata, search, shared logo and loader verified.')
