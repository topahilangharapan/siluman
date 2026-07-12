# Hardcode the human-writing preset into the Claude Code harness

## Context

The user has a "Human-Quality Writing Preset" (anti-AI-tells writing rules derived from Wikipedia's WP:AISIGNS) in `~/Downloads/ai_writing_guidelines/`: a full version (~2.5k tokens), a compact version (~600 tokens), and a `.skill` zip that refreshes the preset from the live Wikipedia page. They want every writing request to follow the preset — but enforced by the harness, not by CLAUDE.md instructions, because instruction-only approaches drift ("Claude hallucinates past the md").

Design principle: **inject deterministically, then verify deterministically.** Two hooks:

1. **UserPromptSubmit hook** — detects writing-intent prompts and injects the compact preset as context adjacent to the prompt (far stronger salience than top-of-context CLAUDE.md). Also flags the turn for enforcement.
2. **Stop hook linter** — when the turn was flagged, a Python script scans Claude's final reply for mechanically checkable violations (banned words, banned sentence skeletons, formatting tells) and returns `{"decision": "block", "reason": ...}`, forcing Claude to rewrite. This is the hardcoded part: a script the model cannot ignore.

## Files to create/modify

### 1. Canonical preset location — `~/.claude/writing/`
- Copy `human-writing-preset.md` and `human-writing-preset-compact.md` from `~/Downloads/ai_writing_guidelines/`.
- This is the single source of truth the hooks read at runtime, so a preset refresh automatically updates what gets injected — no hook changes needed.

### 2. `~/.claude/hooks/writing-preset-inject` (Python 3, executable) — UserPromptSubmit
- Read hook JSON from stdin (`prompt`, `session_id`).
- Writing-intent gate (case-insensitive regex): write/draft/compose/rewrite/reword/rephrase/polish + nouns email/essay/article/blog/letter/post/caption/bio/report/announcement/newsletter/cover letter/proposal/summary, plus Indonesian equivalents (tulis, tuliskan, buatkan artikel/email/surat). Manual override token `#hw` always triggers.
- Negative guard: don't trigger when the writing verb targets code ("write a function/script/test/query/class/component/migration").
- On match: print JSON with `hookSpecificOutput.additionalContext` = full text of the compact preset + a line saying a linter will reject violations; write a per-session flag file `~/.claude/writing/.active-<session_id>` (contains retry counter `0`).
- On no match: delete the flag file if present; exit silently.

### 3. `~/.claude/hooks/writing-preset-lint` (Python 3, executable) — Stop
- Read hook JSON (`session_id`, `transcript_path`, `stop_hook_active`).
- Exit 0 immediately unless the flag file for this session exists.
- Parse the transcript JSONL, take the last assistant message's text blocks, strip fenced code blocks and inline code, then run checks:
  - Banned vocabulary (word-boundary regexes from preset §1: delve, tapestry, testament to, pivotal, crucial, robust, seamless, leverage, showcase, underscore, foster, "it's worth noting", "in conclusion", "stands as", "serves as", "a wide range of", etc.)
  - Negative parallelisms: `not (just|only) X(,)? but`, `it'?s not X[,;—] it'?s`, `no X, no Y, just Z`
  - Trailing "-ing" analysis clauses: `, (highlighting|underscoring|showcasing|reflecting|emphasizing|cementing|demonstrating|signaling)\b[^.]*[.]`
  - Em-dash density > 1 per 300 words
  - `- **Term:** text` bullet pattern; bold-heavy output (> ~3 bold spans)
  - Emoji, horizontal rules, Title Case headings, `#+ Conclusion` heading, curly quotes
- Violations found and retry counter < 2: increment counter, output `{"decision": "block", "reason": "Your reply violates the human-writing preset: <specific list with the offending snippets>. Rewrite it fixing only these issues."}` — Claude is forced to revise.
- Clean (or retry cap hit, or `stop_hook_active` with counter exhausted): delete flag file, exit 0. The cap + `stop_hook_active` check prevents infinite loops.

### 4. `~/.claude/settings.json` — register hooks
- Invoke the `update-config` skill to add, alongside the existing cbm hooks:
  - `UserPromptSubmit` → `~/.claude/hooks/writing-preset-inject` (timeout ~5s)
  - `Stop` → `~/.claude/hooks/writing-preset-lint` (timeout ~10s)

### 5. Install the refresh skill — `~/.claude/skills/human-writing-preset-refresh/`
- Unzip `~/Downloads/ai_writing_guidelines/human-writing-preset-refresh.skill` into `~/.claude/skills/`.
- Edit its SKILL.md Steps 1 and 6 to use `~/.claude/writing/` as the canonical read/write location, so "refresh the writing preset" updates exactly the files the hooks inject.

### 6. `~/.claude/CLAUDE.md` — 2-line backstop
- Short pointer: writing prose deliverables must follow `~/.claude/writing/human-writing-preset-compact.md`. This only covers phrasings the regex gate misses (~40 tokens; not the primary mechanism).

## Scope decisions (made, flag if wrong)
- Enforcement applies to **writing-intent turns only**, not coding replies/commit messages — otherwise the linter would false-positive on Claude Code's normal terse reporting style. `#hw` in any prompt opts a turn in manually.
- The compact preset is what gets injected (600 tokens/writing turn); the full preset stays available in `~/.claude/writing/` for reference and refresh.

## Verification
1. Unit-test the linter offline: pipe fabricated transcripts (one riddled with tells — "delve", "not just X, but Y", `- **Speed:** fast`, em-dash spam; one clean) through `writing-preset-lint` and assert block vs pass.
2. Unit-test the gate: run `writing-preset-inject` with prompts "write a blog post about coffee", "tuliskan email untuk dosen", "write a function that parses JSON" (must NOT trigger), "#hw fix this paragraph".
3. Live test in a fresh `claude` session: a writing prompt (confirm injected context + a deliberately provoked rewrite by asking it to use the word "delve"), then a coding prompt (confirm no injection, no lint).
4. Confirm the retry cap by making the linter temporarily impossible to satisfy and watching it release after 2 blocks.
