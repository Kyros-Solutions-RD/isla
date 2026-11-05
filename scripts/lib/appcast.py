#!/usr/bin/env python3
"""Adds a release to website/updates/appcast.xml for Sparkle.

usage: appcast.py <appcast.xml> <version> <build> <dmg url> <signature> <length> <notes.md>
"""
import html
import re
import sys
from email.utils import formatdate

appcast, version, build, url, signature, length, notes_path = sys.argv[1:8]

notes = open(notes_path, encoding="utf-8").read().strip()
items = [line[2:].strip() for line in notes.splitlines() if line.startswith("- ")]
paragraphs = [line.strip() for line in notes.splitlines() if line.strip() and not line.startswith(("- ", "#"))]
body = "".join(f"<p>{html.escape(p)}</p>" for p in paragraphs)
if items:
    body += "<ul>" + "".join(f"<li>{html.escape(item)}</li>" for item in items) + "</ul>"

item = f"""    <item>
      <title>Isla {html.escape(version)}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{html.escape(build)}</sparkle:version>
      <sparkle:shortVersionString>{html.escape(version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <description><![CDATA[{body}]]></description>
      <enclosure url="{html.escape(url)}" sparkle:edSignature="{html.escape(signature)}" length="{html.escape(length)}" type="application/octet-stream"/>
    </item>
"""

xml = open(appcast, encoding="utf-8").read()
# Replace an existing entry for the same version so a release can be re-run safely.
xml = re.sub(r"\s*<item>\s*<title>Isla " + re.escape(version) + r"</title>.*?</item>\n?", "\n", xml, flags=re.S)
xml = xml.replace("    <language>es</language>\n", "    <language>es</language>\n" + item, 1)
open(appcast, "w", encoding="utf-8").write(xml)
print(f"appcast: added Isla {version} ({build})")
