# Docker sandbox template: Claude Code + Playwright (Chromium)
#
# Build (also handled by .github/workflows/build.yml on push):
#   docker build -t ghcr.io/<org>/claude-playwright:v1 --push .
#
# Use:
#   sbx run --template ghcr.io/<org>/claude-playwright:v1 claude

FROM docker/sandbox-templates:claude-code@sha256:30ec2b1bb76e3993aff912c553a5c249ad95b595249a32fde7158eafb71bda25

# Fixed, user-independent cache path: any project's local `playwright`
# package finds this preinstalled binary regardless of whose home
# directory it runs from, as long as its own Playwright version is
# compatible with the pinned version installed below.
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright

# npm's global prefix (fixed by the base image's npm config, see `npm config
# get prefix`) isn't on Node's default module search path — only npx/npm add
# it. Without this, `node -e "require('playwright')"` fails to find the
# globally-installed package below even though it's right there, which looks
# identical to Chromium itself being missing.
ENV NODE_PATH=/usr/local/share/npm-global/lib/node_modules

# Installing OS-level shared-lib deps (fonts, libnss3, libgbm, etc.) needs
# apt/root, and downloading the browser binary needs network access that
# is only unrestricted at build time (before the runtime egress policy
# applies) — so both must happen here rather than in a running sandbox.
USER root

# The version pin lives in package.json (not an ARG) so Dependabot's npm
# ecosystem can see and bump it — Dependabot only reads FROM lines out of
# Dockerfiles, not versions embedded in RUN commands.
COPY package.json /tmp/package.json
RUN PLAYWRIGHT_VERSION=$(node -p "require('/tmp/package.json').dependencies.playwright") && \
    npm install -g playwright@${PLAYWRIGHT_VERSION} && \
    npx playwright install --with-deps chromium && \
    chmod -R a+rX /opt/ms-playwright && \
    pip install --break-system-packages playwright==${PLAYWRIGHT_VERSION} && \
    rm /tmp/package.json

# Put the browser on PATH so `which chromium` finds it, without Claude
# needing to know Playwright's cache layout. `find` rather than a hardcoded
# glob, so a changed directory layout in a future Playwright release fails
# the build instead of leaving a dead link.
#
# /usr/local/bin/chromium is a wrapper, not a bare symlink: run directly as a
# container user, Chromium needs --no-sandbox, and it needs --headless to start
# without a display. Playwright's own launches use the real binary and are
# unaffected. The alias names are what Lighthouse, chrome-launcher, etc. probe.
RUN CHROME=$(find /opt/ms-playwright -path '*/chrome-linux*/chrome' -type f | head -n1) && \
    test -n "$CHROME" && \
    printf '#!/bin/sh\nexec "%s" --headless=new --no-sandbox "$@"\n' "$CHROME" > /usr/local/bin/chromium && \
    chmod 755 /usr/local/bin/chromium && \
    ln -s chromium /usr/local/bin/chromium-browser && \
    ln -s chromium /usr/local/bin/google-chrome && \
    chromium --version

# For tools that read the browser location from the environment.
ENV CHROME_BIN=/usr/local/bin/chromium \
    CHROME_PATH=/usr/local/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/chromium

# Tell Claude the browser exists. This goes in Claude Code's managed-policy
# location, not ~/.claude/CLAUDE.md: the sandbox rewrites files under
# /home/agent/.claude when it starts, so anything baked in there is lost.
COPY claude-code-memory.md /etc/claude-code/CLAUDE.md
RUN chmod 644 /etc/claude-code/CLAUDE.md

# Smoke-test the bake: fail the build if the browser doesn't actually launch
# from either Node or Python.
RUN node -e "require('playwright').chromium.launch().then(b => { console.log('playwright ok'); return b.close(); }).catch(e => { console.error(e); process.exit(1); })" && \
    python3 -c "from playwright.sync_api import sync_playwright as p; c = p().start(); b = c.chromium.launch(); print('playwright python ok'); b.close(); c.stop()"

USER agent
