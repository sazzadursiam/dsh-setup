## Figma tooling

This machine uses `figma-console-mcp` in **Local Mode** (stdio + WebSocket
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

### Image exports

If the user explicitly asks for an image export, call
`figma_get_component_image` and **return the URL as plain text only** — never
try to fetch or display it. Figma image URLs expire quickly. See "Images and
visual checking" above.

### Before writing to Figma

- Call `figma_get_status` first to confirm which file the Desktop Bridge is
  connected to.
- `figma_navigate` takes a URL, not a file name. Use `figma_list_open_files`
  if you need to know what is open.
- If the bridge is not connected, stop and tell the user to run the
  **Figma Desktop Bridge** plugin in their file. Do not work around it.

After a write, report the node id(s), the layer name(s), and the page and
position — not how it looks.
