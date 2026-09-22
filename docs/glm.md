# GLM (Z.AI) — a second model alongside DeepSeek

> Part of [Step 4: API key](../SETUP.md#step-4-api-key) in the main setup guide. Install dsh first (Part 1, 2 or 3 there).

DeepSeek is the default coding model (Part 1 Step 4). Z.AI's GLM family is a
useful second option — teams that split by task (e.g. coding on DeepSeek,
UI/design reasoning on GLM) add it as a second provider the same way they'd
add Anthropic.

## Step 1: Z.AI API key

Get a key from https://z.ai (API keys / developer console). It starts with a
long alphanumeric string, not `sk-`.

## Step 2: Add the provider

`dsh web` → Settings → Models → **Add provider** → Z.AI → paste the key. Model
list, endpoint and protocol come automatically, the same as Anthropic (Part 1
Step 4). Saved to `~/.dsh/.credentials.yaml` — same plain-text-storage warning
as every other provider key there.

## Step 3: Required extra setting — do not skip this

**Every GLM model (4.7 through 5.3-highspeed) always reasons; it cannot be
told not to.** Without an extra setting, dsh's default request tells it to
turn reasoning off, and the call fails outright:

```
dsh: INVALID_REQUEST: 400: {"code":"1210","message":"This model always
engages in thinking and cannot be disabled; please use low, high, or max"}
```

Fix: open `~/.dsh/settings.yaml` (Windows: `%USERPROFILE%\.dsh\settings.yaml`)
and add `reasoning: low` under the `zai:` provider block (sibling of
`apiKeyEnv:`/`models:`, not inside a model entry):

```yaml
llm-pi-ai:
  providers:
    zai:
      reasoning: low        # <-- add this line
      apiKeyEnv: ZAI_API_KEY
      models:
        - id: glm-5.3
          name: GLM-5.3
          ...
```

`low` is cheapest; `high`/`max` also work if you want GLM to think harder by
default. This is a `~/.dsh/settings.yaml`-only setting — there is no field for
it in the Settings UI. settings.yaml is hot-reloaded; a **new dsh session**
picks it up, no restart needed.

Verified 2026-09-22 against `@deepseek-ai/dsh@0.1.2-rc.1`: the failing request
and the fix were both reproduced directly (`dsh --profile headless "..."`),
and traced to `zai.json`'s `"reasoning": true` flag being set on every GLM
model in dsh's bundled catalog — pi-ai's zai-compat code sends
`thinking: {type: "disabled"}` whenever no reasoning effort is supplied, and
GLM rejects that. `reasoning: low` at the provider level supplies a default
so this path is never hit.

## Step 4: Test

```bash
dsh --profile headless "What is 3+3? Reply with just the number."
```

with `agent-default-model` (or a session's model picker) pointed at a `zai`
GLM id. `6` back with no error confirms the setup.
