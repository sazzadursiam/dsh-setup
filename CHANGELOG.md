# Changelog

## [Unreleased]

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
