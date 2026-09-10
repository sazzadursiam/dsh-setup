# templates/

`agents.sh` / `agents.bat` assemble these into `~/.dsh/AGENTS.md`, the file dsh
loads into every session of every project.

| File | Role |
| --- | --- |
| `core.md` | The shared rules. Applied on every machine, every project. |
| `roles/<slug>.md` | An optional rule block. Loaded only if the machine's roles include `<slug>`. |
| `roles/index.txt` | The list of roles the scripts offer — `<slug>|<description>`, one per line. |
| `project.example.md` | Copied by a user into a project as its own `AGENTS.md`. Not read by the scripts. |
| `local.example.md` | Copied by a user to `local.md` in the repo root for machine-specific rules. |

## Editing the rules

- **`core.md` starts mid-section.** The scripts write the `# Agent Instructions`
  title, the intro, the `## Communication` heading and the `Reply in <language>`
  line — the language is a per-machine setting (`--lang`), so it cannot be baked
  in here. `core.md` picks up from `Be direct` inside that same section.
- **Keep `core.md` and the role files provider- and person-neutral.** No
  languages, no account-specific model names, no "I prefer X". Anything like that
  belongs in a user's `local.md`, which is appended verbatim and never shipped.
- **`## Project specifics` does not appear here.** That lived in the old
  monolithic template; it now belongs only in a project's own `AGENTS.md`.

## Adding a role

1. Write `roles/<slug>.md` — a single `## Heading` section, provider-neutral.
2. Add one line to `roles/index.txt`: `<slug>|<one-line description>`.

No script changes. Bump `VERSION` if the change should prompt existing installs
to regenerate.

## Budget

dsh's default instruction budget is 65536 bytes for the whole rendered baseline
(user-global + project chain). `core.md` plus every role is well under 8 KB, so
there is comfortable headroom — but broader files are dropped before the most
specific one is truncated, so keep role files tight.
