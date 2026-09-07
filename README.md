# dsh + Figma

Get [DeepSeek Harness](https://www.deepseek.com/harness/en/) talking to Figma — create, edit and read designs from your agent.

Install scripts, a working MCP config, and the dead ends documented so you don't repeat them.

> **বাংলা:** [`README.bn.md`](README.bn.md) · পূর্ণ গাইড [`SETUP.md`](SETUP.md)

## What this gets you

- dsh running locally with your own API key
- Figma **read and write** from the agent: create frames, components and variables, or read a design and generate code
- 125 Figma tools available in any dsh session

Works on Windows and macOS. On Linux you get dsh and read-only Figma access — Figma has no Linux desktop app, and the write path needs it.

## Quick start

**Windows** — in Command Prompt (not PowerShell):

```
git clone https://github.com/sazzadursiam/dsh-setup.git
cd dsh-setup
setup.bat
```

**macOS / Linux:**

```bash
git clone https://github.com/sazzadursiam/dsh-setup.git
cd dsh-setup
chmod +x setup.sh
./setup.sh
```

The script installs Node.js, Git and dsh. It prints the remaining manual steps when it finishes.

On Windows, if the script installs Node or Git, it stops and asks you to reopen the terminal — Windows only picks up new PATH entries in a fresh one.

## Manual steps

1. **Set your Figma token** as an environment variable (see `.env.example`)
2. **Copy the MCP config:** `cordis.patch.yml` → your dsh profile
3. **Run `dsh web`**, then add your Anthropic API key under Settings → Models
4. **Import the bridge plugin** into Figma Desktop
5. **Copy `templates/AGENTS.md`** into each project folder

Full detail in `SETUP.md`.

## Something not working?

Run the verifier before digging through docs — it tells you which piece is missing:

```
verify.bat          # Windows
./verify.sh         # macOS / Linux
```

## Why not the official Figma MCP server

Figma's remote MCP (`https://mcp.figma.com/mcp`) does not work with dsh:

- It only accepts OAuth — no personal access tokens
- It does not allow dynamic client registration, so only pre-registered clients (VS Code, Cursor, Claude Code, Codex) can connect
- Both an OAuth-capable community plugin and the `mcp-remote` bridge fail at `registerClient` with `HTTP 403 Forbidden`

This repo uses [`figma-console-mcp`](https://github.com/southleft/figma-console-mcp) in Local Mode instead. It sidesteps OAuth entirely: a bridge plugin runs inside Figma Desktop — where you are already signed in — and talks to the MCP server over a local WebSocket. Writes go through Figma's Plugin API, which is why variables work even on Free and Pro plans.

## Known issues

**The screenshot tools are broken in Local Mode.** `figma_capture_screenshot` and `figma_take_screenshot` fail with `Cannot read properties of undefined (reading 'bytes')`. Worse, one failed call poisons the session — every later turn throws the same error even with no tool call, and the only fix is a new session.

This is upstream: the CDP transport those tools relied on was removed from Local Mode. `templates/AGENTS.md` keeps agents away from them, which is why copying it into each project matters.

**No Figma write access on Linux.** No desktop app means no bridge plugin. Use Windows or macOS for design work.

## Files

| File                       | Purpose                                                 |
| -------------------------- | ------------------------------------------------------- |
| `README.bn.md`             | This page in Bengali                                    |
| `SETUP.md`                 | Full guide (Bengali) — setup, workflow, troubleshooting |
| `setup.bat` / `setup.sh`   | Install scripts                                         |
| `verify.bat` / `verify.sh` | Check what is set up and what is missing                |
| `cordis.patch.yml`         | MCP server config — copy into your dsh profile          |
| `templates/AGENTS.md`      | Agent rules — copy into each project folder             |
| `.env.example`             | Which environment variables you need                    |
| `CHANGELOG.md`             | What changed and why                                    |

## Secrets

No tokens live in this repo. The Figma token is read from the system environment, and the Anthropic key is entered in the dsh UI.

If a token ever gets committed, deleting the file is not enough — it stays in git history. Revoke it at figma.com → Settings → Security and issue a new one.

## Status

dsh is a developer preview and ships breaking changes. If something here stops matching reality, open an issue or send a PR — that is how this stays useful.

## Author

Sazzadur Rahman

## License

MIT — see `LICENSE`.
