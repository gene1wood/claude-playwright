# Docker sandbox template: Claude Code + Playwright (Chromium)
#
# Build (also handled by .github/workflows/build.yml on push):
#   docker build -t ghcr.io/<org>/claude-playwright:v1 --push .
#
# Use:
#   sbx run --template ghcr.io/<org>/claude-playwright:v1 claude

FROM docker/sandbox-templates:claude-code@sha256:868e3f5ef10579e06903d42e86448851ed59319ab8b9fba6dea2772c449bb2a6

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
    rm /tmp/package.json

# Smoke-test the bake: fail the build if the browser doesn't actually launch.
RUN node -e "require('playwright').chromium.launch().then(b => { console.log('playwright ok'); return b.close(); }).catch(e => { console.error(e); process.exit(1); })"

USER agent
