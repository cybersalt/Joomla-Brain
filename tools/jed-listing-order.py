"""Print the slideshow order of a public JED listing (Logo first, then the Images as shown).

    python -I tools/jed-listing-order.py https://extensions.joomla.org/extension/<alias>/

Compare the file ids with the edit form's rows: the slider shows the first stored image last,
which tools/jed-swap-images.py already compensates for.
"""
import sys
from playwright.sync_api import sync_playwright

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'

if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    with sync_playwright() as pw:
        b = pw.chromium.launch(); p = b.new_page(user_agent=UA, viewport={'width': 1400, 'height': 1000})
        p.goto(sys.argv[1], wait_until='domcontentloaded'); p.wait_for_timeout(8000)
        srcs = p.evaluate("""() => [...document.querySelectorAll('.slider-full-images img')].map(i => i.src.split('/').pop())""")
        for n, s in enumerate(srcs):
            print('logo ' if n == 0 else f'slide {n}', s)
        print('last updated:', p.evaluate("""() => { const t = document.body.innerText.match(/Last updated:\\s*\\n?\\s*([^\\n]+)/); return t ? t[1] : '?'; }"""))
        b.close()
