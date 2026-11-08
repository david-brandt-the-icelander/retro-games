# Lays every reference render out on one sheet: python3 contact_sheet.py docs/screens docs/contact-sheet.png
import glob, os, sys
from PIL import Image, ImageDraw
src, out = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(src, "*.png")))
cols, w = 4, 480
h = int(w * 900 / 1440)
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w + (cols + 1) * 16, rows * (h + 34) + 16), (11, 12, 15))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    im = Image.open(f).convert("RGB")
    im.thumbnail((w, h), Image.LANCZOS)
    x = 16 + (i % cols) * (w + 16); y = 16 + (i // cols) * (h + 34)
    sheet.paste(im, (x, y + 24))
    d.text((x, y + 6), os.path.basename(f)[:-4], fill=(217, 178, 107))
sheet.save(out, optimize=True)
