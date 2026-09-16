# dsh-figma-bridge

Registers the Figma MCP server (`figma-console-mcp`, Local Mode) in a dsh web
profile. Before this package existed, that meant hand-copying a
`cordis.patch.yml` into `~/.dsh/profiles/web/` and merging future version bumps
in by hand. This is the same config, installed the way
[`dsh-team-updater`](../team-updater) already is: an ordinary out-of-tree
profile plugin.

It carries no runtime logic of its own — `cordis.patch.yml`'s row names the
**built-in** `@deepseek-ai/dsh-mcp-client`, not this package, so dsh never has
to import it. Its only jobs are: exist as an installable package whose
`dsh.bundle.patch` gets composed into the profile at boot, and ship `lib/pin.js`
so a version bump here reaches an already-installed profile.

The actual bridge — a plugin imported into Figma Desktop, talking to the MCP
server over a local WebSocket — is external and stays manual. See `SETUP.md`
Part 6, Step 5.

## Install

`setup.bat` / `setup.sh` and `update.bat` / `update.sh` in the repo root do this
for you once the `web` profile exists (same `plugins/team-updater` bundle-patch
mechanism — see that package's README for how `dsh plugin add` resolves it).
By hand, from the repo root in cmd:

```
dsh plugin --profile web add "file:%CD%\plugins\figma-bridge"
```

macOS/Linux:

```bash
dsh plugin --profile web add "file:$PWD/plugins/figma-bridge"
```

If that path contains a space, use `"""file:%CD%\plugins\figma-bridge"""`
instead — see `plugins/team-updater/README.md`'s Install section for why. A
path containing `(` or `)` cannot be used at all — pnpm rejects it with
"Mismatch parenthesis".

Uninstall: `dsh plugin --profile web remove dsh-figma-bridge`, then restart.

## Version pinning

The server version is pinned in this package's own `cordis.patch.yml`, not
`@latest` — same reasoning as `dsh-team-updater`'s `DSH_VERSION` pin: with
`@latest`, every machine would run whatever was published last, the moment it
was published.

`dsh plugin add` installs a *copy* of this package into the profile's
`node_modules`, not a link, so a version bump here does not reach an
already-added profile by itself. `lib/pin.js` closes that gap:

```
node plugins/figma-bridge/lib/pin.js           rewrite the installed copy if it differs
node plugins/figma-bridge/lib/pin.js --check   only report
```

`update.sh` / `update.bat` run it after every `dsh plugin add`; `verify.sh` /
`verify.bat` run it with `--check`.

## Migrating a hand-copied install

Machines set up before this package existed have the Figma MCP row pasted
directly into their profile's own `cordis.patch.yml`. Installing this plugin
on top would leave two `serverName: figma` rows. `lib/migrate.js` removes the
old one first:

```
node plugins/figma-bridge/lib/migrate.js
```

It only touches a block that holds nothing but the legacy `id: mcp-figma`
entry, and backs up the file to `cordis.patch.yml.bak` before rewriting it. If
the entry was hand-merged into a block with other config, it leaves the file
alone and prints where to remove it by hand. Every outcome exits 0 — this must
never fail a `setup`/`update` run. `setup.sh`/`update.sh` (and the `.bat`
versions) run it before `dsh plugin add`, so the legacy row is gone before the
plugin-managed one lands.

## See also

`templates/roles/figma.md` in the repo root — agent-facing rules about which
Figma tools are safe to call in Local Mode (e.g. never call
`figma_capture_screenshot`/`figma_take_screenshot`). It's a separate,
plugin-agnostic mechanism (`agents.sh --role=`), not part of this package.

## Verified

`node tests/check.mjs` — the pinned version matches `SETUP.md`'s embedded
example, `package.json`'s `dsh.bundle.patch` points at a real file, `lib/pin.js`
rewrites and reports correctly against a sandboxed profile, and `lib/migrate.js`
handles the legacy-single-entry, already-migrated, and merged-block cases.
