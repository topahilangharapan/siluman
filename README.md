# siluman

Claude Code hooks that catch AI-writing tells and force a rewrite - or, for technical
documentation, force compliance with ASD-STE100 Simplified Technical English instead.

Ask a language model for an email and you get text with fingerprints all over it: "delve", "testament to", an em dash every other sentence, bullet lists where each item opens with a bolded term, and the inescapable "not just X, but Y". Wikipedia editors keep a field guide to these fingerprints at [Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing). siluman turns that guide into an enforcement loop for Claude Code. The rules are injected next to every writing prompt, a linter scans the reply, and anything that still reads like a model gets blocked and rewritten before you see it.

Ask for a maintenance manual, an SOP, or work instructions and the same hooks switch to a
second, unrelated ruleset instead: [ASD-STE100](https://www.asd-ste100.org/) Simplified Technical
English, the aerospace/defense industry's controlled language - a ~875-word approved dictionary,
strict sentence/paragraph caps, imperative-only procedures, and a defined WARNING/CAUTION/NOTE
structure. See [STE100 mode](#ste100-mode-technical-documentation) below.

## Why hooks and not CLAUDE.md

Putting "write like a human" instructions in CLAUDE.md works for a session or two, then drifts. Instructions sitting at the top of a long context lose salience, and the model slides back into its defaults. Hooks take the decision away from the model: a UserPromptSubmit hook injects the rules immediately beside the prompt, where salience is highest, and a Stop hook runs a linter that can mechanically reject the reply. An exit code cannot be talked out of its opinion.

## How it works

```
you: "write a blog post about coffee"
        |
        v
writing-preset-inject  (UserPromptSubmit hook)
  detects writing intent, injects the compact preset (~600 tokens),
  arms the linter for this session
        |
        v
Claude writes
        |
        v
writing-preset-lint  (Stop hook)
  tier 1   hard bans       regex, zero tolerance: em dashes, emoji,
                           bold-term bullets, curly quotes, ...
  tier 2   statistics      tell-word rates vs human baselines,
                           tell clustering, sentence-length burstiness
  tier 3   semantic judge  headless `claude -p` (Haiku) checks what
                           regexes cannot see
        |
   violations? ---yes---> reply blocked with exact quotes,
        |                 Claude rewrites (max 2 retries)
        no
        v
prose with no tells
```

### The gate

`hooks/writing-preset-inject` fires on prompts that look like prose requests: a writing verb (write, draft, rewrite, reply, improve, summarize, ...) plus a prose noun (email, essay, article, blog, message, explanation, ...). It understands Indonesian too (tuliskan, buatkan artikel, susun laporan). Bare polish verbs ("improve this", "shorten it") and phrases like "make it sound more professional" trigger without needing a noun at all. "Write a function that parses JSON" does not trigger it, because code nouns veto the match. "document"/"documentation" gets the same veto treatment even though it's also a recognized prose noun: "draft documentation" triggers, "write documentation for this API" doesn't. Add `#hw` to any prompt to force it on.

Writing is rarely one turn, and some skills run a multi-phase clarify-first intake before any prose exists at all. So once a prompt arms the session, it stays armed - re-injecting the preset every turn for salience - through any number of ordinary follow-ups ("make it shorter", "yes, do that", a clarifying answer), not just the first reply. Only a clear pivot to a code-shaped request disarms it early; otherwise it lasts until the retry cap releases it or the session's 24-hour-stale flag gets swept.

### The linter

Three tiers, merged into a single violation list.

Tier 1 is plain regex with zero tolerance, reserved for formatting: any em dash, curly quotes, emoji, horizontal rules, `- **Term:** text` bullets, Title Case headings, a "Conclusion" heading, bold-heavy output.

Tier 2 is statistical, because banning vocabulary outright punishes normal usage; one "crucial" in two pages is human. Each tell word instead carries a baseline rate (expected occurrences per 1,000 words of human text). The observed count gets a Poisson tail probability, and the per-word surprises combine into one composite score using Stouffer's method. The tier also flags clusters of distinct tells inside a 100-word window, and sentence lengths so uniform that no human wrote them.

Tier 3 pipes the reply through a headless `claude -p` call on Haiku with criteria a regex cannot express: unearned significance claims, synonym rotation, hollow parallelism. It fails open. No CLI, a timeout, or garbage output just skips the tier.

A blocked reply goes back to Claude with the offending quotes, and after two rewrites the linter releases the turn rather than trapping the session, reporting whatever is still wrong. Every failure path in both hooks exits 0; a broken linter must never lock up Claude Code.

## STE100 mode (technical documentation)

`writing-preset-inject` runs a second, separate gate before the general-prose one: a mention of
"STE"/"STE100"/"simplified technical english", or a writing verb plus a technical-documentation
noun (manual, SOP, work instructions, maintenance manual, technical documentation/publication,
installation guide, service bulletin, work/task card, spec, maintenance procedure). This gate wins
over the general one when both would match, on the theory that an explicit ask for a manual means
the user wants STE100 output, not "sound human" prose. Add `#ste` to any prompt to force it on.

This is not the AI-tells preset with extra rules bolted on - it's a different ruleset entirely,
paraphrased from [ASD-STE100](https://www.asd-ste100.org/) Issue 9 (2025-01-15):

- **Controlled vocabulary**: every word must be in the approved dictionary (`ste100-dictionary.json`,
  2,188 entries: ~875 approved words with their single approved meaning/part of speech, ~1,300
  not-approved words each mapped to its approved alternative(s)) or qualify as a technical noun/verb.
- **Sentence and paragraph caps**: 20 words per procedural (instruction) sentence, 25 for
  descriptive sentences and notes, 6 sentences per descriptive paragraph - counted with STE100's own
  word-counting rules (a number, a number+unit, an abbreviation, an alphanumeric ID, a quoted span,
  a proper noun, and a hyphenated compound each count as one word).
- **Verb discipline**: only infinitive, imperative, simple present/past/future, and
  past-participle-as-adjective. No perfect or progressive tenses, no passive-voice auxiliary chains,
  active voice everywhere except descriptive text with a genuinely unknown agent.
- **WARNING/CAUTION/NOTE structure**: WARNING = risk of injury or death, CAUTION = risk of
  equipment damage; every one needs a leading command/condition and a stated consequence. Notes
  give information only, never a command.
- **No semicolons, ever.**

STE100 explicitly doesn't regulate formatting, so siluman's usual formatting hygiene (no
bold-header bullets, no horizontal rules, no emoji, no curly quotes, sentence-case headings) still
applies in this mode as a gap-filler - see `writing/ste100-preset.md` §10.

`writing/ste100-dictionary.json` is extracted from ASD-STE100 Issue 9, © ASD (Aerospace, Security
and Defence Industries Association of Europe). ASD's usage-rights clause grants free reproduction
to ASD/AIA/AIAC members, their customers, defense ministries, airlines, airworthiness authorities,
and universities for educational use - confirm you qualify (or keep this repo private) before
publishing a fork that includes it.

## Install

```sh
git clone https://github.com/topahilangharapan/siluman
cd siluman
./install.sh
```

The script copies the hooks to `~/.claude/hooks/`, the preset and rules to `~/.claude/writing/`, and the refresh skill to `~/.claude/skills/`. It never overwrites an existing `user-overrides.md`. Then register the hooks in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/writing-preset-inject", "timeout": 5 }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/writing-preset-lint", "timeout": 60 }] }
    ]
  }
}
```

Requirements: Claude Code and Python 3.8+ on PATH. Tier 3 spends one extra Haiku call per writing turn; set `semantic_judge.enabled` to `false` in `lint-rules.json` if you'd rather not.

## Configuration

`writing/lint-rules.json` is the linter's whole brain:

- `hard_bans`: name and pattern pairs for tier 1.
- `tell_words`: term, optional variants, and `lambda`, the human baseline per 1,000 words. Raise a lambda to tolerate a word more; delete the entry to stop tracking it.
- `statistics`: composite z threshold, cluster window, burstiness floor.
- `semantic_judge`: enabled flag, model, timeout, and the criteria handed to the judge.
- `max_retries`: rewrites before the linter gives up (default 2).

`writing/user-overrides.md` is appended to every injection and survives preset refreshes. The bundled copy bans em dashes outright; put your own non-negotiables there.

`writing/ste100-lint-rules.json` is STE100 mode's equivalent: sentence/paragraph word caps, the
word-counting exception patterns, the shared semicolon ban, and the semantic-judge criteria for
what regex can't check (passive voice, banned verb constructions, WARNING/CAUTION compliance,
terminology consistency). `writing/ste100-dictionary.json` holds the approved/not-approved word
list the linter checks against; it's deterministic, not statistical - either a word is approved or
it isn't.

## Refreshing the preset

Wikipedia editors keep adding tells as models pick up new habits. The bundled skill (`skills/human-writing-preset-refresh`) re-derives both preset files and the `tell_words` list from the live page. In Claude Code, say "refresh the writing preset". It never touches `hard_bans`, `statistics`, or your overrides.

## Try it in a browser

`docs/harness-guide.html` is a self-contained walkthrough with tiers 1 and 2 reimplemented in JavaScript. Paste any text and watch what the linter would flag. Open the file locally, or serve `docs/` with GitHub Pages.

## Repo layout

```
hooks/writing-preset-inject               UserPromptSubmit hook: gate (both modes), inject, arm
hooks/writing-preset-lint                 Stop hook: linter, dispatched by session mode
writing/human-writing-preset.md           full AI-tells preset (~2.5k tokens), reference copy
writing/human-writing-preset-compact.md   what actually gets injected in general mode (~600 tokens)
writing/lint-rules.json                   general-mode tier 1-3 configuration
writing/ste100-preset.md                  full STE100 preset, reference copy
writing/ste100-preset-compact.md          what actually gets injected in ste100 mode
writing/ste100-lint-rules.json            ste100-mode linter configuration
writing/ste100-dictionary.json            ASD-STE100 approved/not-approved word list
writing/user-overrides.md                 personal rules, never clobbered by refresh
skills/human-writing-preset-refresh/      skill that regenerates the AI-tells preset from Wikipedia
docs/                                     interactive guide, design plan, plan review
install.sh                                copies everything into ~/.claude
```

## License

The code (hooks, install script, guide pages) is MIT, see [LICENSE](LICENSE). The AI-tells preset
texts (`writing/human-writing-preset*.md` and `skills/human-writing-preset-refresh/assets/`) are
derived from Wikipedia's [Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing)
and therefore carry its license, [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

`writing/ste100-preset*.md` and `writing/ste100-lint-rules.json` are paraphrased instructions, not
a reproduction, of ASD-STE100's writing rules. `writing/ste100-dictionary.json` is a direct
extraction of ASD-STE100's controlled dictionary and is **not** covered by this repo's MIT license -
it's © ASD (Aerospace, Security and Defence Industries Association of Europe), used here under
ASD-STE100's own usage-rights terms. See the [STE100 mode](#ste100-mode-technical-documentation)
section above before publishing a fork that includes it.
