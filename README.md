# no-tells

Claude Code hooks that catch AI-writing tells and force a rewrite.

Ask a language model for an email and you get text with fingerprints all over it: "delve", "testament to", an em dash every other sentence, bullet lists where each item opens with a bolded term, and the inescapable "not just X, but Y". Wikipedia editors keep a field guide to these fingerprints at [Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing). no-tells turns that guide into an enforcement loop for Claude Code. The rules are injected next to every writing prompt, a linter scans the reply, and anything that still reads like a model gets blocked and rewritten before you see it.

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

`hooks/writing-preset-inject` fires on prompts that look like prose requests: a writing verb (write, draft, rewrite, polish) plus a prose noun (email, essay, article, blog, report). It understands Indonesian too (tuliskan, buatkan artikel, susun laporan). "Write a function that parses JSON" does not trigger it, because code nouns veto the match. Add `#hw` to any prompt to force it on.

### The linter

Three tiers, merged into a single violation list.

Tier 1 is plain regex with zero tolerance, reserved for formatting: any em dash, curly quotes, emoji, horizontal rules, `- **Term:** text` bullets, Title Case headings, a "Conclusion" heading, bold-heavy output.

Tier 2 is statistical, because banning vocabulary outright punishes normal usage; one "crucial" in two pages is human. Each tell word instead carries a baseline rate (expected occurrences per 1,000 words of human text). The observed count gets a Poisson tail probability, and the per-word surprises combine into one composite score using Stouffer's method. The tier also flags clusters of distinct tells inside a 100-word window, and sentence lengths so uniform that no human wrote them.

Tier 3 pipes the reply through a headless `claude -p` call on Haiku with criteria a regex cannot express: unearned significance claims, synonym rotation, hollow parallelism. It fails open. No CLI, a timeout, or garbage output just skips the tier.

A blocked reply goes back to Claude with the offending quotes, and after two rewrites the linter releases the turn rather than trapping the session, reporting whatever is still wrong. Every failure path in both hooks exits 0; a broken linter must never lock up Claude Code.

## Install

```sh
git clone https://github.com/topahilangharapan/no-tells
cd no-tells
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

## Refreshing the preset

Wikipedia editors keep adding tells as models pick up new habits. The bundled skill (`skills/human-writing-preset-refresh`) re-derives both preset files and the `tell_words` list from the live page. In Claude Code, say "refresh the writing preset". It never touches `hard_bans`, `statistics`, or your overrides.

## Try it in a browser

`docs/harness-guide.html` is a self-contained walkthrough with tiers 1 and 2 reimplemented in JavaScript. Paste any text and watch what the linter would flag. Open the file locally, or serve `docs/` with GitHub Pages.

## Repo layout

```
hooks/writing-preset-inject               UserPromptSubmit hook: gate, inject, arm
hooks/writing-preset-lint                 Stop hook: the three-tier linter
writing/human-writing-preset.md           full preset (~2.5k tokens), reference copy
writing/human-writing-preset-compact.md   what actually gets injected (~600 tokens)
writing/lint-rules.json                   tier 1-3 configuration
writing/user-overrides.md                 personal rules, never clobbered by refresh
skills/human-writing-preset-refresh/      skill that regenerates the preset from Wikipedia
docs/                                     interactive guide, design plan, plan review
install.sh                                copies everything into ~/.claude
```

## License

The code (hooks, install script, guide pages) is MIT, see [LICENSE](LICENSE). The preset texts in `writing/` and `skills/human-writing-preset-refresh/assets/` are derived from Wikipedia's [Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) and therefore carry its license, [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
