# Changelog

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
