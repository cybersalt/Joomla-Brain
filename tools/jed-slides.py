"""Build JED listing feature slides: 1200x525, feature text on the left, a cropped,
readable screenshot on the right (the same frame as tools/jed-banner.py).

    python -I tools/jed-slides.py <config.json>

Config:
{
  "product": "CS MCP for J",            # small label next to the mini logo
  "logo": "logo.png|logo.svg",
  "out_dir": "slides",                   # relative to the config file
  "slides": [
    {"name": "mcp-slide-1-connect", "headline": "Connect any AI app",
     "body": "Two or three short sentences about the feature.",
     "shot": "screenshot.png", "crop": [x0, y0, x1, y1]}
  ]
}

- crop is in source pixels; keep its aspect near 700:455 (1.54). The script prints the
  scale: aim for 0.7-1.2 so the screenshot text stays readable.
- Up to 8 slides (the JED Images limit). Use tools/jed-swap-images.py to upload them.
- Needs Pillow (and PyMuPDF for SVG logos). Fonts: Roboto from C:/Windows/Fonts.
"""
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1200, 525
FONTS = 'C:/Windows/Fonts/'
NAVY, BODY, MUTED, ORANGE = (24, 34, 66), (62, 72, 94), (110, 118, 138), (255, 152, 0)


def load_logo(path):
    if path.lower().endswith('.svg'):
        import fitz
        page = fitz.open(path)[0]
        zoom = 1200 / page.rect.width
        pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=True)
        return Image.frombytes('RGBA', (pix.width, pix.height), pix.samples)
    return Image.open(path).convert('RGBA')


def mini_logo(path, size):
    im = load_logo(path)
    alpha_box = im.getchannel('A').getbbox()
    ink_box = Image.eval(im.convert('L'), lambda v: 255 - v).getbbox()
    box = alpha_box if alpha_box and alpha_box != (0, 0) + im.size else ink_box
    im = im.crop(box)
    im.thumbnail((size, size), Image.LANCZOS)
    return im


def wrap(draw, text, fnt, width):
    lines, line = [], ''
    for word in text.split():
        test = (line + ' ' + word).strip()
        if draw.textlength(test, font=fnt) <= width:
            line = test
        else:
            lines.append(line); line = word
    return lines + [line]


def frame(canvas, shot):
    x, y = 465, (H - shot.height) // 2
    shadow = Image.new('RGBA', (shot.width + 40, shot.height + 40), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((20, 24, shot.width + 20, shot.height + 24), 10, fill=(20, 30, 60, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(9))
    canvas.paste(shadow, (x - 20, y - 20), shadow)
    mask = Image.new('L', shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height - 1), 10, fill=255)
    canvas.paste(shot, (x, y), mask)
    ImageDraw.Draw(canvas).rounded_rectangle((x, y, x + shot.width - 1, y + shot.height - 1), 10,
                                             outline=(200, 208, 222), width=1)


def build(slide, product, logo, out_dir, base):
    canvas = Image.new('RGB', (W, H), (255, 255, 255))
    canvas.paste(Image.new('RGB', (W - 430, H), (238, 242, 250)), (430, 0))
    d = ImageDraw.Draw(canvas)

    box = slide['crop']
    shot = Image.open(os.path.join(base, slide['shot'])).convert('RGB').crop(box).resize((700, 455), Image.LANCZOS)
    frame(canvas, shot)

    left, width = 44, 350
    f_kick = ImageFont.truetype(FONTS + 'Roboto-Medium.ttf', 17)
    f_head = ImageFont.truetype(FONTS + 'Roboto-Bold.ttf', 33)
    f_body = ImageFont.truetype(FONTS + 'Roboto-Regular.ttf', 19)
    head = wrap(d, slide['headline'], f_head, width)
    text = wrap(d, slide['body'], f_body, width)
    kick_h, head_lh, body_lh = 40, 40, 29
    total = kick_h + 22 + len(head) * head_lh + 18 + 4 + 20 + len(text) * body_lh
    if total > H - 40:
        print('WARNING: text too long for', slide['name'])
    y = (H - total) // 2

    canvas.paste(logo, (left, y + (kick_h - logo.height) // 2), logo)
    d.text((left + logo.width + 12, y + kick_h // 2), product, font=f_kick, fill=MUTED, anchor='lm')
    y += kick_h + 22
    for line in head:
        d.text((left, y), line, font=f_head, fill=NAVY); y += head_lh
    y += 18
    d.rounded_rectangle((left, y, left + 56, y + 4), 2, fill=ORANGE)
    y += 4 + 20
    for line in text:
        d.text((left, y), line, font=f_body, fill=BODY); y += body_lh

    path = os.path.join(out_dir, slide['name'] + '.png')
    canvas.save(path, optimize=True)
    w, h = box[2] - box[0], box[3] - box[1]
    print(path, 'scale %.2f' % (700 / w), 'aspect %.3f' % (w / h))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    cfg_path = os.path.abspath(sys.argv[1])
    base = os.path.dirname(cfg_path)
    cfg = json.load(open(cfg_path, encoding='utf-8'))
    if len(cfg['slides']) > 8:
        sys.exit('JED allows at most 8 images')
    out_dir = os.path.join(base, cfg.get('out_dir', 'slides'))
    os.makedirs(out_dir, exist_ok=True)
    logo = mini_logo(os.path.join(base, cfg['logo']), 40)
    for s in cfg['slides']:
        build(s, cfg['product'], logo, out_dir, base)
