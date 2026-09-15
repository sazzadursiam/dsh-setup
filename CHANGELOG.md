# Changelog

## [Unreleased]

### Added

- **`check.bat` / `check.sh`** — fetch quietly and compare against the shared
  repo; do nothing when the checkout is current, and offer to run the update
  when there are new commits. A team picks up updates without being told, and
  without the always-pull cost of `update`.
- **`enable-autoupdate.bat`** — one command that puts `check.bat` in the
  Windows Startup folder, minimized, so the check runs at every login without
  ever flashing a window (unseen when there is nothing new, one prompt in the
  taskbar when there is).
- **Auto-update notes** in `SETUP.md` Part 11 and the README, including the
  silent-schedule option for macOS / Linux.
- **`plugins/team-updater/`** — the in-app update button ("dsh updates" under
  Settings → General) now lives in this repo instead of a folder outside it, so
  it reaches a machine through `git pull` and needs no registry. `setup` and
  `update` add it to the `web` profile once that profile exists.

### Changed

- **The Figma MCP server is pinned to 1.40.0 instead of `@latest`.** With
  `@latest`, every dsh start ran whatever had been published last, on every
  machine at once — the same exposure that pinning dsh removed. `update` now
  carries the version in `cordis.patch.yml` into the profile's copy, rewriting
  only the `figma-console-mcp@…` entry and leaving the rest of that hand-edited
  file alone; `verify` reports a profile that differs. An existing profile on
  `@latest` moves to 1.40.0 on its next `update` — the version `@latest`
  resolved to at the time, so nothing changes in practice.
- **The `--allow-scripts` list has one source, `DSH_ALLOW_SCRIPTS`.** It was
  written out in six places — four scripts, the update button and its runner —
  so a dsh release adding a native dependency meant six edits, and a missed one
  meant one install path silently skipping a package's install script. `setup`,
  `update` and the button now read the file; the button hands it to the runner,
  and refuses to update when the file is malformed. The plugin's fallback list
  and the commands in `SETUP.md` remain copies, and `tests/check.mjs` fails when
  they drift. `verify` now points at `setup` instead of printing the command.
- **`update` no longer stops to ask for roles.** Roles were already optional —
  Enter meant "none" — but a machine with no rules file yet got the question in
  the middle of an update, which read as something having gone wrong. `update`
  now passes the new `agents --no-ask`: with no roles recorded it writes the
  core rules and prints how to add role blocks later. `setup` still asks, now
  marked optional, since first install is when choosing roles makes sense. This
  also lets a scheduled `update.sh` (cron / LaunchAgent) run on such a machine;
  before, with no terminal attached, `agents.sh` stopped there.
- **The update button installs the pinned dsh, not the registry's `latest`.**
  It reads the same `DSH_VERSION` as `setup` and `update`, so the button and the
  scripts can no longer pull a machine in opposite directions — before, a click
  could install a new release that the next `update` run then moved back down.
  A version now reaches the team when someone bumps `DSH_VERSION`, not the
  moment npm publishes it. The row converges on the pin both ways, so a machine
  that already took a newer release is offered the way back. A malformed pin, or
  a pinned version that is not on the registry, stops the button offering
  anything rather than falling back to `latest`, and `apply` refuses any version
  but the pinned one. Profiles with no `DSH_VERSION` to find keep following
  `tag` as before.

### Fixed

- **`agents.sh`, `check.sh`, `setup.sh`, `update.sh` and `verify.sh` were not
  executable in the repository.** Only `setup.sh` was worked around, by the
  `chmod +x setup.sh` the README had you run before it; the other four are
  documented to run the same way (`./update.sh`, `./verify.sh`, ...) with no
  such step, so a real fresh clone on macOS or Linux hit `Permission denied`
  on every one of them. Never noticed locally because nothing here had
  actually run those scripts from a truly fresh clone until CI (added this
  release) did. All five now carry the executable bit; the now-unneeded
  `chmod +x setup.sh` line is gone from the README.
- **The update button was never added on a machine without pnpm.** `dsh plugin`
  runs whatever `pnpm` is on PATH and does not ship one, so a machine set up with
  only Node and npm got `'pnpm' is not recognized` on every `update`. `setup`
  and `update` now install `pnpm@12` first when it is missing, with its install
  script allowed so the native binary is used. Tested with a PATH holding only
  Node and dsh.
- **The checkout can live on any drive, and in a path with spaces.** Tested from
  a separate drive letter with the dsh profile on `C:`. Three things broke along
  the way:
  - **A space in the checkout path stopped the update button being added.** dsh
    runs pnpm through a shell on Windows without quoting its arguments, so
    `X:\My Tools\dsh-setup` reached pnpm as `X:/My`. `setup.bat` and
    `update.bat` now carry quotes inside the argument when the path has a space.
  - **A bracket in the checkout path broke `agents.bat` outright** —
    `...\templates\core.md was unexpected at this time` — because a `)` in a
    path echoed inside a block ended the block early. Paths inside blocks are
    now echoed with delayed expansion.
  - **pnpm itself cannot install from a path containing `(` or `)`**
    ("Mismatch parenthesis"), so that case now skips the button with a clear
    reason instead of failing.
  When adding the plugin does fail, pnpm's own message is now shown; before, the
  output was discarded and only "could not add it" remained.
- **`update.bat` could derail when its own pull changed it.** cmd.exe reads a
  batch file from disk as it runs, so after `git pull` rewrote `update.bat` the
  rest of the run continued in the *new* file at the *old* file's byte offset —
  landing mid-line, re-running earlier steps, or skipping later ones such as
  adding the update button. Reproduced by pulling a change that shifts the file:
  `'every' is not recognized`, then the script restarting from the top. Both
  `update.bat` and `update.sh` now hand over to the freshly pulled copy as soon
  as the pull brings anything new, so the rest of the run is always the new
  script, read from the start. (bash does not corrupt the same way — it keeps
  reading the old file — but it did finish with the old logic, so a new step
  only took effect on the second run.) This protects updates from this version
  on; a machine still on an older `update.bat` should simply run it twice.
- **Agent-rule stamp parsing across platforms.** `verify.bat` and `agents.bat`
  read line 1 with `set /p`, which ends a line on CR and so swallowed a whole
  file written by `agents.sh` (LF only) — the version came out as garbage and
  roles could be silently forgotten. The shell side had the mirror problem: a
  file written by `agents.bat` (CRLF) left a stray CR that stopped the roles
  pattern from matching. Both sides now read the stamp the same way.
- **`verify.bat` always reported failure.** An unescaped `)` inside an `echo`
  closed the `if` block early, so `set FAIL=1` ran unconditionally and a clean
  machine still printed "SOME CHECKS FAILED".
- **`verify.sh` on Windows.** Git Bash was reported as Linux, which hid the
  bridge-plugin check and wrongly claimed Figma write access was unavailable;
  the port check only knew `lsof`, so it always said dsh was not running.
- **The update button skipped npm's install-script allowlist**, installing a
  different dsh than `setup`/`update` do.
- **`setup` and `update` install a pinned dsh, not `latest`.** They were
  installing whatever npm advertised, which is currently 0.1.5-rc.1 — so the
  very script you run to pick up a fix would have installed the release that
  breaks session resume. The version lives in the new `DSH_VERSION` file, and
  because the install now names a version, `update` also brings a machine that
  already took a bad release back down. The commands printed in `SETUP.md` are
  pinned to match.
- **The update button no longer offers dsh 0.1.5-rc.1 or 0.1.5-rc.2.** That
  release cannot resume a session written by an earlier dsh — every resume ends
  in `cannot get property "agent" without inject` — and the registry keeps
  advertising it as `latest`. The row says what it is holding back and why, and
  the apply route refuses those versions outright. The list lives in the
  plugin's `cordis.patch.yml`, so it can be lifted without a code change once a
  fixed dsh ships.

## [0.4.0] — 2026-09-10

**Breaking.** The agent rules move out of your projects and into one file per
machine. See `SETUP.md` Part 10 for the migration — it is two commands plus a
trim, and nothing breaks if you delay it.

### Changed

- **Shared agent rules now live in `~/.dsh/AGENTS.md`, not in a copy inside
  every project.** dsh loads that file into every session of every project
  automatically, before any project's own `AGENTS.md`
  (`@deepseek-ai/dsh-agent-instructions`, which `dsh-base` mounts by default).

  Copying a template into each project never worked, and three releases were
  spent patching around that. Every copy drifts the moment you fill in
  `## Project specifics` or delete a role block you don't need, so the repo can
  never safely overwrite one. 0.3.0 added version stamps and staleness
  reporting; 0.3.2 added folder scanning to find the copies. Both made the
  reporting better without changing the fact that re-applying every template
  change was manual work, repeated per project, forever — and growing with the
  number of projects.

  With no copies there is nothing to drift. Updating three machines is now
  writing one file on each, and adding a project costs nothing.

  A 3-way merge was prototyped first (`git merge-file`, base = the template at
  the copy's stamp). It merged cleanly when only `## Project specifics` had been
  filled in, but conflicted when a role block had been deleted *and* a rule
  added mid-file. It solved the symptom; this removes the cause.

- **`templates/AGENTS.md` is split into `templates/core.md` and
  `templates/roles/{figma,design-to-code,visual-assets}.md`**, assembled at
  install time. Which roles a machine gets is a property of the person using it,
  not of the repo, so it is asked once and remembered — no more "delete the
  blocks you don't use", which only works if nobody forgets.

- **The templates no longer carry one user's language or model list.** The old
  `AGENTS.md` opened with "Reply in Bengali" and named specific providers in the
  model-escalation section — fine when you copied and edited the file, wrong now
  that it is generated and public. The reply language is a remembered setting
  (`--lang`, default English), the escalation section talks about picking from
  your configured providers without naming any, and account-specific notes move
  to `local.md`.

- **`update.sh` / `update.bat` no longer take project paths.** Step 3 rewrites
  the shared rules instead of hunting for stale copies. The folder scanning,
  `projects.txt` support and stale-copy report are gone — about half of
  `update.bat`.

- **`verify.sh` / `verify.bat` no longer take a project directory.** They report
  whether `~/.dsh/AGENTS.md` exists and whether it came from this checkout.

- `setup.sh` / `setup.bat` install the rules as part of setup, so "copy
  AGENTS.md into each project folder" is no longer a manual step.

### Added

- **`agents.sh` / `agents.bat`** — writes `~/.dsh/AGENTS.md`. Takes
  `--role=figma,design-to-code` (or `--role=none`), `--lang=<language>`,
  `--show`, or nothing at all, in which case it reuses the roles and language
  recorded in the generated file's first line. Those are stored there rather
  than in a separate state file, so nothing new is added to `~/.dsh/`, which
  otherwise holds credentials. It writes only that one file, and backs up
  anything it did not generate before replacing it.
- **`local.md`** (git-ignored, from `templates/local.example.md`) — machine- and
  account-specific rules, appended to `~/.dsh/AGENTS.md` verbatim and never
  parsed. This is where the provider and off-peak notes that used to sit in the
  template now live, and it survives every update.
- **`templates/project.example.md`** — a starting point for a project's own
  `AGENTS.md`, which is now for project-specific rules only.
- **`templates/roles/index.txt`** — the role list, so adding a role is a new
  `.md` file plus one line, with no script changes.
- **`VERSION`** — single source of truth for the version stamp, read by
  `agents.*` and `verify.*`.

### Removed

- `templates/AGENTS.md`, and the per-project version-stamp mechanism it carried.
- The `projects.txt` convention and its `.gitignore` entry.

## [0.3.2] — 2026-09-09

### Changed

- **`templates/AGENTS.md` restructured for teams with more than one role**
  (template version `0.3.2`). It was written for a single workflow — Figma to
  frontend code — so six of its ten sections were Figma-specific. On a research
  or artwork project most of the file was noise, and the agent reads all of it
  at session start, which dilutes the rules that do apply.

  Now: a shared core (Communication, Before acting, **Research**, **Images and
  visual checking**, Model escalation, Safety) followed by clearly-labelled role
  blocks — Figma tooling, Design to code, and **Visual assets — Photoshop,
  Illustrator** — that each say to delete them when the project has no use for
  them. One template, one version stamp, one thing to maintain.

### Added

- **A "Research" section**, applying to every role. Nothing in the template
  covered research before, despite it being the one activity common to all of
  them: cite sources, prefer primary ones, separate what a source says from what
  you inferred, check dates, report conflicts instead of averaging them.
- **A "Visual assets" role block** for Photoshop and Illustrator work. It leads
  with the limitation — there is no Adobe integration in this setup, so the
  agent cannot open `.psd` or `.ai` at all — then covers what it can genuinely
  help with, and forbids inventing measurements or colour values for a file it
  cannot read.

### Fixed

- The "cannot render images" rules lived inside the Figma block, but they
  describe a limitation of the client, not of Figma. Moved into the shared core
  as "Images and visual checking", so they still apply on projects where the
  Figma block has been deleted.

## [0.3.1] — 2026-09-09

### Fixed

- **Part 1 never installed Git.** It set up Node only, while Part 2 (macOS)
  installed `node git` together and Part 7 then asked for `git init`. Step 1 is
  now "Node.js and Git" — folded into the existing step rather than inserted as
  a new one, so no step numbers or cross-references shift.
- **The quick start opened with `git clone` on a machine that may not have Git**
  — which the setup script is what installs. The README now offers the ZIP
  download or a one-line Git install first.
- **`setup.sh` installed Git through `apt-get` only**, despite claiming to
  support "other Linux distros"; Node already came from distro-agnostic nvm.
  It now detects `apt-get`, `dnf`, `pacman`, `zypper` or `apk`, and says which
  ones it looked for when none is found.
- **Removed the claim that "starting with npm 12, install scripts are disabled
  by default".** There is no npm 12. Verified against npm 11.17.0: the behavior
  is real but comes from `allow-scripts` being empty by default with
  `dangerously-allow-all-scripts` off. Reworded, with a pointer to
  `npm approve-scripts`.
- **The update scripts could not deliver themselves.** `update.sh` /
  `update.bat` shipped in 0.3.0, so any clone made earlier does not have them —
  running one is a "command not found" until you have already updated. Both
  READMEs now tell you to `git pull` by hand once, and use the script from then
  on. Same bootstrapping shape as the `git clone` fix above.
- Part 8 (troubleshooting) now points at `verify <project-dir>` for the case
  where the agent ignores a rule you know you wrote — usually a stale
  `AGENTS.md` copy.
### Removed

- **The Bengali translations (`README.bn.md`, `SETUP.bn.md`) are no longer part
  of the repo.** Keeping them in meant every documentation change had to be
  written twice, and the two languages had already drifted apart. They are now
  maintained locally only; `*.bn.md` is git-ignored, and the pointers to them in
  `README.md` and `SETUP.md` are gone. Earlier tags and history still contain
  them — this stops future updates, it does not unpublish what was released.

## [0.3.0] — 2026-09-09

### Added

- **`LICENSE`.** The README claimed MIT and the 0.2.0 entry below said the file
  was added, but it never existed. Without it the project was legally "all
  rights reserved" no matter what the README said.
- **Version stamp on `templates/AGENTS.md`** (`<!-- dsh-setup-template-version:
  0.3.0 -->`), and an `AGENTS.md` freshness check in `verify.sh` / `verify.bat`.
  Both now accept an optional project directory. `git pull` updates the
  template, never the copies already sitting in projects — this is what tells
  you a copy has fallen behind, without overwriting your `## Project specifics`.
- Agent rules for **model escalation** in `templates/AGENTS.md`: run bulk work on
  the cheap default and delegate hard sub-tasks through `subagent` with
  `agentOptions`, rather than raising the model for a whole session.
- **`update.sh` / `update.bat`** for installations that already exist: pulls the
  repo, shows what changed, reinstalls dsh with the right `--allow-scripts`
  allowlist, and reports which projects' `AGENTS.md` are behind. Takes project
  paths as arguments or from a git-ignored `projects.txt`. It refuses to pull
  over local changes, and it reports rather than rewrites — overwriting a
  project's `AGENTS.md` would destroy its `## Project specifics`.

### Changed

- **WSL support removed — Linux/Ubuntu is now the primary Linux target.**
  The WSL section in `SETUP.md` became a Linux (Ubuntu) section; WSL-only
  guidance (port forwarding, `/mnt/c` performance notes, `wsl --install`)
  and the unverified `FIGMA_WS_HOST=0.0.0.0` workaround were dropped.
  `setup.sh` and `verify.sh` no longer special-case WSL.
- `SETUP.md` now has a full macOS setup section (part 2) and was renumbered
  to Windows · macOS · Linux. `cordis.patch.yml` gained a Windows
  `npx.cmd` troubleshooting tip.

### Fixed

- **`.credentials.yaml` was documented as "write-only — you cannot see them
  again later". That is wrong.** The file's `refs:` section stores every
  provider key in plain text, readable in any editor. Corrected in six places
  across `SETUP.md`, `SETUP.bn.md`, `README.md` and `README.bn.md`, and replaced
  with a warning to treat `.dsh/` as a password file. Anyone who followed the
  old wording may have copied or shared that file believing it was safe.
- `setup.bat` line endings normalized to CRLF (`.gitattributes` added) so
  `cmd.exe` stops misparsing labels and `if` blocks.
- `npm update -g` advice replaced with the full `--allow-scripts` install
  command — `npm update` does not re-apply the allowlist and leaves native
  modules unbuilt.
- Broken `AGENTS.md` copy path in `SETUP.md`, Bengali characters inside a
  `setx` placeholder, missing `mkdir` before the config copy, and
  `taskkill /IM node.exe /F` no longer presented as the normal stop command.

## [0.2.0] — 2026-09-07

### Changed

- **Removed the `dsh-mcp-manager` dependency.** Testing showed dsh's built-in
  MCP client (`@deepseek-ai/dsh-mcp-client`) handles the Figma stdio server on
  its own. The community plugin was only ever added for OAuth, which Figma
  rejects anyway.
- Setup dropped from 5 install steps to 3. `pnpm` and the git-hosted plugin
  install are no longer needed.
- MCP server is now configured by copying `cordis.patch.yml` into the dsh
  profile instead of filling in a UI form.
- The Figma token moves to a system environment variable, so no secret is
  stored in any config file.

### Added

- `cordis.patch.yml` — shareable MCP config, no secrets.
- `.env.example`, `.gitignore`, `LICENSE`.
- Design-to-code guidance in `AGENTS.md` (auto layout, layer naming, tokens).

## [0.1.0] — 2026-09-06

### Added

- Initial setup guide for dsh on Windows and WSL.
- Figma integration via `figma-console-mcp` in Local Mode.
- `setup.bat` and `setup.sh` install scripts.
- `AGENTS.md` with rules that keep agents away from the broken screenshot tool.

### Known issues

- `figma_capture_screenshot` and `figma_take_screenshot` do not work in Local
  Mode, and one failed call poisons the whole session. Worked around in
  `AGENTS.md`. Upstream issue, not fixable here.
- Figma write access is unavailable on Linux — no Figma Desktop app, so the
  bridge plugin cannot be imported.
