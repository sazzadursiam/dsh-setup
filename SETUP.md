# DeepSeek Harness (dsh) — Local Setup Guide

**Created:** September 2026
**Environment:** Windows · macOS · Linux/Ubuntu (macOS instructions: Part 2; Linux Figma limitations: Part 3)
**Status:** dsh is still a developer preview — breaking changes may arrive

> **About paths:** In this document `%USERPROFILE%` means your user folder (e.g. `C:\Users\AC`). In **cmd** it works as-is, and pasting it into a Windows file dialog opens the location too. In **PowerShell** replace it with `$env:USERPROFILE`. On **macOS/Linux** use `~` (your home folder, e.g. `/Users/AC`) instead — `%USERPROFILE%\.dsh` = `~/.dsh`.

> **What you must do by hand on each machine:** a DeepSeek or Anthropic API key, Figma PAT, sign in to Figma Desktop, import the bridge plugin, select a workspace. Everything else happens by running commands.

**Contents**

- [What dsh is](#what-dsh-is)
- [Part 1 — Windows setup](#part-1--windows-setup)
- [Part 2 — macOS setup](#part-2--macos-setup)
- [Part 3 — Linux (Ubuntu) setup](#part-3--linux-ubuntu-setup)
- [Part 4 — What not to do](#part-4--what-not-to-do)
- [Part 5 — Safe usage rules](#part-5--safe-usage-rules)
- [Part 6 — Figma integration (create / edit / read)](#part-6--figma-integration-create--edit--read) → [docs/figma.md](docs/figma.md)
- [Part 7 — Project setup and workflow](#part-7--project-setup-and-workflow) → [docs/workflow.md](docs/workflow.md)
- [Part 8 — Troubleshooting](#part-8--troubleshooting)
- [Part 9 — New-PC setup checklist](#part-9--new-pc-setup-checklist)
- [Part 10 — Migrating from v0.3.x](#part-10--migrating-from-v03x)
- [Part 11 — Auto-updates (optional)](#part-11--auto-updates-optional)
- [Quick reference](#quick-reference)

---

## What dsh is

DeepSeek Harness (`dsh`) is an open-source agent harness built by DeepSeek AI, MIT licensed. Core idea: **everything is a plugin**. Model, tools, sessions, sandbox, storage, UI — all plugins, all swappable through config.

Important: **the harness is local, the model is not.** API calls go to DeepSeek or Anthropic servers.

**Reference links**

- Site: https://www.deepseek.com/harness/en/
- GitHub: https://github.com/deepseek-ai/deepseek-harness
- Docs: https://deepseek-harness.github.io/deepseek-harness/en/guide/quickstart

---

## Part 1 — Windows setup

> **A word about terminals:** PowerShell blocks script execution by default, so `npm`/`npx` throw errors (`.ps1 cannot be loaded`). The least-friction path is **cmd** (Win+R → `cmd`). If you prefer PowerShell, run this once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

### Step 1: Node.js and Git

```powershell
winget install OpenJS.NodeJS.LTS
winget install Git.Git
```

Git is needed to clone this repo, and again in [Part 7](docs/workflow.md) — `git init` per project is
what lets you review and undo what the agent changes.

**After installing, close PowerShell and open a new one.** Otherwise PATH will not update.

Verify:

```powershell
node -v
npm -v
git --version
```

If all three print version numbers, you are good.

### Step 2: Install dsh

```powershell
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh@0.1.2-rc.1
```

The `--allow-scripts` part is essential. `node-pty` and `koffi` compile native binaries in an install script, and the shell/terminal tools do not work without them. **Do not remove it** — npm will not run a dependency's install scripts unless that package is allowlisted, so the native modules are silently never built (error: `Failed to load native module`).

The list belongs to the dsh version, since a new release can bring a new native
dependency. The scripts and the in-app update button read it from the
`DSH_ALLOW_SCRIPTS` file; the commands in this guide are copies of it.

The version is pinned on purpose, and the setup scripts read it from the
`DSH_VERSION` file rather than taking whatever npm calls `latest`. dsh is a
developer preview, and a release can land that this setup cannot use: 0.1.5-rc.1
cannot resume a session written by an earlier version, so every old session
fails to open with `cannot get property "agent" without inject`. The in-app
update button refuses those versions too — the list, with reasons, is in
`plugins/team-updater/cordis.patch.yml`.

<details>
<summary>Why npm needs telling</summary>

Checked against npm 11.17.0: `allow-scripts` is empty by default and
`dangerously-allow-all-scripts` is `false`, so an unlisted package's scripts are
skipped. `npm approve-scripts` and `npm deny-scripts` manage the same list
interactively if you would rather not pass the flag each time.

</details>

Just want to try it without installing:

```powershell
npx @deepseek-ai/dsh web
```

### Step 3: Start the server

```powershell
dsh web
```

Default address: `http://127.0.0.1:3080`
If a firewall popup appears, choose **Allow access**.

**Keep the terminal open** — closing it stops the server. To stop it, press Ctrl+C.

### Step 4: API key

Open **Settings → Models**.

**DeepSeek** — one key field on the card. Get the key from https://platform.deepseek.com.

**Anthropic** — **Add provider** → Anthropic → paste the key. Model list, endpoint and protocol come automatically. Get the key from console.anthropic.com → API keys. You need credit on the console; a Claude.ai subscription does not enable the API.

Once saved it works without a restart. Keys are stored in `%USERPROFILE%\.dsh\.credentials.yaml` (`$DSH_HOME` = dsh's data folder = `%USERPROFILE%\.dsh`).

> ⚠️ **That file stores your keys in plain text.** Its `refs:` section lists every key by name, readable in any text editor — the UI hides them, the file does not. Treat `.dsh\` like a password file: never copy it to another machine, never put it in a repo or a backup that syncs, and never paste its contents into a chat or issue. Anyone who reads it has all your provider keys. If it leaks, rotate every key it contains.

### Step 5: Workspace

Click **Choose workspace** and add your project folder. The chat box stays disabled until a workspace is selected.

You can add several workspaces and switch from the UI later. **No need to launch dsh from the project folder every time** — the folder you launch from is only the default suggestion.

### Step 6: Test

Start with an empty folder, e.g. `C:\Users\<name>\dsh-test`. Open a session and type: "make a hello world Python script". If the file is created, the setup works.

---

## Part 2 — macOS setup

On macOS **everything works** — Figma Desktop exists on Mac, so both read and write are available (same as Windows). The steps mirror Windows; only the package manager and paths differ: `brew` and `~` (= `/Users/<name>`), plus the `Cmd+/` keyboard shortcut.

### Step 1: Node.js + Git (Homebrew)

```bash
brew install node git
```

If you don't have `brew`, install it first from https://brew.sh. Verify:

```bash
node -v
git --version
```

### Step 2: Install dsh

```bash
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh@0.1.2-rc.1
```

The `--allow-scripts` part is essential — Part 1 Step 2 explains why.

### Step 3: Figma token

Once `dsh web` is running (Step 4 below installs it): Settings → General → "Figma token" → paste it and save. No terminal needed — restart dsh afterward to use it.

By hand instead, append to the end of `~/.zshrc` (zsh is macOS's default shell):

```bash
export FIGMA_ACCESS_TOKEN="figd_..."
export ENABLE_MCP_APPS=true
```

Then verify with `source ~/.zshrc` (or a new terminal):

```bash
echo $FIGMA_ACCESS_TOKEN
```

### Step 4: API key

`dsh web` → `http://127.0.0.1:3080` → Settings → Models → add a DeepSeek or Anthropic key (Part 1 Step 4 shows both). Keys are stored in `~/.dsh/.credentials.yaml` **in plain text** — see the warning in Part 1 Step 4.

### Step 5: Add the Figma MCP plugin

`setup.sh` asks once whether to install this (default: no) — say yes there, or
skip and add it later from `dsh web` → Settings → General → "Add Figma
integration", no terminal needed. `update.sh` never installs it for you if you
skipped it; it only keeps an already-installed copy in sync. By hand:

```bash
dsh plugin --profile web add "file:$PWD/plugins/figma-bridge"
```

([Figma integration, Step 4](docs/figma.md#step-4-config-file) has the full detail, including the manual config fallback.)

### Step 6: Import the bridge plugin

The server creates the plugin files when it starts. Verify:

```bash
ls ~/.figma-console-mcp/plugin
```

`manifest.json`, `code.js`, `ui.html` should be there. Then, with a file open in Figma Desktop, press **`Cmd+/`** → type `import` → **Import plugin from manifest…** → pick `~/.figma-console-mcp/plugin/manifest.json`. Then run **Figma Desktop Bridge** — you should see a green **Connected** status.

(Full detail: [Part 6](docs/figma.md). Where it says `%USERPROFILE%` and `setx`, read `~` and `export`.)

### Verify

```bash
./verify.sh
```

If everything is green the setup is done. Your agent rules are already installed at `~/.dsh/AGENTS.md` and apply to every project (see [workflow](docs/workflow.md)).

---

## Part 3 — Linux (Ubuntu) setup

On Linux, dsh and coding work fully, but there is **no Figma write** — Figma Desktop does not exist on Linux, so the Desktop Bridge plugin cannot be imported. Figma read (via PAT) works.

You need a separate Node (the distro-bundled one is often old):

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install --lts
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh@0.1.2-rc.1
dsh web
```

`http://127.0.0.1:3080` opens in your browser.

**Keep projects in `~/projects/`.** dsh reads the whole folder tree as the workspace, so don't select a huge location (like your home or `/`).

Read-only Figma tools (design system, variables, components) work over the PAT — but **write and bridge-dependent tools will not**. For design work use Windows or a Mac.

---

## Part 4 — What not to do

### Don't set up auto-start

Putting a `.bat` in the Startup folder and running it in the background **has caused problems** — it ran out of memory and hung the PC.

Why: hidden windows can accumulate multiple instances, and the agent itself spawns subprocesses (shell, sandbox, subagent). Memory climbs fast if a session loops or a large folder gets indexed — and you can't tell because it is hidden.

**To remove auto-start:**

```powershell
explorer shell:startup
```

Delete `dsh.bat` (or its shortcut) from the folder that opens.

**To kill a stuck process:**

```powershell
taskkill /IM node.exe /F
```

(Kills all Node processes.) Or Ctrl+Shift+Esc → Task Manager → `node.exe` → End task.

### Don't make a big folder your workspace

Don't select `C:\Users\<name>` or Desktop. The agent can read and modify files in the workspace, and a large tree eats memory.

---

## Part 5 — Safe usage rules

- **Start it by hand, stop it when done.** If you can see the terminal you know what is happening; Ctrl+C stops it immediately.
- For the first few sessions, **keep Task Manager open and watch `node.exe` memory**. If it keeps growing, press Ctrl+C.
- Start with a small, separate workspace.
- The server binds to `127.0.0.1` — reachable only from that PC, nobody else on the network can get in.

---

## Part 6 — Figma integration (create / edit / read)

This part is its own page: **[docs/figma.md](docs/figma.md)**. It covers what works and what
does not, the Figma token and its scopes, the config file, the Desktop bridge plugin, and the
known problems (the broken screenshot tools).

---

## Part 7 — Project setup and workflow

This part is its own page: **[docs/workflow.md](docs/workflow.md)**. It covers per-project setup,
where the agent rules live, sessions, and going from a Figma design to code.

---

## Part 8 — Troubleshooting

**If something doesn't work, run the verifier first** — it tells you directly which piece is missing:

```
verify.bat          # Windows
./verify.sh         # macOS / Linux
```

> **Note (Windows):** if you set the token by hand with `setx`, running verify in the **same window** afterward shows a false `[FAIL]` on `FIGMA_ACCESS_TOKEN` — `setx` only affects new terminals. Close the window, open a new cmd, and run it again. Setting the token via Settings → General instead does not have this problem — `verify.bat` checks that file directly.

It also reports whether `~/.dsh/AGENTS.md` is installed and came from this
version of the repo — worth checking when the agent ignores a rule you know you
wrote. If it is behind, run `agents.sh` (your roles are remembered) and start a
new session.

Then use the table below.

| Problem                                                                    | Solution                                                                                                                                                             |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `'node' is not recognized`                                                 | Restart the terminal. If that fails: `$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")` |
| `'dsh' is not recognized` right after installing                           | npm's global folder is not on PATH. `setup.bat` and `update.bat` add it for you (`ensure-npm-path.bat`). By hand: add `%APPDATA%\npm` to your user PATH and open a new terminal |
| `npm.ps1` / `npx.ps1 cannot be loaded because running scripts is disabled` | PowerShell's execution policy is blocking it. Run in cmd (Win+R → `cmd`), or once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`                               |
| `Cannot find module` / `.node file not found`                              | Reinstall with `--allow-scripts` (Step 2)                                                                                                                            |
| Port 3080 busy                                                             | Run `netstat -ano \| findstr 3080` to see who is holding it                                                                                                          |
| `MISSING_CREDENTIAL`                                                       | The key wasn't saved on the Models page                                                                                                                              |
| `UNKNOWN_MODEL`                                                            | Select a configured model                                                                                                                                            |
| Fetch models → 401                                                         | Wrong key or no credit                                                                                                                                               |
| PC hangs / out of memory                                                   | `taskkill /IM node.exe /F`, remove auto-start                                                                                                                        |
| `client registration failed: HTTP 403` (Figma OAuth)                       | Figma doesn't allow dynamic client registration. The official remote MCP won't run in dsh — use figma-console-mcp                                                      |
| `Cannot read properties of undefined (reading 'bytes')`                    | Screenshot tool is broken. Session is poisoned — open a **New Session**                                                                                              |
| `figma_get_status` tool missing                                            | 1) Check `cordis.patch.yml` indentation (spaces, not tabs). 2) On Windows try `command: npx` → `command: npx.cmd`. Then restart dsh                    |
| Can't get the Figma token                                                  | If set via `setx`, check that you started dsh from a new cmd afterward. If set via Settings → General, restart dsh (Ctrl+C, then `dsh web` again)                    |
| Figma write tools not working                                              | Bridge plugin window closed, or Figma Desktop closed, or you're in Minimal mode                                                                                       |

The `deprecated node-domexception` warning can be ignored. The npm update notice is optional too.

---

## Part 9 — New-PC setup checklist

To build the whole system from scratch, follow this order. Details for each item are in the earlier parts.

**Prep**

- [ ] Figma Desktop app installed and signed in
- [ ] Using cmd (not PowerShell) — otherwise fix the execution policy first

**Install (all in cmd)**

- [ ] `winget install OpenJS.NodeJS.LTS` → **restart terminal** → verify `node -v`
- [ ] `winget install Git.Git` → **restart terminal** → verify `git --version`
- [ ] `npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh@0.1.2-rc.1`

**dsh config**

- [ ] `dsh web` → `http://127.0.0.1:3080` → Settings → Models → add a DeepSeek or Anthropic key

The rest of this checklist is for Figma integration — skip it if this machine
only needs dsh for coding. Using `setup.bat` instead of building by hand, it
asks about this for you and does the plugin-add step itself (default: no).

- [ ] `dsh plugin --profile web add "file:%CD%\plugins\figma-bridge"` ([Part 6 Step 4](docs/figma.md#step-4-config-file)) — or, once dsh is running, Settings → General → "Add Figma integration"
- [ ] Settings → General → "Figma token" → paste and save (or by hand: `setx FIGMA_ACCESS_TOKEN "figd_..."` and `setx ENABLE_MCP_APPS true`, then open a **new cmd**)
- [ ] Restart dsh so it picks up the token
- [ ] Restart dsh → `figma_get_status` works in the session

**Figma bridge**

- [ ] `dir %USERPROFILE%\.figma-console-mcp\plugin` → manifest.json present
- [ ] In Figma Desktop `Ctrl+/` → `import` → Import plugin from manifest…
- [ ] Run the plugin → green **Connected — Connected to 1 AI app**

**Project**

- [ ] Create a folder and `git init` it
- [ ] Add and select it via Choose workspace in dsh
- [ ] New Session, Standard mode → test with `figma_diagnose`

### What can be shared

- **Figma PAT** — make one and use it on every PC. When it expires you must change it everywhere.
- **Agent rules** — clone this repo on each machine and run `agents.sh` there. Each person picks their own roles, so the file ends up different per machine on purpose.
- **A project's own `AGENTS.md`** — it is committed to that project's repo, so everyone gets it with `git pull`.

### What cannot

- **API key** — entered per machine in the UI; `$DSH_HOME` differs.
- **Bridge plugin** — imported separately on each machine.

### Caution

**Run it on one PC for a few days before rolling out.** dsh is a dev preview and Figma changes its UI often — a month later the buttons may not be where they were.

When setting up a second PC from this document, **update the document wherever reality doesn't match**. Then hand the verified version to the rest of the team.

Update:

```
update.bat          # Windows
./update.sh         # macOS / Linux
```

That pulls this repo, runs the install command below, and rewrites
`~/.dsh/AGENTS.md` with your remembered roles. To update only the npm package:

```powershell
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh@0.1.2-rc.1
```

**Don't use `npm update -g`** — it doesn't re-apply the `--allow-scripts` allowlist, so the native modules (node-pty, koffi) are left unbuilt (`Cannot find module` / `.node file not found` error — see Part 8). The install command above is the correct way to update, and running it repeatedly is safe — if you're already on the latest it changes nothing.

---

## Part 10 — Migrating from v0.3.x

Skip this if you set up with v0.4.0 or later.

Before v0.4.0, every project held its own copy of `templates/AGENTS.md`. Those
copies still work — dsh reads a project's `AGENTS.md` exactly as before — but
they now duplicate the shared rules that `~/.dsh/AGENTS.md` provides on every
project. Trim each one down to what is genuinely project-specific.

**1. Install the shared rules** (once per machine):

```
cd dsh-setup
git pull
update.bat            # ./update.sh on macOS/Linux — asks which roles you work in
```

**2. Trim each project's copy.** See what your copy has that the old template
never had:

```
git -C dsh-setup show v0.3.2:templates/AGENTS.md > old-template.md
diff old-template.md ~/projects/my-site/AGENTS.md      # fc on Windows
```

Keep the `## Project specifics` content and any custom rules you added; delete
everything the diff shows as unchanged template text. `templates/project.example.md`
shows the shape to aim for. If nothing is left, delete the file — the shared
rules still apply.

A copy with no version stamp predates v0.3.0; diff it against `v0.2.0` instead.

**3. Start a new session.** There is no file watcher, so a running session keeps
what it loaded.

Nothing breaks if you skip step 2 — you just pay for the duplicated text in
every session's context.

---

## Part 11 — Auto-updates (optional)

`check` fetches quietly, compares against the shared repo, and does nothing
when the checkout is already current. When there are new commits it says so
and offers to run the usual `update.bat` / `update.sh`:

```
check.bat           # Windows
./check.sh          # macOS / Linux
```

**Windows — check at every login:** `setup.bat` and `update.bat` set this up
for you automatically now, by running `enable-autoupdate.bat` as their last
step. It puts a shortcut to `check.bat` in your Startup folder, minimized so
it never takes the screen. At every login it opens and closes in the taskbar
unseen if there is nothing new; if there is an update, click the taskbar
entry to see the prompt. Remove it later: Win+R, type `shell:startup`,
delete `dsh-check-updates.lnk`. If you move the repo, run
`enable-autoupdate.bat` by hand once from the new location — `update.bat`
will also fix it on its next run there.

**macOS / Linux:** run `./check.sh` by hand — same check, no login hook. If you
prefer fully automatic updates with no prompt, schedule `update.sh` directly:

- macOS — a LaunchAgent whose `ProgramArguments` is
  `["/bin/bash", "/Users/YOU/dsh-setup/update.sh"]`.
- Linux — `crontab -e`, add `@weekly /home/YOU/dsh-setup/update.sh`

A silent run still skips when the tree has local changes, and new rules only
reach a session you start afterwards (Part 10, step 3). Prefer the prompted
`check` when you want to see what happened.

---

## Quick reference

**Startup order**

```powershell
# 1. dsh server
dsh web
# 2. Browser: http://127.0.0.1:3080
# 3. Open Figma Desktop
# 4. Ctrl+/ → run "Figma Desktop Bridge"
# 5. In dsh: New Session, select workspace, Standard mode
```

**Three things must be running together:** dsh server · Figma Desktop · bridge plugin window

**Commands**

```
dsh web                              # start
Ctrl+C (in the dsh window)           # stop
update.bat                           # update (repo + dsh + rules)
check.bat                            # check for updates, ask before updating
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh@0.1.2-rc.1   # update dsh only (not npm update — Part 9)
dir %USERPROFILE%\.figma-console-mcp\plugin   # check plugin files
```

**Paths**

```
%USERPROFILE%\.dsh\profiles\web\cordis.patch.yml   # dsh config
%USERPROFILE%\.dsh\.credentials.yaml               # API keys — PLAIN TEXT, never share
%USERPROFILE%\.dsh\AGENTS.md                       # shared agent rules — generated
%USERPROFILE%\.figma-console-mcp\plugin\manifest.json   # bridge plugin
<workspace>\AGENTS.md                            # that project's own rules
```
