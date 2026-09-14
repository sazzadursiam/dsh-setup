# dsh-team-updater

An update button **inside the dsh web GUI**. It puts one row in *Settings →
General* that compares the running `@deepseek-ai/dsh` against the version
dsh-setup pins and, on click, installs that version and brings dsh back up.

No fork, no patched frontend bundle, no hand-edited files inside the dsh
installation: it is an ordinary out-of-tree profile plugin.

```
Settings → General
┌──────────────────────────────────────────────────────────────────────┐
│ dsh updates                 0.1.2-rc.1 → 0.1.6, pinned by dsh-setup  │
│                                    [ Update & restart ] [ Check again]│
└──────────────────────────────────────────────────────────────────────┘
```

## Which version it installs

The one named in `DSH_VERSION` at the root of the dsh-setup checkout — the same
file `setup` and `update` install from. Not whatever the registry calls
`latest`.

That is deliberate. A button that follows the registry and a script that follows
a pin will eventually disagree: a new release appears, someone clicks, and the
next `update` run moves the machine back down. More importantly, a list of
blocked versions can only exclude releases already known to be bad; a pin
excludes every release nobody has looked at yet. dsh 0.1.5-rc.1 is why this
matters — it could not resume any session written by an earlier dsh, and the
registry offered it as `latest`.

So the row converges on the pin in both directions. Pin bumped: it offers the
new version. Machine already on something newer than the pin: it offers the way
back, which is also what `update` would do. Installed equals pinned: it offers
nothing.

The profile holds a *copy* of this plugin, not a link, so the copy finds the
checkout through the `file:` spec `setup` recorded in the profile's
`package.json`. The file is read on every check, so a `git pull` that changes
the pin reaches the row without reinstalling the plugin.

It refuses rather than guesses: a `DSH_VERSION` holding something that is not a
version, or a pinned version the registry has not published, stops the row from
offering anything, since the runner quits dsh before npm runs and a failed
install would leave dsh stopped. With no `DSH_VERSION` found at all — a profile
added by hand from a copy outside any checkout — it falls back to following
`tag`, as it did before pins existed.

## Install

`setup.bat` / `setup.sh` and `update.bat` / `update.sh` in the repo root do this
for you once the `web` profile exists. By hand, from the repo root in cmd:

```
dsh plugin --profile web add "file:%CD%\plugins\team-updater"
```

If that path contains a space, use `"""file:%CD%\plugins\team-updater"""`
instead. dsh 0.1.2-rc.1 hands the arguments to pnpm through a shell on Windows
without quoting them, so a plain quoted path arrives split at the space; the
extra quotes survive that step. A path containing `(` or `)` cannot be used at
all — pnpm rejects it with "Mismatch parenthesis".

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
| `versionFile` | found automatically | path to a pin file, overriding the checkout's `DSH_VERSION`; an unreadable one is an error |
| `tag` | `latest` | npm dist-tag to follow, or an exact version — **only when no pin is found** |
| `registry` | `https://registry.npmjs.org` | registry to query and install from |
| `restart` | `true` | relaunch dsh after a successful install |
| `blocked` | 0.1.5-rc.1, 0.1.5-rc.2 | `version: reason` pairs never installed, even if pinned — a backstop against a pin set by mistake |

## Verified

- `node tests/check.mjs` — version ordering, finding the pin in both the
  checkout and the profile-copy layout (absolute and relative `file:` specs,
  empty and malformed pins, a missing explicit `versionFile`), the shipped
  blocked list, and the real registry lookup.
- The row renders in Settings → General — pinned, it reads
  "0.1.2-rc.1 · up to date, pinned by dsh-setup" with only *Check for updates*
  offered — and the routes answer 401 without the browser session cookie and
  200 with it.
- A real quit and install on Windows: the polite `taskkill` is refused for a
  windowless console process and the forced pass succeeds, as the log shows.
- The host half, driven against the real registry with a stand-in dsh context:
  installed equals pinned offers nothing; a bumped pin is offered exactly; an
  unpublished, blocked or malformed pin offers nothing and `apply` answers 409;
  a `version` in the request body other than the pin is refused; a machine
  above the pin is offered the way back; and a click stages exactly the pinned
  version for the runner.

## Not verified yet

- **Styling.** The row uses inline styles and inherited colors, not the GUI's
  own primitives, so it may not match neighbouring rows exactly.
- **A click on a real pin bump.** Offering and staging the pinned version were
  checked through the host half; a full quit → install → relaunch to a newly
  pinned version has not been run, since no newer usable dsh exists yet.
