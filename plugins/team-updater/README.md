# dsh-team-updater

An update button **inside the dsh web GUI**. It puts one row in *Settings →
General* that compares the running `@deepseek-ai/dsh` against the npm registry
and, on click, installs the newer version and brings dsh back up.

No fork, no patched frontend bundle, no hand-edited files inside the dsh
installation: it is an ordinary out-of-tree profile plugin.

```
Settings → General
┌──────────────────────────────────────────────────────────────────────┐
│ dsh updates                        0.1.2-rc.1 → 0.1.5-rc.1 (latest)  │
│                                    [ Update & restart ] [ Check again]│
└──────────────────────────────────────────────────────────────────────┘
```

## Install

`setup.bat` / `setup.sh` and `update.bat` / `update.sh` in the repo root do this
for you once the `web` profile exists. By hand, from the repo root:

```powershell
dsh plugin --profile web add file:%CD%\plugins\team-updater
```

`dsh plugin` forwards to pnpm inside `$DSH_HOME/profiles/web`, and because this
package declares `dsh.bundle.patch` it is appended to `dsh.profile.bundles`
automatically. Restart dsh (`dsh web`) and open Settings → General.

For a team rollout it travels with this repo: a `git pull` updates the plugin
source, and the install spec is a path inside the checkout, so nothing has to be
published. To use a registry instead, change the spec
(`dsh plugin --profile web add @your-scope/dsh-team-updater`).

Uninstall: `dsh plugin --profile web remove dsh-team-updater`, then restart.

## How an update works

The button never replaces files under a running process. `npm install -g` over
a live dsh install fails on Windows because the process keeps native addons
(`node-pty`, `koffi`, `sharp`) mapped, and Windows refuses to overwrite a
mapped DLL. So `POST /team-updater/apply` only *stages* the work:

1. Host half spawns a detached runner (`lib/update-runner.mjs`) with
   `pid`, target version, cwd, log path and the original `dsh` arguments.
2. With `quit: true` the runner asks dsh to quit (`taskkill` without `/f`
   first, then `/f`; `SIGTERM` on POSIX).
3. Runner waits for the pid to disappear, pauses 1.5 s for Windows to release
   the mappings, then runs `npm install -g @deepseek-ai/dsh@<version>`.
4. It verifies the installed version through `npm root -g`, then relaunches
   `dsh` with the original arguments in the original directory.
5. Every step is appended to `%TEMP%\dsh-team-updater\update.log`, which the
   row reads back over `GET /team-updater/log` — so a failed install is
   visible in the GUI after the restart instead of being lost.

Routes (all on the GUI's own origin):

| Route | Purpose |
|---|---|
| `GET /team-updater/status[?refresh=1]` | installed vs registry version, update flag, log path, manual command |
| `POST /team-updater/apply` `{ version?, quit? }` | stage the update and hand off to the runner |
| `GET /team-updater/log` | tail of the runner log |

Every request passes through `connection.requestRejection`, the same Host/
Origin fence and browser-authentication policy the `/api` bridge uses; the
plugin composes only `webServer` and `connection` and adds no policy of its own.

## Config (`cordis.patch.yml`)

| Key | Default | Meaning |
|---|---|---|
| `tag` | `latest` | npm dist-tag to follow, or an exact version |
| `registry` | `https://registry.npmjs.org` | registry to query and install from |
| `restart` | `true` | relaunch dsh after a successful install |

## Verified

- `node --check` on all four sources.
- `node tests/check.mjs` — version ordering (release/prerelease, `rc.10 > rc.9`)
  and the real registry lookup: `latest` resolves, and it *is* newer than the
  installed `0.1.2-rc.1`.
- `node lib/update-runner.mjs` with no arguments exits 2 without touching npm.
- `dsh plugin --profile web add file:…` installed it, and
  `dsh --profile web --dump-config` shows the row composed into the profile
  tree as `id: team-updater, name: dsh-team-updater`.

## Not verified yet (first GUI boot will tell)

- **Whether the row renders.** The bundle is hand-written in the module
  loader's own format; a wrong module id or slot name shows up as a browser
  console error, not a dsh failure.
- **`ctx.connection.requestRejection` on a non-`/api` route.** If the browser
  cookie is not accepted there, the row shows a 401/403; the fallback is a
  loopback-socket check in `lib/index.js`.
- **The whole handoff on a real quit**, including whether `taskkill` needs the
  forced pass on this machine.
- **Styling.** The row uses inline styles and inherited colors, not the GUI's
  own primitives, so it may not match neighbouring rows exactly yet.
