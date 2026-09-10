# Docker sandbox template: Claude Code + Playwright (Chromium)
#
# Build (also handled by .github/workflows/build.yml on push):
#   docker build -t ghcr.io/<org>/claude-playwright:v1 --push .
#
# Use:
#   sbx run --template ghcr.io/<org>/claude-playwright:v1 claude

FROM docker/sandbox-templates:claude-code@sha256:68fdd3172a6f64a7f14ffddfb58b0a36fbbb5d849b73daa5b11f872cfda33467

# Fixed, user-independent cache path: any project's local `playwright`
# package finds this preinstalled binary regardless of whose home
# directory it runs from, as long as its own Playwright version is
# compatible with the pinned version installed below.
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright

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
# NODE_PATH must point at the global node_modules dir here because `playwright`
# was installed with `npm install -g`, and plain `node -e` (run from
# /home/agent/workspace) doesn't search the global install location by default.
RUN NODE_PATH="$(npm root -g)" node -e "require('playwright').chromium.launch().then(b => { console.log('playwright ok'); return b.close(); }).catch(e => { console.error(e); process.exit(1); })"

USER agent
