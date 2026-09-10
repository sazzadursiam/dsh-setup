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
