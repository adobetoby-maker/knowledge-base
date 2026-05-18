# DRY Applied Correctly

DRY (Don't Repeat Yourself) is misunderstood as "never write similar-looking code twice." That's wrong, and applying it blindly produces worse code than duplication would have.

## The Real Rule

DRY is about knowledge, not text. The principle says each piece of **domain knowledge** should have a single authoritative representation. Two functions that happen to share the same three lines of code are not a DRY violation if they represent different concepts that will evolve independently.

## Accidental vs Intentional Duplication

**Accidental duplication** is copy-paste without thought. You needed a discount calculation in the cart and copy-pasted it into the invoice module. Now a bug fix requires two changes instead of one, and you'll forget the second one. This is the duplication DRY targets.

**Intentional duplication** is two things that look alike today but change for different reasons. Validation logic in a mobile app and validation logic on the server often start identical. Coupling them via shared code is a mistake — they have different error message formats, different tolerance for edge cases, and different deployment cycles. When the server hardens a rule, you don't want the mobile app to break.

The test: ask "if the business rule changes, do I want one change to affect both places?" If yes, abstract. If no, leave them separate.

## Why Premature DRY Creates Wrong Abstractions

Sandi Metz put it clearly: the cost of the wrong abstraction is higher than the cost of duplication. When you extract shared code too early, you tie together two concepts that don't actually belong together. Later, when one of them needs to diverge, you're stuck: either you add a flag parameter to handle the special case (making the abstraction leaky), or you duplicate it back out (making the original extraction wasted work), or you contort the code to fit the abstraction (making it misleading).

Wrong abstractions compound. Every new caller of the abstracted function adds another vote for keeping it. The longer a wrong abstraction lives, the more expensive it is to fix.

## When to Abstract

Wait for the **third repetition**. Two occurrences might be coincidence. Three occurrences usually indicate a real pattern worth naming. When you do abstract, name the abstraction after the concept, not after the shared mechanics.

## DRY for Data, Not Just Code

DRY applies strongly to **data definitions**. A field name, a business rule threshold, a URL base — these should be defined once and referenced everywhere. Constants and configuration files exist for this reason. Hardcoding `"admin"` in five places is a DRY violation even if the code surrounding it looks nothing alike.

## Key Rules

- Abstract when the underlying **knowledge** is the same, not just when the text is similar
- Two things that change for different reasons should not share an abstraction
- Wait for three repetitions before extracting
- Wrong abstractions are more expensive than duplication — premature DRY is a form of technical debt
- DRY applies most strongly to data: constants, config values, domain rules
- When unsure, duplicate first; the right abstraction will reveal itself once you see the pattern three times
