# DeepSeek Harness (dsh) — Local Setup Guide

**Created:** September 2026
**Environment:** Windows · macOS · Linux/Ubuntu (macOS instructions: Part 2; Linux Figma limitations: Part 3)
**Status:** dsh is still a developer preview — breaking changes may arrive

> **About paths:** In this document `%USERPROFILE%` means your user folder (e.g. `C:\Users\AC`). In **cmd** it works as-is, and pasting it into a Windows file dialog opens the location too. In **PowerShell** replace it with `$env:USERPROFILE`. On **macOS/Linux** use `~` (your home folder, e.g. `/Users/AC`) instead — `%USERPROFILE%\.dsh` = `~/.dsh`.

> **What you must do by hand on each machine:** Anthropic API key, Figma PAT, sign in to Figma Desktop, import the bridge plugin, select a workspace. Everything else happens by running commands.

**Contents**

- [What dsh is](#what-dsh-is)
- [Part 1 — Windows setup](#part-1--windows-setup)
- [Part 2 — macOS setup](#part-2--macos-setup)
- [Part 3 — Linux (Ubuntu) setup](#part-3--linux-ubuntu-setup)
- [Part 4 — What not to do](#part-4--what-not-to-do)
- [Part 5 — Safe usage rules](#part-5--safe-usage-rules)
- [Part 6 — Figma integration (create / edit / read)](#part-6--figma-integration-create--edit--read)
- [Part 7 — Project setup and workflow](#part-7--project-setup-and-workflow)
- [Part 8 — Troubleshooting](#part-8--troubleshooting)
- [Part 9 — New-PC setup checklist](#part-9--new-pc-setup-checklist)
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

Git is needed to clone this repo, and again in Part 7 — `git init` per project is
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
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
```

The `--allow-scripts` part is essential. `node-pty` and `koffi` compile native binaries in an install script, and the shell/terminal tools do not work without them. **Do not remove it** — npm will not run a dependency's install scripts unless that package is allowlisted, so the native modules are silently never built (error: `Failed to load native module`).

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
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
```

The `--allow-scripts` part is essential — Part 1 Step 2 explains why.

### Step 3: Environment variable

Append to the end of `~/.zshrc` (zsh is macOS's default shell):

```bash
export FIGMA_ACCESS_TOKEN="figd_..."
export ENABLE_MCP_APPS=true
```

Then verify with `source ~/.zshrc` (or a new terminal):

```bash
echo $FIGMA_ACCESS_TOKEN
```

### Step 4: API key

`dsh web` → `http://127.0.0.1:3080` → Settings → Models → add the Anthropic key. Keys are stored in `~/.dsh/.credentials.yaml` **in plain text** — see the warning in Part 1 Step 4.

### Step 5: Copy the config

```bash
mkdir -p ~/.dsh/profiles/web
cp cordis.patch.yml ~/.dsh/profiles/web/
```

If that file already has entries, merge by hand instead of overwriting (Part 6 Step 4).

### Step 6: Import the bridge plugin

The server creates the plugin files when it starts. Verify:

```bash
ls ~/.figma-console-mcp/plugin
```

`manifest.json`, `code.js`, `ui.html` should be there. Then, with a file open in Figma Desktop, press **`Cmd+/`** → type `import` → **Import plugin from manifest…** → pick `~/.figma-console-mcp/plugin/manifest.json`. Then run **Figma Desktop Bridge** — you should see a green **Connected** status.

(Full detail: Part 6. Where it says `%USERPROFILE%` and `setx`, read `~` and `export`.)

### Verify

```bash
./verify.sh
```

If everything is green the setup is done. Don't forget to copy `templates/AGENTS.md` into each project (Part 7).

---

## Part 3 — Linux (Ubuntu) setup

On Linux, dsh and coding work fully, but there is **no Figma write** — Figma Desktop does not exist on Linux, so the Desktop Bridge plugin cannot be imported. Figma read (via PAT) works.

You need a separate Node (the distro-bundled one is often old):

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install --lts
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
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

Create, edit and read Figma designs from your agent — all from dsh.

> **About platforms:** the commands below are written for Windows/cmd. **macOS** users: your platform setup is in Part 2, **Linux** in Part 3. The only difference is the command shell — `setx` vs `export`, `%USERPROFILE%` vs `~`, `Ctrl+/` vs `Cmd+/`. The token, scopes, config YAML and plugin import rules are **identical on every platform**.

### What does NOT work (don't waste time)

Figma's official remote MCP (`https://mcp.figma.com/mcp`) **will not run in dsh**. Because:

- Figma only accepts OAuth, not PATs
- Figma does not allow dynamic client registration — only pre-registered clients (VS Code, Cursor, Claude Code, Codex) can connect
- Trying with an OAuth-capable community plugin (dsh-mcp-manager) → `client registration failed: HTTP 403 Forbidden`
- Trying with the mcp-remote bridge → fails at the same point (`registerClient`, HTML error page instead of JSON)

### What works — figma-console-mcp (Local Mode)

Instead of climbing the OAuth wall, this goes around it. Figma's Plugin API has full write power, and it runs inside the desktop app where you are already signed in. A bridge plugin talks to the MCP server over a localhost WebSocket.

**125 tools, full read/write.** Because it uses the Plugin API, variables work on Free and Pro plans too.

### Step 1: Prerequisites

**Figma Desktop app** (not the browser — needed for importing the plugin). That's all.

> **Older versions needed the `dsh-mcp-manager` plugin.** Testing showed it is **not needed** — dsh's built-in MCP client is enough. The pnpm install, git-hosted plugin install and UI form-filling steps were all dropped.

### Step 2: Figma Personal Access Token

figma.com → profile → Settings → Security → Personal access tokens → Generate new token

Any expiration is fine (90 days is fine). Tick the scopes in the order Figma's screen shows them:

| Section           | Scope                        |
| ----------------- | ---------------------------- |
| **Users**         | ✅ `current_user:read`       |
| **Files**         | ✅ `file_comments:read`      |
|                   | ✅ `file_comments:write`     |
|                   | ✅ `file_content:read`       |
|                   | ✅ `file_metadata:read`      |
|                   | ✅ `file_versions:read`      |
| **Design systems**| ✅ `library_assets:read`     |
|                   | ✅ `library_content:read`    |
|                   | ✅ `team_library_content:read` |
| **Development**   | ✅ `file_dev_resources:read` |
|                   | ✅ `file_dev_resources:write`|
| **Folders**       | ✅ `folders:read`            |
| **Webhooks**      | ❌ skip both — not needed    |

REST does have `file_variables:read` / `file_variables:write` scopes for variables, but they are **limited to Enterprise plans** — don't tick them here. In this setup variables are read and written through the Plugin API (the bridge plugin), not REST — that is why it works on Free/Pro plans too.

The token starts with `figd_` and is **shown only once** — copy it immediately.

> **To avoid scope confusion:** the token's write scopes are only for comments and dev resources (the ✅ ones in the table). **Design content** (frame, layer, component, variable) cannot be created or changed over REST at all — that is the bridge plugin's (Plugin API) job. So the plugin is what gives you design-write power, not the token.

**Never put the token in a file or screenshot.** If it leaks, revoke it immediately at figma.com → Settings → Security and issue a new one.

### Step 3: Set the environment variable

In cmd:

```
setx FIGMA_ACCESS_TOKEN "figd_..."
setx ENABLE_MCP_APPS true
```

**Close cmd and open a new one**, then verify:

```
echo %FIGMA_ACCESS_TOKEN%
```

If the token prints, you are good. If `%FIGMA_ACCESS_TOKEN%` echoes back literally, it wasn't set.

**macOS/Linux:** use `export` instead of `setx` (Part 2 Step 3 / Part 3):

```bash
export FIGMA_ACCESS_TOKEN="figd_..."
export ENABLE_MCP_APPS=true
```

The npx process inherits the system environment, so nothing extra needs to be written into the config.

### Step 4: Config file

If you use the team repo, the easy path — just copy:

```
mkdir "%USERPROFILE%\.dsh\profiles\web" 2>nul
copy cordis.patch.yml "%USERPROFILE%\.dsh\profiles\web\"
```

**macOS/Linux:**

```bash
mkdir -p ~/.dsh/profiles/web
cp cordis.patch.yml ~/.dsh/profiles/web/
```

**If that file already has entries, don't overwrite it** — merge by hand.

To do it by hand:

```
notepad %USERPROFILE%\.dsh\profiles\web\cordis.patch.yml
```

**macOS/Linux:** `nano ~/.dsh/profiles/web/cordis.patch.yml` (or any editor).

If the file only contains `[]`, delete that and paste the following (keep the comment lines above):

```yaml
- insert:
    - id: mcp-figma
      name: "@deepseek-ai/dsh-mcp-client"
      config:
        serverName: figma
        transport: stdio
        command: npx
        args: ["-y", "figma-console-mcp@latest"]
```

**Keep the indentation exact** — YAML is strict about spaces, no tabs.

Save, then restart dsh. In the window where `dsh web` is running press **Ctrl+C**, then start it again:

```
dsh web
```

(Config changes don't apply without a restart. If Ctrl+C doesn't work — dsh is stuck — then use `taskkill /IM node.exe /F`; see Part 4.)

### Step 5: Import the bridge plugin

The server creates the plugin files when it starts. Verify:

```
dir %USERPROFILE%\.figma-console-mcp\plugin
```

**macOS/Linux:** `ls ~/.figma-console-mcp/plugin`

`manifest.json`, `code.js`, `ui.html` should be there.

With a file open in Figma Desktop, press **`Ctrl+/`** (**macOS: `Cmd+/`**) → type `import` → choose **Import plugin from manifest…**.

(That option is not in the Tools panel's Create menu — that menu is for making new plugins. Quick actions are the only reliable path.)

Path:

```
%USERPROFILE%\.figma-console-mcp\plugin\manifest.json
```

**macOS/Linux:** `~/.figma-console-mcp/plugin/manifest.json`

After importing, run **Figma Desktop Bridge**. The plugin window shows green **Connected — Connected to 1 AI app**. Importing once is enough.

### Requirements to keep it running

Three things must be running together:

1. **dsh server**
2. **Figma Desktop**
3. **Bridge plugin window**

If any one stops, the write tools won't work. Move the plugin window to a corner of the canvas.

The session must be in **Standard or Code mode** — Minimal mode doesn't show MCP tools.

### Important: the screenshot tools are broken

`figma_capture_screenshot` and `figma_take_screenshot` do not work in this setup — `Cannot read properties of undefined (reading 'bytes')`.

**Why:** Local Mode used to have a Chrome DevTools Protocol transport and screenshots went through that. The developer removed it — the WebSocket bridge is now the only local path. But the screenshot/navigate/console tools still depend on Cloud Mode's browser rendering. So there is no code path in Local Mode at all.

**No fix.** Launching Figma with `--remote-debugging-port=9222` doesn't help either — that code is gone. It might return in the future — because `@latest` is used, updates arrive on their own.

**The biggest danger:** one failed call poisons the whole session. After that, every turn throws the same error even with no tool call. There is no recovery — you must open a **New Session**.

**Solution:** put `AGENTS.md` in the workspace (see Part 7). If the rules are there, the agent won't touch these tools.

### About viewing images

dsh cannot render inline images (`unsupported content type "image/png"`), and shell downloads of Figma image URLs also fail in this environment.

So don't put visual verification on the agent. **Figma Desktop is open right next to you — glance at it.** That's the fastest option and nothing can break.

If you really need it, get a URL from `figma_get_component_image` and open it in your browser. The URL expires quickly.

### Test

```
Run figma_diagnose and show the connection status
```

```
In the Test AI file, make a 200x100 blue rectangle. No screenshot.
```

If it appears on the canvas, everything works.

### Caution

**Work in a test file, not a real project file.** The agent can write to Figma, so it can also make mistakes — and Figma's undo history doesn't always play well with the agent's large operations.

---

## Part 7 — Project setup and workflow

### What to do per project

**Windows** (cmd):

```
mkdir %USERPROFILE%\projects\my-site
cd %USERPROFILE%\projects\my-site
git init
copy %USERPROFILE%\dsh-setup\templates\AGENTS.md .
REM The path above assumes the dsh-setup repo was cloned into %USERPROFILE%. Change it if you cloned elsewhere.
```

**macOS/Linux:**

```bash
mkdir -p ~/projects/my-site
cd ~/projects/my-site
git init
cp ~/dsh-setup/templates/AGENTS.md .
# The path above assumes the dsh-setup repo was cloned into your home folder. Change it if you cloned elsewhere.
```

Then, in the dsh UI, use **Choose workspace** to add and select the folder. No server restart needed.

**Do run `git init`.** The agent will modify files and occasionally make mistakes. `git diff` shows what changed, and you can revert if it went wrong.

### AGENTS.md

Putting `AGENTS.md` in the workspace makes the agent read it at session start. It's the most effective way to keep it away from the broken Figma tools — no need to remind it by hand every session.

**You need a separate copy per project** — it's workspace-based, not global.

### Keeping copies up to date

Because each project holds its own copy, `git pull` in this repo updates
`templates/AGENTS.md` but **not** the copies already sitting in your projects.

The template carries a version stamp on its first line, and the verifier compares
it against a project's copy:

```
verify.bat C:\Users\me\projects\my-site
./verify.sh ~/projects/my-site
```

It reports `AGENTS.md is v0.2.0 but the template is v0.3.0` when a copy has
fallen behind.

**Do not fix that by overwriting the file.** Everything you wrote under
`## Project specifics` would be lost. Diff the two and copy across only the
sections that changed:

```
fc "my-site\AGENTS.md" "templates\AGENTS.md"     REM Windows
diff ~/projects/my-site/AGENTS.md templates/AGENTS.md
```

Then start a **new session** — a running one keeps the copy it loaded.

The rules the file should contain:

- never use `figma_capture_screenshot` / `figma_take_screenshot`, and why (it ruins the session)
- don't inline images or download them via the shell
- visual verification is the user's job; the agent only reports node ids, layer names, positions
- call `figma_get_status` to verify the active file before writing
- `figma_navigate` takes a URL, not a file name
- ask permission before destructive actions

Write the **reason** alongside each rule. When the agent knows why, it follows the rule more and doesn't look for loopholes.

### About sessions

**A fresh session per task.** Context stays clean, costs stay down, and one task's mistake doesn't bleed into the next.

Changing AGENTS.md requires a new session — a running session keeps the old copy.

Run in **Standard or Code** mode — Minimal mode doesn't show MCP tools (detail: Part 6, "Requirements to keep it running").

### Figma → code

**1.** Select a frame in Figma Desktop
**2.** Make sure the Desktop Bridge plugin is running (green Connected)
**3.** In a new dsh session, say:

```
Read the frame currently selected in Figma and build responsive HTML + Tailwind.
- First verify the connection with figma_get_status
- Semantic HTML, mobile-first, sm/md/lg breakpoints
- Build an index.html with the Tailwind CDN
- At the end, report what you created
```

**4.** Open it in your browser: `start index.html`
**5.** Keep refining in the same session

If it can't grab the selected node, right-click the layer in Figma → **Copy link to selection**, and give it the URL's `node-id`.

### For better results

**Use auto layout** — this makes the biggest difference. Auto layout translates straight to flex/grid. With absolutely-positioned designs the agent will guess the responsive behavior.

**Keep layer names meaningful** — not `Frame 47` but `header`, `card-grid`, `cta-button`. The agent picks semantic tags from the names.

**Pull tokens first** — before big work, run `figma_get_variables` once to build `tailwind.config.js`, then do components one by one. Asking for everything at once lowers quality.

**Keep frames at multiple breakpoints** — Figma designs usually exist at one size, so responsive behavior is the agent's guess. Showing both a desktop and a mobile frame gives much better results.

### What not to expect

Pixel-perfect output on the first try. Figma's layout model and CSS's model aren't the same — text rendering, shadows and nested constraints will differ. Expect several rounds of refinement; that's normal.

---

## Part 8 — Troubleshooting

**If something doesn't work, run the verifier first** — it tells you directly which piece is missing:

```
verify.bat          # Windows
./verify.sh         # macOS / Linux
```

> **Note (Windows):** running verify in the **same window** after `setx` shows a false `[FAIL]` on `FIGMA_ACCESS_TOKEN` — `setx` only affects new terminals. Close the window, open a new cmd, and run it again.

Pass a project folder to also check whether its `AGENTS.md` has fallen behind
the template — worth doing when the agent ignores a rule you know you wrote:

```
verify.bat C:\Users\me\projects\my-site
./verify.sh ~/projects/my-site
```

Then use the table below.

| Problem                                                                    | Solution                                                                                                                                                             |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `'node' is not recognized`                                                 | Restart the terminal. If that fails: `$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")` |
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
| Can't get the Figma token                                                  | Check that you started dsh from a new cmd after `setx`                                                                                                               |
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
- [ ] `npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh`

**dsh config**

- [ ] `dsh web` → `http://127.0.0.1:3080` → Settings → Models → add the Anthropic key
- [ ] `setx FIGMA_ACCESS_TOKEN "figd_..."` and `setx ENABLE_MCP_APPS true`
- [ ] Open a **new cmd** and verify `echo %FIGMA_ACCESS_TOKEN%`
- [ ] Copy the repo's `cordis.patch.yml` to `%USERPROFILE%\.dsh\profiles\web\` (Part 6 Step 4)
- [ ] Restart dsh → `figma_get_status` works in the session

**Figma bridge**

- [ ] `dir %USERPROFILE%\.figma-console-mcp\plugin` → manifest.json present
- [ ] In Figma Desktop `Ctrl+/` → `import` → Import plugin from manifest…
- [ ] Run the plugin → green **Connected — Connected to 1 AI app**

**Project**

- [ ] Create a folder, `git init`, copy `templates/AGENTS.md`
- [ ] Add and select it via Choose workspace in dsh
- [ ] New Session, Standard mode → test with `figma_diagnose`

### What can be shared

- **Figma PAT** — make one and use it on every PC. When it expires you must change it everywhere.
- **AGENTS.md** — just copy it.

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

That pulls this repo, runs the install command below, and flags any project
whose `AGENTS.md` has fallen behind. To update only the npm package:

```powershell
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
```

**Don't use `npm update -g`** — it doesn't re-apply the `--allow-scripts` allowlist, so the native modules (node-pty, koffi) are left unbuilt (`Cannot find module` / `.node file not found` error — see Part 8). The install command above is the correct way to update, and running it repeatedly is safe — if you're already on the latest it changes nothing.

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
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh   # update (not npm update — Part 9)
dir %USERPROFILE%\.figma-console-mcp\plugin   # check plugin files
```

**Paths**

```
%USERPROFILE%\.dsh\profiles\web\cordis.patch.yml   # dsh config
%USERPROFILE%\.dsh\.credentials.yaml               # API keys — PLAIN TEXT, never share
%USERPROFILE%\.figma-console-mcp\plugin\manifest.json   # bridge plugin
<workspace>\AGENTS.md                            # agent rules
```
