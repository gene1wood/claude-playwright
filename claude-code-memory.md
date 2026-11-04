# Browser available in this sandbox

A Chromium browser is preinstalled. Don't try to install one.

- CLI: `chromium` (headless, no-sandbox already set), e.g.
  `chromium --screenshot=/tmp/out.png https://example.com`
- Node: `require('playwright')` works. Use CommonJS only: ES module
  `import('playwright')` fails with ERR_MODULE_NOT_FOUND because ES modules
  ignore NODE_PATH.
- Python: `from playwright.sync_api import sync_playwright` works with the
  system `python3`, not a project virtualenv.
- Playwright finds the browser via PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright.
  Don't run `playwright install`; there is no network access for it at runtime.
- Don't add `playwright` to a project's dependencies; its version could expect
  a different browser build than the one installed here.
