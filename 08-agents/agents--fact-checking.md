# Agent: Fact-Checking

A fact-checking agent verifies claims in text against external sources and assigns verdicts with supporting evidence. It is most useful when content may contain outdated statistics, attributed quotes, or disputed assertions. The agent's output is only as good as its source access — if search results are unreliable or the claim domain is poorly indexed, the verdict must reflect that uncertainty.

## Claim Extraction

Before any search, extract discrete, verifiable claims from the input text. Not every sentence is a claim — only those that assert a specific fact that can be confirmed or contradicted.

Good claim types: statistics ("X% of users..."), temporal assertions ("Company Y was founded in..."), causal claims ("Drug Z reduces risk by..."), attribution ("Person X said...").

Not verifiable as facts: opinions, predictions, normative statements ("this is the best approach").

Extract claims as a structured list before beginning verification. Each claim should be:
- Self-contained (can be evaluated without the surrounding paragraph)
- Specific enough to search for (avoid vague claims)
- Scoped to a single assertion (split compound claims)

## Search-Grounded Verification

For each claim, formulate 1–2 search queries targeting authoritative sources. Prefer primary sources (original studies, official filings, government databases) over secondary sources (news articles, blog posts).

Query formulation matters: search for the claim's core assertion, not the original text. A claim "Apple's revenue was $394B in 2022" should be searched as "Apple annual revenue 2022 fiscal year" — matching the domain language, not the input phrasing.

Retrieve at least 2 independent sources before assigning a verdict. One source is rarely sufficient — sources can themselves be wrong, misquote, or use different definitions.

## Evidence Chain Format

Each verified claim should produce a structured record:

```
Claim: [exact text of the claim]
Queries used: [list of search queries run]
Sources:
  1. [URL] — [relevant excerpt] — [publication date]
  2. [URL] — [relevant excerpt] — [publication date]
Verdict: confirmed | unverified | contradicted | outdated
Confidence: high | medium | low
Notes: [discrepancies between sources, scope limitations, definitional differences]
```

This chain makes the reasoning auditable. Anyone reading the output can follow the same evidence trail to assess whether the verdict is sound.

## Confidence Levels

**Confirmed**: Multiple authoritative sources agree; claim matches sources precisely (same year, same scope, same definition).

**Unverified**: Searched but found no authoritative source that directly addresses the claim. This is not the same as false — it means the claim cannot be grounded with available evidence. Absence of evidence ≠ evidence of absence.

**Contradicted**: One or more authoritative sources directly state a different figure or fact. Note the discrepancy precisely (e.g., "claim says 47%, primary source says 43%").

**Outdated**: Claim was accurate at some point but the current data differs. Applies to statistics, rates, and counts that change over time. Always note the year the claim would have been accurate if determinable.

Use low confidence when: sources disagree with each other, only secondary sources found, claim requires specialized domain expertise to interpret.

## Citation Format

Citations in output should be:
- Inline in the verdict text: "[Confirmed¹]"
- Footnoted at the end with full URL, title, publication, and date accessed
- Never just a bare URL — always include the publication name and date so the reader can assess source quality without clicking

For statistical claims, cite the specific table or figure, not just the homepage: "Apple Q4 2022 10-K, Table 2, Total net sales."

## Key Rules

- Extract all claims before searching any of them — prevents anchoring bias from early search results.
- Require at least 2 independent sources before a "confirmed" verdict; single-source confirmation is overconfident.
- Distinguish "unverified" from "false" — most claims that can't be confirmed are simply not well-indexed, not wrong.
- Note definitional differences: "users" vs "active users" vs "registered accounts" can make a claim technically accurate or false depending on which definition the source uses.
- For numeric claims, check the time period, geography, and methodology match between the claim and the source.
- Never fabricate citations — if a claim cannot be grounded, mark it unverified, not confirmed.
