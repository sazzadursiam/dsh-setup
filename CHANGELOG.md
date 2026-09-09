# Changelog

## [Unreleased]

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
  modules unbuilt (npm 12 issue).
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
