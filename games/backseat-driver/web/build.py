#!/usr/bin/env python3
"""Builds web/backseat-driver.html from web/src/*.js and the template."""
import pathlib
here = pathlib.Path(__file__).parent
files = ["audio.js", "gfx.js", "signs_a.js", "signs_b.js", "signs_c.js", "events_a.js", "events_b.js", "events_c.js", "events_d.js",
         "hazards_a.js", "hazards_b.js", "hazards_c.js", "game.js", "draw.js"]
src = "\n".join((here / "src" / f).read_text() for f in files)
html = (here / "src" / "template.html").read_text().replace("/*EVENTS*/\n", "").replace("/*SRC*/", src)
(here / "backseat-driver.html").write_text(html)
print("wrote", here / "backseat-driver.html", len(html), "bytes")
