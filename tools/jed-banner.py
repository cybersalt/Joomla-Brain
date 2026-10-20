"""Build the JED listing "logo" image Cybersalt uses: a 1200x525 banner with the
extension logo on the left and a product screenshot on the right.

    python -I tools/jed-banner.py <logo.png|logo.svg> <screenshot.png> <out.png> [--top N]

- The logo can be a PNG or an SVG (SVGs are rendered with PyMuPDF).
- The screenshot is scaled to 700 px wide and cropped from the top (or from --top N px
  after scaling) to fit; use an anonymized screenshot that shows the extension working.
- Needs Pillow (and PyMuPDF for SVG logos).
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

W, H = 1200, 525


def load_logo(path):
    if path.lower().endswith('.svg'):
        import fitz
        page = fitz.open(path)[0]
        zoom = 1200 / page.rect.width
        pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=True)
        return Image.frombytes('RGBA', (pix.width, pix.height), pix.samples)
    return Image.open(path).convert('RGBA')


def build(logo_path, shot_path, out_path, top=0):
    canvas = Image.new('RGB', (W, H), (255, 255, 255))
    canvas.paste(Image.new('RGB', (W - 430, H), (238, 242, 250)), (430, 0))

    logo = load_logo(logo_path)
    logo.thumbnail((330, 330), Image.LANCZOS)
    canvas.paste(logo, ((430 - logo.width) // 2, (H - logo.height) // 2), logo)

    shot = Image.open(shot_path).convert('RGB')
    box_w, box_h = 700, 455
    shot = shot.resize((box_w, round(shot.height * box_w / shot.width)), Image.LANCZOS)
    shot = shot.crop((0, top, box_w, top + min(box_h, shot.height - top)))
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
    canvas.save(out_path, optimize=True)
    print(out_path, canvas.size)


if __name__ == '__main__':
    args = sys.argv[1:]
    top = 0
    if '--top' in args:
        i = args.index('--top'); top = int(args[i + 1]); del args[i:i + 2]
    if len(args) != 3:
        sys.exit(__doc__)
    build(args[0], args[1], args[2], top)
