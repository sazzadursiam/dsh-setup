<!-- Copy this to `local.md` in the repo root (it is git-ignored) and edit it.
     agents.sh / agents.bat append it to ~/.dsh/AGENTS.md, unchanged, after the
     core rules and your role blocks. It survives every update.

     This is the place for anything true of *your* machine or account that this
     repo cannot know: the providers you actually pay for, an internal proxy, a
     directory you keep outside your projects. The templates stay neutral so
     they are useful to everyone; this file is where you get specific.

     Do not put credentials here. It is a rules file, not a secret store, and
     it lands in ~/.dsh/AGENTS.md which is loaded into every session's context.

     Delete the example below - it describes one person's account, not yours. -->

## This machine

- Providers configured here: `anthropic`, `deepseek-official`, `qwen`.
  When escalating, reasonable targets are `claude-sonnet-5` (anthropic),
  `deepseek-v4-pro` (deepseek-official), `qwen3.5-397b-a17b` (qwen).
- `deepseek-v4-flash` and `deepseek-v4-pro` appear under **two** providers:
  `deepseek-official` (direct) and `qwen` (resold through Alibaba). Prefer
  `deepseek-official` — the resold copies lose the off-peak discount.
