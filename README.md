# dsh + Figma

[![CI](https://github.com/sazzadursiam/dsh-setup/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/sazzadursiam/dsh-setup/actions/workflows/ci.yml)

Get [DeepSeek Harness](https://www.deepseek.com/harness/en/) talking to Figma — create, edit and read designs from your agent.

Install scripts, a working MCP config, and the dead ends documented so you don't repeat them.

> **Full guide:** [`SETUP.md`](SETUP.md) — install, troubleshooting, maintenance. Longer topics have their own page: [Figma integration](docs/figma.md), [project setup and workflow](docs/workflow.md).

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
./setup.sh
```

**No Git yet?** These commands start with `git clone`, but Git is one of the
things the script installs — so on a fresh machine, get the code first by either
route:

- Download the ZIP from the repo page (**Code → Download ZIP**) and unpack it, or
- `winget install Git.Git` on Windows / `brew install git` on macOS, open a new
  terminal, then clone as above.

**Where to put it.** Any folder, on any drive — it does not need to sit next to
your projects, and your projects can live on other drives, since nothing here
reads or writes project folders. Spaces in the path are fine. One limit: keep
`(` and `)` out of the checkout's path. pnpm cannot install the dsh plugins
from such a folder, so `setup` and `update` skip that step and say so.

The script installs Node.js, Git and dsh. It asks once whether to also set up Figma integration (default: no — just dsh and coding tools if you skip it) before printing the remaining manual steps.

On Windows, if the script installs Node or Git, it stops and asks you to reopen the terminal — Windows only picks up new PATH entries in a fresh one.

**Only want dsh, no Figma?** Press Enter at that prompt (or don't pass `--with-figma`) and it's skipped — no MCP server, no extra tools. Add it later any time from `dsh web` → Settings → General → "Add Figma integration", no terminal needed — and remove it again the same way, with a "Remove Figma integration" button next to the token field.

## Manual steps

1. **Run `dsh web`**, then set your Figma token under Settings → General → "Figma token" (no terminal needed — restart dsh after saving). Setting it as an environment variable instead still works too (see `.env.example`). If you skipped Figma during setup, click "Add Figma integration" first.
2. **Add an API key** under Settings → Models — DeepSeek or Anthropic
3. **Import the bridge plugin** into Figma Desktop

Full detail in `SETUP.md`.

## Agent rules

dsh loads `~/.dsh/AGENTS.md` into **every session of every project**, before any
project's own `AGENTS.md`. So the shared rules — how to reply, how to research,
what not to touch, when to escalate the model — live in that one file per
machine. Nothing is copied into your projects, so there is nothing to go stale.

`setup` writes it for you. To change it later:

```
agents.bat --role=figma,design-to-code     # Windows
./agents.sh --role=figma,design-to-code    # macOS / Linux
./agents.sh --lang=Bengali                 # reply language
./agents.sh --show                         # what is installed right now
```

**Language** defaults to English. Set `--lang` for anything else — it is
remembered like roles, and it is the way to get replies in a script when you
type in a romanised form. (In `agents.bat`, `--lang` takes the rest of the line,
so put it last.)

**Roles pick which extra rule blocks you get**, because a machine used for
Photoshop work should not be reading Figma tool rules at the start of every
session:

| Role | For |
| ------------------ | ---------------------------------------------- |
| `figma`            | Reading and writing Figma via the bridge plugin |
| `design-to-code`   | Building frontend code from Figma designs       |
| `visual-assets`    | Photoshop and Illustrator work                  |

You are asked once and it is remembered, so plain `./agents.sh` regenerates with
the same roles. Edits to `~/.dsh/AGENTS.md` are overwritten on the next update —
to change the shared rules, edit `templates/core.md` or `templates/roles/*.md`.

**For rules that are true of your machine or account** — the providers you
actually pay for, an internal proxy, a folder outside your projects — copy
`templates/local.example.md` to `local.md` in the repo root (git-ignored). It is
appended to `~/.dsh/AGENTS.md` verbatim and survives every update. The templates
stay provider-neutral so they are useful to everyone; `local.md` is where you get
specific. No credentials in it — it lands in every session's context.

**Project-specific rules go in that project's own `AGENTS.md`**, committed to
that project's repo. This repo never touches it. Start from
`templates/project.example.md`, and keep it short — it is read at the start of
every session. A rule a *project* must obey belongs there, not in the global
file: the global file is per-machine and does not travel with a clone.

## Updating

One command pulls this repo, updates dsh with the right `--allow-scripts`
allowlist, moves your Figma MCP (if you installed it) to the version pinned in
`plugins/figma-bridge/cordis.patch.yml`, and rewrites your agent rules. If you
skipped Figma during setup, update leaves it skipped — it never installs it
for you; use the "Add Figma integration" button in Settings for that:

```
update.bat          # Windows
./update.sh         # macOS / Linux
```

**First time on an older clone?** These scripts arrived in v0.3.0, so a clone
made before that does not have them yet. Pull once by hand to get them, then use
them from then on:

```
cd dsh-setup
git pull
./update.sh          # update.bat on Windows
```

Two things no script can do for you: **restart your sessions** (changed rules
only reach a session started afterwards — there is no file watcher), and
**update `~/.dsh/settings.yaml`** — model choice, reasoning effort and API keys
are per-machine and live outside this repo.

## Auto-update (optional)

Your team does not need you to tell them when you have shipped something.
`check` fetches quietly, compares against the shared repo, and does nothing
when the checkout is already current. When there are new commits it says so
and offers to run the update:

```
check.bat           # Windows
./check.sh          # macOS / Linux
```

To have it happen by itself at login:

- **Windows** — `setup.bat` and `update.bat` do this for you now: they put a
  shortcut to `check.bat` in your Startup folder, minimized so it never takes
  the screen. When there is nothing new it opens and closes in the taskbar
  unseen; when there is an update, click the taskbar entry to see the prompt.
  Nothing to run by hand — but `enable-autoupdate.bat` still exists if you
  ever need to redo it (e.g. after moving the checkout).
- **macOS / Linux** — run `./check.sh` by hand, or schedule `update.sh` directly
  for fully silent updates. Both are in `SETUP.md`, Part 11.

`check` covers this repo — the shared rules and the scripts. **dsh itself** has
its own button: `setup` and `update` add the `plugins/team-updater` plugin to
your dsh profile, which puts a "dsh updates" row under **Settings → General**
that installs dsh and restarts for you. It installs the version in
`DSH_VERSION` — the same one `setup` and `update` use — not whatever npm calls
latest. So a new dsh reaches the team when someone bumps `DSH_VERSION` and the
change is pulled, not the moment it is published.

**The Figma MCP server** is installed the same way, as `plugins/figma-bridge`
— `setup` and `update` add it with `dsh plugin --profile web add`, so there is
nothing to hand-copy. A version bump in this repo reaches an already-installed
profile the next time `update` runs.

## Something not working?

Run the verifier before digging through docs — it tells you which piece is missing:

```
verify.bat          # Windows
./verify.sh         # macOS / Linux
```

It also reports whether your agent rules are installed and current.

## Why not the official Figma MCP server

Figma's remote MCP (`https://mcp.figma.com/mcp`) does not work with dsh:

- It only accepts OAuth — no personal access tokens
- It does not allow dynamic client registration, so only pre-registered clients (VS Code, Cursor, Claude Code, Codex) can connect
- Both an OAuth-capable community plugin and the `mcp-remote` bridge fail at `registerClient` with `HTTP 403 Forbidden`

This repo uses [`figma-console-mcp`](https://github.com/southleft/figma-console-mcp) in Local Mode instead. It sidesteps OAuth entirely: a bridge plugin runs inside Figma Desktop — where you are already signed in — and talks to the MCP server over a local WebSocket. Writes go through Figma's Plugin API, which is why variables work even on Free and Pro plans.

## Known issues

**The screenshot tools are broken in Local Mode.** `figma_capture_screenshot` and `figma_take_screenshot` fail with `Cannot read properties of undefined (reading 'bytes')`. Worse, one failed call poisons the session — every later turn throws the same error even with no tool call, and the only fix is a new session.

This is upstream: the CDP transport those tools relied on was removed from Local Mode. The `figma` role block keeps agents away from them, which is why it is worth having in your rules if you touch Figma at all.

**No Figma write access on Linux.** No desktop app means no bridge plugin. Use Windows or macOS for design work.

## Files

| File                          | Purpose                                                    |
| ----------------------------- | ---------------------------------------------------------- |
| `SETUP.md`                    | Guide (English) — install on each OS, troubleshooting, maintenance |
| `docs/figma.md`               | Figma integration: token, config file, bridge plugin       |
| `docs/workflow.md`            | Per-project setup, where agent rules live, Figma → code    |
| `setup.bat` / `setup.sh`      | Install scripts                                            |
| `update.bat` / `update.sh`    | Update an existing setup                                   |
| `check.bat` / `check.sh`      | Check for updates, apply only when you say yes             |
| `enable-autoupdate.bat`       | Add the login-time update check (Windows)                  |
| `ensure-npm-path.bat`         | Put npm's global folder on PATH if `dsh` is not found — called by `setup.bat` and `update.bat` (Windows) |
| `agents.bat` / `agents.sh`    | Write the shared agent rules to `~/.dsh/AGENTS.md`         |
| `verify.bat` / `verify.sh`    | Check what is set up and what is missing                   |
| `plugins/team-updater/`       | The in-app update button — added to your dsh profile by setup |
| `plugins/figma-bridge/`       | Figma MCP server config — added to your dsh profile by setup, like `plugins/team-updater/` |
| `templates/core.md`           | The shared rules, applied on every project                 |
| `templates/roles/`            | Optional rule blocks — Figma, design-to-code, visual assets |
| `templates/project.example.md`| Starting point for a project's own `AGENTS.md`             |
| `templates/local.example.md`  | Starting point for `local.md` — your machine-specific rules |
| `.env.example`                | Which environment variables you need                       |
| `VERSION`                     | What version this checkout is                              |
| `DSH_VERSION`                 | Which dsh version setup and update install — pinned, not `latest` |
| `DSH_ALLOW_SCRIPTS`           | Which packages npm may run install scripts for when installing that dsh |
| `CHANGELOG.md`                | What changed and why                                       |
| `LICENSE`                     | MIT                                                        |

## Secrets

No tokens live in this repo. The Figma token can be set as a system environment variable, or pasted into Settings → General in the dsh UI (see `plugins/figma-bridge/`); the provider API key (DeepSeek or Anthropic) is entered in the dsh UI.

Entering a key in the UI is not the same as encrypting it: dsh writes every provider key **in plain text** to `~/.dsh/.credentials.yaml`, and the Figma token set via Settings → General is written **in plain text** to `~/.dsh/profiles/web/node_modules/dsh-figma-bridge/cordis.patch.yml`. Never copy those files or the `.dsh/` folder to another machine, a repo, or a syncing backup, and never paste their contents anywhere. Details in `SETUP.md`, Part 1 Step 4.

If a token ever gets committed, deleting the file is not enough — it stays in git history. Revoke it at figma.com → Settings → Security and issue a new one.

## Status

dsh is a developer preview and ships breaking changes. If something here stops matching reality, open an issue or send a PR — that is how this stays useful. How to do that is in [`CONTRIBUTING.md`](CONTRIBUTING.md); security problems go through [`SECURITY.md`](SECURITY.md), not a public issue.

## Author

Sazzadur Rahman

## License

MIT — see `LICENSE`.
