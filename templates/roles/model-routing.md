## Model routing — LiteLLM smart-router

When a `smart-router` virtual model is available (a local LiteLLM proxy that
picks a tier model per turn):

- `session_affinity` is inert for dsh traffic — dsh sends no session id, so
  the router can pick a different model every turn even within one session.
- Keep steady coding sessions on a fixed model. Only route research or
  mixed-difficulty sessions through `smart-router` — otherwise a task can
  bounce between models turn to turn and bust the prompt cache for no
  benefit.
- The router scores keywords, not real difficulty. A hard request phrased as
  short plain prose can land on a cheaper tier than it needs; don't treat the
  tier it picked as a difficulty judgement.
