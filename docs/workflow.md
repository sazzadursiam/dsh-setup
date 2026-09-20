# Project setup and workflow

> Part 7 of the [setup guide](../SETUP.md). Do this once dsh is installed and running.

## What to do per project

**Windows** (cmd):

```
mkdir %USERPROFILE%\projects\my-site
cd %USERPROFILE%\projects\my-site
git init
```

**macOS/Linux:**

```bash
mkdir -p ~/projects/my-site
cd ~/projects/my-site
git init
```

Then, in the dsh UI, use **Choose workspace** to add and select the folder. No server restart needed.

**Do run `git init`.** The agent will modify files and occasionally make mistakes. `git diff` shows what changed, and you can revert if it went wrong. It also marks the project root, which is how dsh finds your instruction files.

Nothing else to copy. The shared rules are already loaded from
`~/.dsh/AGENTS.md` (next section).

## Where agent rules live

dsh loads instruction files in this order, broad to specific, at the start of
every session — later ones win:

| File | Scope | Who maintains it |
| --- | --- | --- |
| `~/.dsh/AGENTS.md` | every project on this machine | `agents.sh` / `agents.bat`, from this repo |
| `<project>/AGENTS.md` | that project | you, committed to that project's repo |

**The shared file is generated, so never edit it by hand** — the next update
overwrites it (it saves a `.bak` if it does not recognise the file). Change the
rules at the source instead, in `templates/core.md` or `templates/roles/*.md`,
then re-run `agents.sh`.

```
agents.bat --show                          # what is installed
agents.bat --role=figma,design-to-code     # change which role blocks you get
agents.bat --lang=Bengali                  # fixed reply language
```

Roles exist so a machine used for artwork is not reading Figma tool rules at the
start of every session: `figma`, `design-to-code`, `visual-assets`. You pick once
and it is remembered.

**Language** defaults to English. Pass `--lang` for anything else — handy if you
type in a romanised form but want replies in the script. It is remembered too.
In `agents.bat` it takes the rest of the line, so put it last.

**For anything specific to your machine or account** — the providers you
actually have, an internal proxy, a scratch folder outside your projects — copy
`templates/local.example.md` to `local.md` in the repo root. It is git-ignored,
appended to `~/.dsh/AGENTS.md` verbatim, and survives every update. Keep the
templates neutral and put the specifics there. Not credentials — it is loaded
into every session.

**Per-project rules go in the project's own `AGENTS.md`.** Start from
`templates/project.example.md`. Keep it short — it is read every session — and
put only what an agent would otherwise get wrong: the test command, a directory
that must not be hand-edited, a library to avoid.

A rule that a *project* must obey belongs in the project file, not the global
one. The global file is per-machine and does not travel with a `git clone`, so a
teammate who has not run this setup would not have it.

Whichever file a rule lands in, write the **reason** next to it. When the agent
knows why, it follows the rule more and doesn't look for loopholes. That is why
the Figma block spells out that one bad screenshot call poisons the session.

## About sessions

**A fresh session per task.** Context stays clean, costs stay down, and one task's mistake doesn't bleed into the next.

Changing AGENTS.md requires a new session — a running session keeps the old copy.

Run in **Standard or Code** mode — Minimal mode doesn't show MCP tools (detail: [Figma integration](figma.md#requirements-to-keep-it-running)).

## Figma → code

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

## For better results

**Use auto layout** — this makes the biggest difference. Auto layout translates straight to flex/grid. With absolutely-positioned designs the agent will guess the responsive behavior.

**Keep layer names meaningful** — not `Frame 47` but `header`, `card-grid`, `cta-button`. The agent picks semantic tags from the names.

**Pull tokens first** — before big work, run `figma_get_variables` once to build `tailwind.config.js`, then do components one by one. Asking for everything at once lowers quality.

**Keep frames at multiple breakpoints** — Figma designs usually exist at one size, so responsive behavior is the agent's guess. Showing both a desktop and a mobile frame gives much better results.

## What not to expect

Pixel-perfect output on the first try. Figma's layout model and CSS's model aren't the same — text rendering, shadows and nested constraints will differ. Expect several rounds of refinement; that's normal.

---

[← Back to the setup guide](../SETUP.md)
