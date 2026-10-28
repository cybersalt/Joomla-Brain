"""Log in to the JED and save the Playwright session.

    python -I tools/jed-login.py <username> <password> <state_out.json>

Credentials live in the vault (09.accounts/joomla-extensions-directory.md for Cybersalt,
03.team/clients/php-web-design.md for PHP Web Design). Never commit them here.
"""
import sys
from playwright.sync_api import sync_playwright

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'

if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    user, password, out = sys.argv[1:4]
    with sync_playwright() as pw:
        b = pw.chromium.launch(); ctx = b.new_context(viewport={'width': 1280, 'height': 1000}, user_agent=UA); p = ctx.new_page()
        p.goto('https://extensions.joomla.org/users-login-form', wait_until='domcontentloaded'); p.wait_for_timeout(3000)
        p.fill('#username', user); p.fill('#password', password)
        p.locator('button[type=submit]', has_text='Log in').last.click()
        p.wait_for_load_state('domcontentloaded'); p.wait_for_timeout(4000)
        logged_in = p.locator('a', has_text='Log out').count() + p.locator('text=Logout').count() > 0
        print('after login url', p.url, '| logged in:', logged_in)
        ctx.storage_state(path=out)
        b.close()
        sys.exit(0 if logged_in else 1)
