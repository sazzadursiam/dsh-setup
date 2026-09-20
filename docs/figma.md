# Figma integration (create / edit / read)

> Part 6 of the [setup guide](../SETUP.md). Install dsh first (Part 1, 2 or 3 there). `%USERPROFILE%` means your user folder — see the note at the top of the setup guide.

Create, edit and read Figma designs from your agent — all from dsh.

> **About platforms:** the commands below are written for Windows/cmd. **macOS** users: your platform setup is in [Part 2](../SETUP.md#part-2--macos-setup), **Linux** in [Part 3](../SETUP.md#part-3--linux-ubuntu-setup). The only difference is the command shell — `setx` vs `export`, `%USERPROFILE%` vs `~`, `Ctrl+/` vs `Cmd+/`. The token, scopes, config YAML and plugin import rules are **identical on every platform**.

## What does NOT work (don't waste time)

Figma's official remote MCP (`https://mcp.figma.com/mcp`) **will not run in dsh**. Because:

- Figma only accepts OAuth, not PATs
- Figma does not allow dynamic client registration — only pre-registered clients (VS Code, Cursor, Claude Code, Codex) can connect
- Trying with an OAuth-capable community plugin (dsh-mcp-manager) → `client registration failed: HTTP 403 Forbidden`
- Trying with the mcp-remote bridge → fails at the same point (`registerClient`, HTML error page instead of JSON)

## What works — figma-console-mcp (Local Mode)

Instead of climbing the OAuth wall, this goes around it. Figma's Plugin API has full write power, and it runs inside the desktop app where you are already signed in. A bridge plugin talks to the MCP server over a localhost WebSocket.

**125 tools, full read/write.** Because it uses the Plugin API, variables work on Free and Pro plans too.

## Step 1: Prerequisites

**Figma Desktop app** (not the browser — needed for importing the plugin). That's all.

> **Older versions needed the `dsh-mcp-manager` plugin.** Testing showed it is **not needed** — dsh's built-in MCP client is enough. The pnpm install, git-hosted plugin install and UI form-filling steps were all dropped.

## Step 2: Figma Personal Access Token

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

## Step 3: Set the Figma token

Once `dsh web` is running (Step 4 installs it, Step 5 below wires up the plugin): Settings → General → "Figma token" → paste it and save. No terminal needed — restart dsh afterward to use it. This writes the token in plain text into `~/.dsh/profiles/web/node_modules/dsh-figma-bridge/cordis.patch.yml` (see Secrets in `README.md`).

Changed your mind? The same row has a "Remove Figma integration" button — it uninstalls the plugin (and the saved token with it) and asks you to confirm first. Restart dsh afterward; add it back any time from Settings → General → "Add Figma integration".

By hand instead, in cmd:

```
setx FIGMA_ACCESS_TOKEN "figd_..."
setx ENABLE_MCP_APPS true
```

**Close cmd and open a new one**, then verify:

```
echo %FIGMA_ACCESS_TOKEN%
```

If the token prints, you are good. If `%FIGMA_ACCESS_TOKEN%` echoes back literally, it wasn't set.

**macOS/Linux:** use `export` instead of `setx` ([Part 2 Step 3](../SETUP.md#part-2--macos-setup) / [Part 3](../SETUP.md#part-3--linux-ubuntu-setup)):

```bash
export FIGMA_ACCESS_TOKEN="figd_..."
export ENABLE_MCP_APPS=true
```

The npx process inherits the system environment, so nothing extra needs to be written into the config.

## Step 4: Config file

If you use the team repo, `setup.bat` / `setup.sh` ask once whether to install
this (default: no, so a coding-only machine does not carry an extra MCP
server and 125 unused tools). Say yes there, or skip and add it later from
`dsh web` → Settings → General → "Add Figma integration" — no terminal
needed, `update.bat` / `update.sh` do not install it for you retroactively,
they only keep an already-installed copy in sync. By hand, from the repo
root:

```
dsh plugin --profile web add "file:%CD%\plugins\figma-bridge"
```

**macOS/Linux:**

```bash
dsh plugin --profile web add "file:$PWD/plugins/figma-bridge"
```

If that path contains a space, use `"""file:%CD%\plugins\figma-bridge"""`
instead — see `plugins/team-updater/README.md`'s Install section for why. A
path containing `(` or `)` cannot be used at all — pnpm rejects it with
"Mismatch parenthesis".

This installs `plugins/figma-bridge/cordis.patch.yml` — shown below for
reference — as a plugin bundle, not a copy pasted into your profile's own
config:

```yaml
- insert:
    - id: mcp-figma
      name: "@deepseek-ai/dsh-mcp-client"
      config:
        serverName: figma
        transport: stdio
        command: npx
        args: ["-y", "figma-console-mcp@1.40.0"]
```

The version is pinned for the same reason dsh is: with `@latest`, every machine
runs a new release the moment it is published. `update.bat` / `update.sh` keep
an already-installed profile's copy in step with this repo's pin, changing
only the version (`plugins/figma-bridge/lib/pin.js`).

**If `dsh plugin add` fails** (no web profile yet, no pnpm, or a checkout path
with a bracket), the command above prints why. As a last-resort fallback you
can still hand-edit the profile's own config: open
`%USERPROFILE%\.dsh\profiles\web\cordis.patch.yml` (**macOS/Linux:**
`~/.dsh/profiles/web/cordis.patch.yml`) and, if it only contains `[]`, replace
that with the YAML block above (keep the comment lines already in the file).
**Keep the indentation exact** — YAML is strict about spaces, no tabs. A
hand-edited entry like this won't be plugin-managed, so `verify` will flag it
and `update` will migrate it into the plugin automatically next time it runs.

Save, then restart dsh. In the window where `dsh web` is running press **Ctrl+C**, then start it again:

```
dsh web
```

(Config changes don't apply without a restart. If Ctrl+C doesn't work — dsh is stuck — then use `taskkill /IM node.exe /F`; see [Part 4](../SETUP.md#part-4--what-not-to-do).)

## Step 5: Import the bridge plugin

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

## Requirements to keep it running

Three things must be running together:

1. **dsh server**
2. **Figma Desktop**
3. **Bridge plugin window**

If any one stops, the write tools won't work. Move the plugin window to a corner of the canvas.

The session must be in **Standard or Code mode** — Minimal mode doesn't show MCP tools.

## Important: the screenshot tools are broken

`figma_capture_screenshot` and `figma_take_screenshot` do not work in this setup — `Cannot read properties of undefined (reading 'bytes')`.

**Why:** Local Mode used to have a Chrome DevTools Protocol transport and screenshots went through that. The developer removed it — the WebSocket bridge is now the only local path. But the screenshot/navigate/console tools still depend on Cloud Mode's browser rendering. So there is no code path in Local Mode at all.

**No fix.** Launching Figma with `--remote-debugging-port=9222` doesn't help either — that code is gone. It might return in the future — because `@latest` is used, updates arrive on their own.

**The biggest danger:** one failed call poisons the whole session. After that, every turn throws the same error even with no tool call. There is no recovery — you must open a **New Session**.

**Solution:** the `figma` role block in `~/.dsh/AGENTS.md` (see [Project setup and workflow](workflow.md)). If the rules are loaded, the agent won't touch these tools. Check with `agents.sh --show` that `figma` is one of your roles.

## About viewing images

dsh cannot render inline images (`unsupported content type "image/png"`), and shell downloads of Figma image URLs also fail in this environment.

So don't put visual verification on the agent. **Figma Desktop is open right next to you — glance at it.** That's the fastest option and nothing can break.

If you really need it, get a URL from `figma_get_component_image` and open it in your browser. The URL expires quickly.

## Test

```
Run figma_diagnose and show the connection status
```

```
In the Test AI file, make a 200x100 blue rectangle. No screenshot.
```

If it appears on the canvas, everything works.

## Caution

**Work in a test file, not a real project file.** The agent can write to Figma, so it can also make mistakes — and Figma's undo history doesn't always play well with the agent's large operations.

---

[← Back to the setup guide](../SETUP.md)
