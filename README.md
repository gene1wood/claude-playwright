# claude-playwright

A [Docker sandbox template](https://docs.docker.com/ai/sandboxes/customize/templates/)
that extends `docker/sandbox-templates:claude-code` with Playwright and a
preinstalled Chromium browser, so Claude Code has browser access inside the
sandbox without installing anything at session start.

## What it does

- Installs a pinned version of the `playwright` npm package globally.
- Installs Chromium and its OS-level shared library dependencies
  (`playwright install --with-deps chromium`) at image build time, since that
  needs `apt`/root and unrestricted network access — neither of which is
  available inside a running sandbox.
- Caches the browser binary at a fixed path (`/opt/ms-playwright`, readable
  by any user) instead of a user home directory, so it's found regardless of
  which user a project's local `playwright` package runs as.
- Smoke-tests that Chromium actually launches as part of the build, so a
  broken image fails CI instead of shipping silently.

## Build and publish

Handled automatically by [`.github/workflows/build.yml`](.github/workflows/build.yml)
on push to `main` (tag `latest`), on version tags like `v1.0.0` (tag
`1.0.0`), and on other branches (tag `<branch>`). Images publish to
`ghcr.io/<org>/claude-playwright`.

To build and push manually instead:

```bash
docker build -t ghcr.io/<org>/claude-playwright:v1 --push .
```

## Use

```bash
sbx run --template ghcr.io/<org>/claude-playwright:v1 claude
```

## Updating the Chromium version

The Playwright version is pinned in [`package.json`](package.json), which
the `Dockerfile` reads at build time — this keeps the pin somewhere
[Dependabot](.github/dependabot.yml)'s `npm` ecosystem can see and bump
automatically, since Dependabot can't see versions embedded in `RUN`
commands. To bump manually instead, edit the version in `package.json` and
rebuild. If a project you're using this sandbox for pins a materially
different Playwright version in its own `package.json`, that project's
`playwright` may try to download a different, incompatible browser revision
at runtime and hit the sandbox's egress policy — keep this pin reasonably
current, or aligned with the versions your projects commonly use.

## Updating the base image

The `FROM` line pins `docker/sandbox-templates:claude-code` to a digest
rather than floating on a tag, so builds are reproducible and upstream
changes don't silently roll in. Dependabot's `docker` ecosystem checks
weekly for a new digest and, when one is published, opens a PR bumping the
pin — merging it (or letting CI build it) picks up the update. Actions
pinned by SHA in `build.yml` are kept current the same way.
