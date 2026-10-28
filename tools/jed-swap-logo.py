"""Replace the Logo (the 1200x525 banner from tools/jed-banner.py) on an existing JED listing.
Images, zip and version stay untouched.

    python -I tools/jed-swap-logo.py <state.json> <edit_url> <banner.png> <tag> <dry|save>

<state.json> is a logged-in session from tools/jed-login.py. save aborts unless only the Logo changed.
"""
import sys
from playwright.sync_api import sync_playwright

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
FD = ("()=>{const fd=new FormData(document.querySelector('#version').form); return {logo: fd.getAll('logo[]'),"
      " images: fd.getAll('images[]'), zip: fd.getAll('extension_file[]'), version: fd.get('version')}}")

if __name__ == '__main__':
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    STATE, URL, PNG, TAG, MODE = sys.argv[1:6]
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        ctx = b.new_context(viewport={'width': 1280, 'height': 1000}, user_agent=UA, storage_state=STATE)
        ctx.set_default_timeout(45000); p = ctx.new_page()
        p.on('dialog', lambda d: d.accept())
        p.goto(URL, wait_until='domcontentloaded'); p.wait_for_timeout(8000)
        if p.locator('#version').count() == 0:
            print('NOT ON EDIT FORM', p.url); sys.exit(2)
        before = p.evaluate(FD); print('before:', before)
        rows = p.locator('tr[id^="logo_"]')
        print('logo rows:', rows.count())
        for i in range(rows.count()):
            rows.nth(0).locator('button[id$="_delete"]').click(); p.wait_for_timeout(2500)
        p.locator('input[type=file]').nth(1).set_input_files(PNG); p.wait_for_timeout(9000)  # 0 = zip, 1 = logo, 2 = images
        after = p.evaluate(FD); print('after:', after)
        p.locator('form').filter(has=p.locator('#version')).first.screenshot(path=f'{TAG}-logo-edit.png')
        ok = (len(after['logo']) == 1 and after['logo'] != before['logo'] and after['images'] == before['images']
              and after['zip'] == before['zip'] and after['version'] == before['version'])
        print('clean swap:', ok)
        if MODE == 'save':
            if not ok:
                print('ABORT'); sys.exit(3)
            p.locator('button[type=submit]', has_text='Save').last.click()
            p.wait_for_load_state('domcontentloaded'); p.wait_for_timeout(9000)
            print('after save url:', p.url)
            p.screenshot(path=f'{TAG}-logo-after-save.png')
        b.close()
