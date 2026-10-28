"""Replace every Image on an existing JED listing (Logo, zip and version untouched).

    python -I tools/jed-swap-images.py <state.json> <edit_url> <tag> <dry|save> <slide1.png> ... <slideN.png>

- Pass the slides in the order viewers should see them (max 8). The public JED slider
  shows the FIRST stored image LAST, so this script uploads the last slide first.
- <state.json> is a logged-in Playwright session from tools/jed-login.py.
- Always run dry first and read <tag>-edit.png. save aborts unless only the images changed.
- Check the live order afterwards with tools/jed-listing-order.py.
"""
import sys
from playwright.sync_api import sync_playwright

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
FD = ("()=>{const fd=new FormData(document.querySelector('#version').form); return {logo: fd.getAll('logo[]'),"
      " images: fd.getAll('images[]'), zip: fd.getAll('extension_file[]'), version: fd.get('version')}}")

if __name__ == '__main__':
    if len(sys.argv) < 6:
        sys.exit(__doc__)
    STATE, URL, TAG, MODE, SLIDES = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:]
    if len(SLIDES) > 8:
        sys.exit('JED allows at most 8 images')
    upload = SLIDES[-1:] + SLIDES[:-1]
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        ctx = b.new_context(viewport={'width': 1280, 'height': 1000}, user_agent=UA, storage_state=STATE)
        ctx.set_default_timeout(45000); p = ctx.new_page()
        p.on('dialog', lambda d: d.accept())
        p.goto(URL, wait_until='domcontentloaded'); p.wait_for_timeout(8000)
        if p.locator('#version').count() == 0:
            print('NOT ON EDIT FORM', p.url); sys.exit(2)
        before = p.evaluate(FD); print('before:', before)
        rows = p.locator('tr[id^="images_"]')
        print('image rows:', rows.count())
        for i in range(rows.count()):
            rows.nth(0).locator('button[id$="_delete"]').click(); p.wait_for_timeout(2500)
        uploader = p.locator('input[type=file]').nth(2)  # 0 = zip, 1 = logo, 2 = images
        for png in upload:
            uploader.set_input_files(png); p.wait_for_timeout(7000)
        p.wait_for_timeout(5000)
        after = p.evaluate(FD); print('after:', after)
        p.locator('form').filter(has=p.locator('#version')).first.screenshot(path=f'{TAG}-edit.png')
        ok = (len(after['images']) == len(upload) and not set(after['images']) & set(before['images'])
              and after['logo'] == before['logo'] and after['zip'] == before['zip'] and after['version'] == before['version'])
        print('clean swap:', ok)
        if MODE == 'save':
            if not ok:
                print('ABORT'); sys.exit(3)
            p.locator('button[type=submit]', has_text='Save').last.click()
            p.wait_for_load_state('domcontentloaded'); p.wait_for_timeout(9000)
            print('after save url:', p.url)
            print('messages:', [m.strip()[:200] for m in p.locator('.alert, #system-message-container').all_inner_texts() if m.strip()])
            p.screenshot(path=f'{TAG}-after-save.png')
        b.close()
