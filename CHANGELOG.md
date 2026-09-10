# Changelog

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
