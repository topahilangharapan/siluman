# Source map: WP:AISIGNS page sections → preset sections

Use this during the diff step. Left column: section on the Wikipedia page (structure as of
June 2026 — section names may shift, so match by topic, not exact title). Right column: where the
inverted rule lives in the preset, and what kind of rule it becomes.

| Wikipedia page section | Preset target | Rule type |
|---|---|---|
| Intro + Caveats (detection tools, human ability) | none (context only) | Reminds you the page lists *tendencies*; carry caveats into rules only when they prevent banning human habits |
| Content → Undue emphasis on significance/legacy/trends | §3 Content, rule on significance inflation | Ban |
| Content → Canned emphasis on notability/attribution/media coverage | §3 "notability theater" + §5 citation narration | Ban; note this grows in 2025+ models |
| Content → Superficial analyses | §3 superficial analysis + §2 trailing "-ing" clauses | Ban |
| Content → Promotional language | §3 neutral-not-promotional | Ban |
| Content → Vague attributions / overgeneralized opinions | §3 weasel attribution | Ban |
| Content → "Challenges"/"Future prospects" outlines | §3 formula ban | Ban |
| Content → Leads treating titles as proper nouns | §3 (add if preset gains a lead-sentence rule) | Ban, niche |
| Language → "AI vocabulary" word lists (era breakdown) | §1 Banned vocabulary | Ban; THIS IS THE HIGHEST-CHURN SECTION — re-derive the word list every refresh and era-tag it |
| Language → Avoidance of copulas (is/are → "serves as") | §2 plain copulas | Ban inversion: *require* is/are/has |
| Language → Negative parallelisms (not just X but Y; not X, but Y) | §2 parallelism bans | Ban |
| Language → Rule of three | §2 vary list lengths | Ban-the-default |
| Language → Lexical diversity / elegant variation | §2 allow natural repetition | Permission (allow repeating nouns) |
| Style → Title case headings | §4 sentence case | Ban |
| Style → Overuse of boldface | §4 minimal bold | Ban |
| Style → Inline-header vertical lists ("- **Term:** text") | §4 bullet-with-bold-header ban | Ban |
| Style → Em dash overuse | §2 em dash budget | Quota; check whether the page updates frequency notes (newer models suppress them) |
| Style → Unusual tables | §4 no mini-tables | Ban |
| Style → Curly quotes/apostrophes | §4 straight quotes | Default + consistency rule; keep the caveat (Word/macOS produce curly quotes too) |
| Style → Skipped heading levels, thematic breaks | §4 | Ban |
| Communication → Collaborative chatter, knowledge-cutoff disclaimers, placeholders | §3 disclaimers/placeholders + §6 meta rules | Ban |
| Markup → Markdown leakage, broken wikitext, turn0search0, oaicite, etc. | §4 match-destination-markup; artifacts list | Ban; artifact strings churn fast — refresh the named artifacts each sync |
| Citations → broken links, fake DOIs/ISBNs, pageless book cites, UTM params, unused refs | §5 Citations | Ban/require |
| Miscellaneous → style shifts, edit summaries, AfC quirks, model differences | mostly none | Wikipedia-editor-specific; only fold in what generalizes (e.g., verbose self-justifying summaries → §6) |
| Indicators of AI-written comments (canned good faith, wikilawyering, emoji headers, etc.) | §6 Conversational/meta | Ban what generalizes (canned politeness, stock offers of criticism, emoji decoration) |
| Signs of human writing (simple phrases, plain verbs, superlatives, hedges, wordy connectors) | §2 human syntax markers | PERMISSIONS — adopt as positive instructions |
| Ineffective indicators | none | Guardrail: never add a rule banning something this section says is a weak/ineffective tell |
| Historical indicators (didactic disclaimers, Conclusion sections, prompt refusals, cut-offs, stale access-dates) | keep existing rules, demote urgency | Keep bans, tag as legacy; watch for items migrating INTO this section from above |

## Diff heuristics

- The vocabulary lists, the markup-artifact strings, and the "Historical indicators" section are
  where ~80% of churn happens. Check those three first.
- A tell moving to "Historical indicators" means newer models stopped doing it — keep the rule
  (it's free) but don't let it crowd the compact version.
- Anything appearing in "Ineffective indicators" must be ABSENT from the preset; if a preset rule
  matches, remove it and note the removal in the changelog.
- New entries under "Signs of human writing" are the only additions that become permissions
  rather than bans.
