"""Builds the website's changelog page from CHANGELOG.md and CHANGELOG.es.md.

    python3 -I scripts/lib/changelog_page.py

Every "## x.y.z — YYYY-MM-DD" section becomes one release on
website/novedades/index.html (between the releases:start/end markers), in
English and Spanish; a version missing from CHANGELOG.es.md falls back to
English. It also writes the latest version into every [data-latest] element
of the site, so the island in the menu bar always announces the current release.
"""
import datetime
import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
PAGE = ROOT / "website" / "novedades" / "index.html"
LATEST_PAGES = [ROOT / "website" / "index.html", PAGE]
GITHUB = "https://github.com/Kyros-Solutions-RD/isla/releases/tag/v"

IMAGE = re.compile(r"^!\[([^\]]*)\]\((?:website/)?([^)\s]+)\)\s*$")
HEADING = re.compile(r"^##\s+(\d+\.\d+\.\d+)(?:\s*[—–-]\s*(\d{4}-\d{2}-\d{2}))?\s*$")
MONTHS_ES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
             "septiembre", "octubre", "noviembre", "diciembre"]
MONTHS_EN = ["January", "February", "March", "April", "May", "June", "July", "August",
             "September", "October", "November", "December"]


def parse(path):
    """Returns {version: {"date", "intro", "items", "images"}} in file order."""
    releases = {}
    current = None
    if not path.exists():
        return releases
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        match = HEADING.match(line)
        if match:
            version, date = match.groups()
            current = releases.setdefault(version, {
                "date": datetime.date.fromisoformat(date) if date else None, "intro": [], "items": [], "images": []})
            continue
        if current is None or not line.strip():
            continue
        image = IMAGE.match(line.strip())
        if image:
            current["images"].append(image.groups())
        elif line.startswith(("- ", "* ")):
            current["items"].append(line[2:].strip())
        elif line.startswith("  ") and current["items"]:
            current["items"][-1] += " " + line.strip()
        elif not line.startswith("#"):
            current["intro"].append(line.strip())
    return releases


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    return re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", r'<a href="\2">\1</a>', text)


def date_text(date, lang):
    if date is None:
        return ""
    if lang == "es":
        return f"{date.day} de {MONTHS_ES[date.month - 1]} de {date.year}"
    return f"{MONTHS_EN[date.month - 1]} {date.day}, {date.year}"


def notes(release, lang, indent):
    pad = " " * indent
    out = []
    for paragraph in release["intro"]:
        out.append(f'{pad}<p class="release-intro">{inline(paragraph)}</p>')
    for alt, src in release["images"]:
        out.append(f'{pad}<figure class="release-shot"><img src="../{html.escape(src)}" alt="{html.escape(alt)}" loading="lazy"></figure>')
    if release["items"]:
        out.append(f"{pad}<ul>")
        out.extend(f"{pad}  <li>{inline(item)}</li>" for item in release["items"])
        out.append(f"{pad}</ul>")
    return "\n".join(out)


def render(english, spanish):
    blocks = []
    for index, (version, release) in enumerate(english.items()):
        es = spanish.get(version) or release
        date = release["date"] or es["date"]
        badge = ('\n          <span class="release-badge"><span class="i18n-es">Versión actual</span>'
                 '<span class="i18n-en" lang="en">Current version</span></span>') if index == 0 else ""
        iso = f' datetime="{date.isoformat()}"' if date else ""
        blocks.append(f'''      <article class="release" id="v{version}">
        <header class="release-head">
          <h3 class="release-version"><a href="#v{version}">{version}</a></h3>
          <time class="release-date"{iso}><span class="i18n-es">{date_text(date, "es")}</span><span class="i18n-en" lang="en">{date_text(date, "en")}</span></time>{badge}
        </header>
        <div class="release-body">
          <div class="i18n-es">
{notes(es, "es", 12)}
          </div>
          <div class="i18n-en" lang="en">
{notes(release, "en", 12)}
          </div>
          <p class="release-links">
            <a href="../downloads/Isla-{version}.dmg"><span class="i18n-es">Descargar {version}</span><span class="i18n-en" lang="en">Download {version}</span></a>
            <a href="{GITHUB}{version}"><span class="i18n-es">En GitHub</span><span class="i18n-en" lang="en">On GitHub</span></a>
          </p>
        </div>
      </article>''')
    return "\n".join(blocks)


def main():
    english = parse(ROOT / "CHANGELOG.md")
    if not english:
        sys.exit("changelog_page: no releases found in CHANGELOG.md")
    spanish = parse(ROOT / "CHANGELOG.es.md")

    page = PAGE.read_text(encoding="utf-8")
    start = page.index("<!-- releases:start")
    start = page.index("-->", start) + 3
    end = page.index("      <!-- releases:end -->")
    page = page[:start] + "\n" + render(english, spanish) + "\n" + page[end:]
    PAGE.write_text(page, encoding="utf-8")

    latest = next(iter(english))
    for path in LATEST_PAGES:
        text = path.read_text(encoding="utf-8")
        updated = re.sub(r"(<span data-latest>)[^<]*(</span>)", rf"\g<1>{latest}\g<2>", text)
        path.write_text(updated, encoding="utf-8")

    missing = [v for v in english if v not in spanish]
    note = f" (no Spanish notes for {', '.join(missing)}: English used)" if missing else ""
    print(f"changelog: {len(english)} releases, latest {latest}{note}")


if __name__ == "__main__":
    main()
