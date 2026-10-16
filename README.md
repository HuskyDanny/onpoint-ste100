# onpoint-ste100 — the ASD-STE100 rulebook as common personas + adapters

The OnPoint rulebook (upstream: two-axis terse-output plugin, doctrine /
essence-first / say-less), with its personas rewritten in **ASD-STE100
controlled English** — one instruction per sentence, ≤20 words, active
voice, no idioms; every rule preserved (the mapping of all 46 lives in the
ste100 branch of OnPoint: `ste/MAPPING.md`).

Upstream OnPoint was engineered for claude code's lifecycle and generates
~20 per-harness files from `personas/*.md` ("copies are correct, staleness
is the problem"). This repo applies the same discipline to the box's common
persona layer: **personas as structured YAML (single truth) + one adapter
per harness**, compiled and staleness-checked. Personas are model-agnostic
— which model answers is the deployer's decision, never the persona's.

## Layout

    personas/                  common truth (edit these)
      00-doctrine.yaml           order 0 — applies the rulebook, orders the axes
      01-essence-first.yaml      order 1 — the big idea line one, next action line two
      02-say-less.yaml           order 2 — keep only words that carry information
    adapters/build.py          the adapter registry — one function per harness
    adapters/templates/claude/ harness mechanics ported from upstream
                               (inject.sh, hooks.json, plugin.json, output-style)
    surfaces/                  GENERATED — never hand-edit
      claude-plugin/             a complete claude plugin (plugin.json, hooks,
                                 personas/*.md, output-styles)
      pi/bodies/on-point-ste.md  the bare rulebook — the --append-system-prompt channel
      pi/extension/on-point-ste.ts  the lifecycle twin of the claude hooks
    test.sh                    invariants (7, see below)

## Lifecycle parity (the exploration result)

| | claude (upstream native) | pi (ported via extension) |
|---|---|---|
| inject on session start | `SessionStart` hook cats bodies (payload <10KB — past it, claude silently spills to a file; measured upstream 10000 in / 10050 spill) | pi stream is per-run: extension handler on `before_agent_start` appends bodies to the system prompt |
| re-assert per prompt | `UserPromptSubmit --line`: one-line reinforcement (full bodies every turn would stack) | not needed — the prompt is rebuilt every run, so the append happens per run by construction |
| subagents | `SubagentStart` hook, full bodies | pi subagent runs go through the same `before_agent_start` |
| disable | delete/rename a persona file | `/on-point-ste off` (registered command) |
| observed quirk | hook stdout cap testable by size | the JSON stream's system message shows the PRE-extension prompt; the transform is request-side only — verify behaviorally (ask for rulebook-only facts) |

pi contract notes (measured 2026-10-16, pi 1.3.0): explicit `--extension
<path>` loads even under `--no-extensions` (same as `--skill` under
`--no-skills`); a handler receiving `before_agent_start` returns
`{ systemPrompt }` — a REPLACE, so the idiomatic form is
`event.systemPrompt + bodies`.

## Workflow

    $EDITOR personas/01-essence-first.yaml      # edit the truth
    uv run --script adapters/build.py           # regenerate claude + pi
    ./test.sh                                   # 7 invariants

## test.sh invariants

8 checks: surfaces fresh · axis order 0..n · claude hook payload < 9800B ·
`--line` names both axes · pi bodies ≡ claude persona bodies · output-style
≤ ½ bodies · no vendor model name in the truth · no borrowed style labels.

## Is it "clean" ASD-STE100? (cross-check 2026-10-16)

Cross-checked against the spec's public structure (Issue 9: 53 rules in 9
sections + ~900-word dictionary) and max.nardit.com's review of Karpathy's
STE post. Honest statement, in that post's own terms:

- **Certified by test.sh (structure)**: one instruction per sentence, no
  sentence over the STE limits measured in the audit, active voice, no
  borrowed style labels (i-have-adhd, caveman — upstream's own rule NAMES;
  they live in provenance docs now, not in the rulebook), no emoji/tables,
  short-word substitutions.
- **NOT certified (vocabulary)**: the ~900-word approved dictionary (one
  meaning, one part of speech each) is the spec's real discriminator and is
  not checked here. This rulebook is **STE-flavored English, not STE** — the
  same finding that article applies to every AI STE attempt without a
  linter. The structural rules are what generalize to an LLM rulebook; the
  dictionary is a maintainer-grade layer we deliberately do not claim.
- **"Plausibility must not be confused with verified compliance"** (STEMG
  AI white paper, quoted in the article): test.sh verifies structure and
  parity, never model-output compliance. The A/B judge measures effect, not
  STE adherence — the future sweep should add a mechanical linter
  (e.g. Vale) over arm answers.
- **The hedges pair resolves the article's main warning** ("keep every if,
  unless, not yet verified — a clearer sentence can become a stronger
  claim"): the rulebook holds BOTH halves — rule 26 keeps a hedge carrying
  real uncertainty ("deleting it manufactures confidence"), rule 30 drops
  filler hedging. Simplification must never strengthen a claim, and the
  pair already encodes that.
- The output-style surface (ported from upstream) also dropped the labels
  today (description + headings + table rows); its voice remains upstream's,
  and it is the one surface whose prose makes no STE claim.

## Arming (the field's experiment)

Armed as arm `b` of `Projects/Experiments/onpoint-ste100`:
- pi channel: `SYSTEM_PROMPT_FILE.b` → `surfaces/pi/bodies/on-point-ste.md`
- claude channel: `PLUGIN_DIR.b` → `surfaces/claude-plugin/`

## Provenance

- Rulebook authored 2026-10-16 on OnPoint branch `ste100` (`e143bf7`) — the
  ste100 treatment of upstream `HuskyDanny/OnPoint` (`26e80fd`); claude-form
  build+tests green there (45 invariants).
- This repo extracted the personas into the common YAML schema 2026-10-16
  (same structure as `Agents/personas/review-*.yaml`) and ported the claude
  hook mechanics verbatim into `adapters/templates/claude/`.
