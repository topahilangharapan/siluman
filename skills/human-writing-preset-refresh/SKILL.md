---
name: human-writing-preset-refresh
description: Refresh, update, or regenerate the "Human-Quality Writing Preset" (the anti-AI-tells writing instructions) from its source, Wikipedia's "Signs of AI writing" page (WP:AISIGNS). Use this skill whenever the user asks to refresh the preset, update the AI-writing-tells guide, sync the preset with Wikipedia, check for new AI writing signs or banned words, regenerate human-writing-preset.md, or asks whether the preset is out of date. Also use it when the user uploads a human-writing-preset file and asks to update or improve it.
---

# Human Writing Preset Refresh

This skill keeps the "Human-Quality Writing Preset" current. The preset is a set of writing
instructions (banned vocabulary, sentence rules, content rules, formatting rules) that makes AI
output read more like human writing. Its source of truth is the community-maintained Wikipedia page
**Wikipedia:Signs of AI writing** (`https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing`),
which documents the tells of machine text and is updated as models change. Because AI vocabulary and
habits drift between model generations (e.g., "delve" peaked in 2023 and faded; em-dash overuse was
suppressed in later models), the preset goes stale and must be re-derived from the live page
periodically — roughly every 2–3 months, or whenever a major new model generation ships.

## Workflow

Follow these steps in order. Do not skip the diff step — the user cares about *what changed*, not
just a fresh file.

### Step 1: Locate the current preset

The canonical live copies on this machine are in `~/.claude/writing/`:

- `~/.claude/writing/human-writing-preset.md` — full preset (injected reference version)
- `~/.claude/writing/human-writing-preset-compact.md` — compact preset (injected into every
  writing turn by the `writing-preset-inject` UserPromptSubmit hook)
- `~/.claude/writing/lint-rules.json` — mechanical enforcement rules read by the
  `writing-preset-lint` Stop hook

Use those as the "previous" version. Only if they are missing, fall back to the bundled baselines
in `assets/`. Note the "Last synced" date in the file header — if it is less than ~3 weeks old,
tell the user it is probably still current and ask whether they want to proceed anyway.

### Step 2: Fetch the source page

Try the cheap path first:

1. `web_fetch` on `https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing`.
2. If that fails (the domain may be cache-only in some environments), fall back to browser
   extraction with Claude in Chrome. The page is ~170k characters and full of strings that trip
   output filters (tracking parameters, citation junk like `oaicite`), so plain `get_page_text`
   will fail. Use the chunked DOM-extraction technique in `references/extraction.md` — it
   compresses the page to ~55k characters and pulls it out in two passes.
3. If neither works, ask the user to paste the page text or save it as a file, then continue.

Optionally also check the page's "External links" (e.g., the "Tropes – AI Writing Pattern
Directory") for supplementary patterns, but treat the Wikipedia page as canonical.

### Step 3: Diff against the preset

Map the page's sections to the preset's sections using `references/source-map.md`. For each preset
section, identify:

- **New tells** on the page not yet covered by a rule (most often: new vocabulary in the
  era-by-era word lists, new markup artifacts, new formula patterns).
- **Faded tells** the page now marks as "Historical indicators" or notes as suppressed in newer
  models. Do NOT delete the corresponding rules — following them still does no harm — but move
  era-specific vocabulary into the right era grouping and drop urgency language if any.
- **Changed caveats** (e.g., notes that a tell is also common in human writing). These matter:
  the preset must not ban genuinely human habits.
- **New "signs of human writing"** — these become *positive* instructions (things to allow or
  adopt), not bans.

### Step 4: Update all three enforcement files

The preset ships in two forms plus a machine-readable rules file, and all three must stay in sync:

- `human-writing-preset.md` — the full version (7 sections + self-check list).
- `human-writing-preset-compact.md` — the condensed version for character-limited instruction
  fields. Keep it under ~2,500 characters of rules; cut the least impactful items first.
- `lint-rules.json` (schema v2) — the Stop-hook linter's rules. Regenerate the `tell_words` list
  from the updated vocabulary: each entry is `{term, lambda, variants?}` where `lambda` is the
  plausible HUMAN rate per 1000 words (0.02 for words humans almost never write like "delve" or
  "tapestry"; 0.1–0.3 for strong tells; 0.6–1.0 for words humans genuinely use like "crucial").
  Detection is statistical (Poisson surprise vs these baselines), so new tell words are ADDED with
  a lambda, never as outright bans. Figurative-only tells ("landscape", "journey", "navigate")
  go into `semantic_judge.criteria` instead — the judge can tell figurative from literal, regex
  cannot. NEVER modify `hard_bans` (the em-dash zero-tolerance entry is a personal rule), the
  `statistics` thresholds, or `~/.claude/writing/user-overrides.md`. Validate the file parses
  (`python3 -c "import json; json.load(open(...))"`) and test one dirty transcript through
  `~/.claude/hooks/writing-preset-lint` before finishing — a malformed rules file silently
  disables enforcement.

Rules for editing:

- Preserve the 7-section structure of the full preset (Role, Banned vocabulary, Sentence-level,
  Content, Formatting, Citations, Conversational/meta, Self-check). Renumber only if a whole
  section is added or removed.
- Write rules in the imperative, as instructions to the AI that will consume the preset — the
  preset is a prompt, not an essay. Invert every detection sign into a "do/never do" rule.
- Paraphrase everything in original wording. Never copy sentences from the Wikipedia page.
- The page is descriptive, not prescriptive, and warns about false positives. Carry those caveats
  into rules only where they change behavior (e.g., "repeating a noun is fine").
- Update the "Last synced" date in the header of both files.
- Era-tag vocabulary when the page does (e.g., 2023/GPT-4-era vs. 2025+ words), but keep all eras
  banned — old tells still flag text as AI to readers.
- Never remove, rewrite, or renumber a `semantic_judge.criteria` entry prefixed `(clarity)`. Those
  are carried over from general writing-clarity discipline, not derived from Wikipedia, and are out
  of scope for a WP:AISIGNS refresh.

### Step 5: Report a changelog

Tell the user, in short prose: what was added, what was demoted to historical, what caveats
changed, and whether the compact version had to drop anything to stay within budget. If nothing
material changed, say so plainly — do not invent changes to justify the refresh.

### Step 6: Deliver

Save all three files back to `~/.claude/writing/` — that is the live location the hooks read, so
saving there deploys the refresh immediately with no further wiring. Suggest the next refresh
window (current date + ~3 months, or "after the next major model release, whichever comes first").

## Bundled resources

- `references/extraction.md` — read when web_fetch fails and you need the browser-based chunked
  extraction technique (includes the exact JavaScript and the output-filter workarounds).
- `references/source-map.md` — read during Step 3; maps Wikipedia page sections to preset
  sections and lists what kind of rule each section produces.
- `assets/human-writing-preset.md` — baseline full preset (June 2026). Regeneration template and
  fallback "previous version" for diffing.
- `assets/human-writing-preset-compact.md` — baseline compact preset (June 2026).
