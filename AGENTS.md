# Agent Instructions

Rules for any agent working in this workspace.

## Communication

Reply in Bengali. Write code, comments, commit messages, variable names, and
file names in English.

Be direct. Skip preamble and flattery. If you are unsure, say so instead of
guessing — a confident wrong answer costs more time than an honest "I don't know".

Keep explanations short. Show the command or the code, not a paragraph about
what the code will do.

## Before acting

Read before you write. Check what already exists in the workspace before
creating files — do not recreate something that is already there.

If a request is ambiguous in a way that changes the outcome, ask one question.
Do not ask about things you can determine by looking at the files. State
smaller assumptions inline as you work rather than stopping to confirm each one.

## Figma tooling

This workspace uses `figma-console-mcp` in **Local Mode** (stdio + WebSocket
Desktop Bridge plugin). Some tools in the exposed tool list do not work in this
mode. Follow these rules strictly.

### Never use these tools

- `figma_capture_screenshot`
- `figma_take_screenshot`

They depend on a Cloud Mode browser-rendering transport that does not exist in
Local Mode. They fail with `Cannot read properties of undefined (reading 'bytes')`,
and — more importantly — **a single failed call poisons the whole session**:
every following turn throws the same error even with no tool call, and the only
fix is starting a new session.

If you think a screenshot is needed, do not take one. Say so and move on.

### Do not display or download images

The client cannot render `image/png` inline (`unsupported content type`), and
shell downloads of Figma image URLs fail in this environment. So:

- Do not embed or inline images in your reply.
- Do not use PowerShell, curl, or any shell command to download exported images.
- If the user explicitly asks for an image export, call `figma_get_component_image`
  and **return the URL as plain text only**. Figma image URLs expire quickly.

### Visual verification is the user's job

The user has Figma Desktop open next to this chat and can see the canvas
directly. Do not try to verify your own work visually.

After a write operation, report only:

- what was created or changed
- the node id(s)
- the layer name(s)
- the page and position

### Before writing to Figma

- Call `figma_get_status` first to confirm which file the Desktop Bridge is
  connected to.
- `figma_navigate` takes a URL, not a file name. Use `figma_list_open_files`
  if you need to know what is open.
- If the bridge is not connected, stop and tell the user to run the
  **Figma Desktop Bridge** plugin in their file. Do not work around it.

## Design to code

When converting a Figma frame to code:

- Auto layout maps to flex/grid. If a frame uses absolute positioning, say so —
  the responsive result will be a guess, and the user may want to fix the
  design first.
- Use layer names to pick semantic HTML tags.
- Prefer design tokens over hardcoded values. Pull them with
  `figma_get_variables` and map them to config rather than inlining hex codes.
- Mobile-first. Do not invent breakpoint behaviour silently — if the design
  only exists at one width, state what you assumed for the others.

## Safety

Only modify files inside this workspace.

Before destructive operations — deleting files or layers, replacing variable
collections, force-pushing, rewriting git history — describe what you are about
to do and wait for confirmation.

Never write API keys, tokens, or passwords into files. If a secret is needed,
tell the user to set it as an environment variable.

Prefer small, reviewable changes over large rewrites. If a task needs many
files changed, outline the plan first.

## Project specifics

<!--
Fill this in per project. Examples of what belongs here:

- Stack: framework, package manager, TypeScript or JavaScript
- File structure conventions
- Naming conventions
- Libraries to use or avoid
- Test command, and whether to run it before reporting done
- Git workflow: branch naming, commit format

Leave it empty rather than filling it with guesses.
-->
