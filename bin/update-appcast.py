#!/usr/bin/env python3
"""Insert a new <item> entry into appcast.xml, creating the file if needed.

Usage:
    update-appcast.py \\
        --appcast appcast.xml \\
        --version 0.2.4 \\
        --download-url https://github.com/.../CapNote-0.2.4.zip \\
        --length 1234567 \\
        --signature 'sparkle:edSignature="..."' \\
        --release-notes-url https://github.com/.../releases/tag/v0.2.4 \\
        --min-system-version 14.0
"""
from __future__ import annotations

import argparse
import datetime
import os
import re
from xml.etree import ElementTree as ET


SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)


EMPTY_TEMPLATE = """<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>CapNote</title>
        <link>https://github.com/lardissone/cap-note</link>
        <description>Quick notes to Capacities, from your menu bar.</description>
        <language>en</language>
    </channel>
</rss>
"""


def parse_signature(raw: str) -> tuple[str, str]:
    """Return (signature, length) from sign_update's stdout line.

    sign_update prints e.g.
        sparkle:edSignature="abc..." length="12345"
    """
    sig_match = re.search(r'sparkle:edSignature="([^"]+)"', raw)
    len_match = re.search(r'length="([^"]+)"', raw)
    if not sig_match:
        raise ValueError(f"No edSignature in: {raw!r}")
    return sig_match.group(1), len_match.group(1) if len_match else ""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--appcast", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--download-url", required=True)
    parser.add_argument("--length", required=True)
    parser.add_argument("--signature", required=True,
                        help="Either the raw 'sparkle:edSignature=...' line or just the signature value.")
    parser.add_argument("--release-notes-url")
    parser.add_argument("--min-system-version", default="14.0")
    args = parser.parse_args()

    # Load or create the appcast.
    if os.path.exists(args.appcast):
        with open(args.appcast, "r", encoding="utf-8") as fh:
            tree = ET.parse(fh)
    else:
        tree = ET.ElementTree(ET.fromstring(EMPTY_TEMPLATE))

    root = tree.getroot()
    channel = root.find("channel")
    if channel is None:
        raise SystemExit("Malformed appcast: no <channel> element.")

    # Bail out if the same version is already there.
    sparkle_version_attr = f"{{{SPARKLE_NS}}}version"
    for existing in channel.findall("item"):
        enc = existing.find("enclosure")
        if enc is not None and enc.attrib.get(sparkle_version_attr) == args.version:
            print(f"appcast already contains version {args.version}; nothing to do.")
            return

    # Parse signature: accept either raw line or just the value.
    if args.signature.startswith("sparkle:edSignature"):
        signature, _ = parse_signature(args.signature)
    else:
        signature = args.signature

    pub_date = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%a, %d %b %Y %H:%M:%S +0000"
    )

    item = ET.Element("item")
    title = ET.SubElement(item, "title")
    title.text = f"Version {args.version}"

    if args.release_notes_url:
        notes_link = ET.SubElement(item, f"{{{SPARKLE_NS}}}releaseNotesLink")
        notes_link.text = args.release_notes_url

    pub = ET.SubElement(item, "pubDate")
    pub.text = pub_date

    min_sys = ET.SubElement(item, f"{{{SPARKLE_NS}}}minimumSystemVersion")
    min_sys.text = args.min_system_version

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", args.download_url)
    enclosure.set(sparkle_version_attr, args.version)
    enclosure.set(f"{{{SPARKLE_NS}}}shortVersionString", args.version)
    enclosure.set("length", args.length)
    enclosure.set("type", "application/octet-stream")
    enclosure.set(f"{{{SPARKLE_NS}}}edSignature", signature)

    # Insert at the top of the channel's <item> list.
    insert_index = 0
    for idx, child in enumerate(channel):
        if child.tag == "item":
            insert_index = idx
            break
    else:
        insert_index = len(channel)
    channel.insert(insert_index, item)

    ET.indent(tree, space="    ")
    tree.write(args.appcast, encoding="utf-8", xml_declaration=True)
    # ElementTree omits "standalone" by default — restore it.
    with open(args.appcast, "r+", encoding="utf-8") as fh:
        body = fh.read()
        body = body.replace(
            "<?xml version='1.0' encoding='utf-8'?>",
            '<?xml version="1.0" encoding="utf-8" standalone="yes"?>',
            1,
        )
        fh.seek(0)
        fh.write(body)
        fh.truncate()
    print(f"appcast updated with version {args.version}")


if __name__ == "__main__":
    main()
