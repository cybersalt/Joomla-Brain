"""Set the Video on an existing JED listing. Logo, images, zip and version stay untouched.

    python -I tools/jed-set-video.py <state.json> <edit_url> <youtube_id> <tag> <dry|save>

The listing has ONE Video field (AllVideos syntax, {youtube}ID{/youtube}). JED shows it as the
slide right after the Logo, before every image. <state.json> is a logged-in session from
tools/jed-login.py. save aborts unless only the video changed.
"""
import sys
from playwright.sync_api import sync_playwright

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
FD = ("()=>{const fd=new FormData(document.querySelector('#version').form); return {logo: fd.getAll('logo[]'),"
      " images: fd.getAll('images[]'), zip: fd.getAll('extension_file[]'), version: fd.get('version'), video: fd.get('video')}}")

if __name__ == '__main__':
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    STATE, URL, YT, TAG, MODE = sys.argv[1:6]
    want = '{youtube}%s{/youtube}' % YT
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        ctx = b.new_context(viewport={'width': 1280, 'height': 1000}, user_agent=UA, storage_state=STATE)
        ctx.set_default_timeout(45000); p = ctx.new_page()
        p.on('dialog', lambda d: d.accept())
        p.goto(URL, wait_until='domcontentloaded'); p.wait_for_timeout(8000)
        if p.locator('#version').count() == 0:
            print('NOT ON EDIT FORM', p.url); sys.exit(2)
        before = p.evaluate(FD); print('before:', before)
        p.locator('#video').fill(want)
        after = p.evaluate(FD); print('after:', after)
        p.locator('#video').scroll_into_view_if_needed(); p.screenshot(path=f'{TAG}-video-edit.png')
        ok = (after['video'] == want and all(after[k] == before[k] for k in ('logo', 'images', 'zip', 'version')))
        print('clean change:', ok)
        if MODE == 'save':
            if not ok:
                print('ABORT'); sys.exit(3)
            p.locator('button[type=submit]', has_text='Save').last.click()
            p.wait_for_load_state('domcontentloaded'); p.wait_for_timeout(9000)
            print('after save url:', p.url)
            p.screenshot(path=f'{TAG}-video-after-save.png')
        b.close()
