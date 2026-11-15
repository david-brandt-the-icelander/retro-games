#!/usr/bin/env python3
"""Builds web/backseat-driver.html from ../events.gd (data) and src/*.js (engine)."""
import re, pathlib
here = pathlib.Path(__file__).parent
ev = (here.parent / "events.gd").read_text()
ev = re.sub(r"^extends .*\n", "", ev, flags=re.M)
ev = re.sub(r"^##", "//", ev, flags=re.M)
ev = re.sub(r"^const (\w+) := ", r"const \1 = ", ev, flags=re.M)
ev = ev.replace("\n]\n", "\n];\n")
src = "\n".join((here / "src" / f).read_text() for f in ["gfx.js", "hazards_a.js", "hazards_b.js", "game.js", "draw.js"])
html = (here / "src" / "template.html").read_text().replace("/*EVENTS*/", ev).replace("/*SRC*/", src)
(here / "backseat-driver.html").write_text(html)
print("wrote", here / "backseat-driver.html", len(html), "bytes")
