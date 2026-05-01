# 023 — statusline extra session-state items

## Intent

The Claude Code statusline JSON payload carries several session-state
fields that the current item list never surfaces:

- `effort.level` — reasoning-effort setting (`low` / `medium` / `high`
  / `xhigh` / `max`), present only when the active model supports it.
- `output_style.name` — active output style (e.g. `Explanatory`,
  `Learning`), present whenever the user has set a non-default style.
- `thinking.enabled` — whether extended thinking is on for this session.
- `vim.mode` — current vim-editor mode (`INSERT` / `NORMAL` / `VISUAL`
  / `VISUAL LINE`), present only when vim mode is enabled.

None of these fields appears in any current item emitter. Users have no
way to glance at effort level, style, or vim mode from the statusline.

This spec adds four new item emitters and extends `extract_fields` to
parse the new fields. Canonical order and priority levels follow the
spec-021 model.

## Acceptance criteria

### New globals in `data.sh`

`extract_fields` populates four new globals from the JSON payload:

- `effort_level` — `jq -r '.effort.level // empty'`. Empty when the
  field is absent (model does not support reasoning effort).
- `output_style_name` — `jq -r '.output_style.name // empty'`. Empty
  when absent or when the name is `default` (case-insensitive).
- `thinking_enabled` — `jq -r '.thinking.enabled // empty'`. Empty
  when absent; `true` when extended thinking is on.
- `vim_mode` — `jq -r '.vim.mode // empty'`. Empty when absent.

### New item emitters in `items.sh`

Four new `emit_*` functions, each a no-op when its governing global is
empty (or, for `output_style`, when the name is `default`):

#### `emit_effort`

- Condition: `[[ -n "${effort_level}" ]]`
- Label: `✦ effort:<level>` where `<level>` is the raw string.
- Visible width: 2 (emoji) + 1 (space) + 7 (`effort:`) + `${#effort_level}`.
- Color: green for `low`; yellow for `medium`; orange for `high`;
  red for `xhigh` and `max`. Applies only to the level word, not the
  `effort:` prefix.
- Priority: **2** (useful — affects API cost and response speed).

#### `emit_output_style`

- Condition: `[[ -n "${output_style_name}" ]]` and
  `[[ "${output_style_name,,}" != "default" ]]`
- Label: `✎ <name>` where `<name>` is the style name as received.
- Visible width: 2 (emoji) + 1 (space) + `${#output_style_name}`.
- No extra colour beyond the default dim rendering.
- Priority: **3** (nice-to-have).

#### `emit_thinking`

- Condition: `[[ "${thinking_enabled}" == "true" ]]`
- Label: `💭 thinking`.
- Visible width: 2 (emoji) + 1 (space) + 8 (`thinking`).
- Priority: **3** (nice-to-have).

#### `emit_vim_mode`

- Condition: `[[ -n "${vim_mode}" ]]`
- Label: `VIM:<mode>` in bold, where `<mode>` is upper-cased.
- Visible width: 4 (`VIM:`) + `${#vim_mode}`.
- Color: green for `INSERT`; yellow for `NORMAL`; magenta for `VISUAL`
  and `VISUAL LINE`.
- Priority: **1** (important — signals to the user that keystrokes are
  interpreted differently).

### Canonical order in `emit_all`

The four new calls are inserted into `emit_all` immediately after
the existing items they relate to contextually:

- `emit_effort` — after `emit_version` (both are model/session metadata).
- `emit_output_style` — after `emit_effort`.
- `emit_thinking` — after `emit_output_style`.
- `emit_vim_mode` — after `emit_model` (vim mode modifies input at the
  top level, warranting placement near the model badge).

The resulting canonical order for the affected region:

```
model · vim_mode · folder · … · version · effort · output_style · thinking · …
```

### Tests (`tests/test_smoke.sh`)

New `[claude statusline (spec 023)]` block:

Structural:

- `extract_fields` in `data.sh` reads `.effort.level`, `.output_style.name`,
  `.thinking.enabled`, and `.vim.mode`.
- `emit_effort`, `emit_output_style`, `emit_thinking`, and `emit_vim_mode`
  are all defined in `items.sh`.
- `emit_effort` references the `✦` symbol.
- `emit_vim_mode` references `VIM:`.
- `emit_all` calls all four new emitters.

Behavioural (require `bash` and `jq`):

- Feed a fixture JSON with `effort.level = "xhigh"`, `output_style.name
  = "Explanatory"`, `thinking.enabled = true`, and `vim.mode = "INSERT"`;
  set `CLAUDE_STATUSLINE_COLS=300`. The combined output must contain
  each of: `effort:xhigh`, `Explanatory`, `thinking`, `VIM:INSERT`.
- Feed a fixture JSON with `effort.level = "low"`, no `output_style`
  field, `thinking.enabled = false`, no `vim` field. The output must
  contain `effort:low` and must NOT contain `thinking` or `VIM:`.
- Feed a fixture JSON with `output_style.name = "default"` (lower-case).
  The output must NOT contain `default` from the style emitter (i.e.
  the default style is suppressed).

## Out of scope

- Colour-scheme changes to existing items.
- Adding an `agent` item (the `agent.name` / `agent.type` fields are
  already populated in sub-agent sessions where `subagents` shows the
  count; a separate per-item agent name display is deferred).
- Localised / translated effort labels.
- Configuration knobs to suppress individual items (priority-based
  dropping at width limits already handles de-cluttering).

## Affected files

- `specs/023-statusline-session-state-items.md` (new)
- `home/dot_claude/statusline/data.sh` — four new globals in
  `extract_fields`.
- `home/dot_claude/statusline/items.sh` — four new `emit_*` functions;
  `emit_all` updated.
- `tests/test_smoke.sh` — new `[claude statusline (spec 023)]` block.
