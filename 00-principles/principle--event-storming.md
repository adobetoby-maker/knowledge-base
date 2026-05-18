# Principle: Event Storming as Domain Discovery

## What Event Storming Actually Does

Event storming is a workshop technique for understanding a domain by mapping what happens in it, not by designing a system. The output is not a data model or an architecture diagram. It is a shared understanding of the business timeline: what events occur, what triggers them, what state they affect, and where the natural seams in the domain are. That shared understanding — built collaboratively with domain experts — is what justifies the design decisions that follow.

The reason to do this before building is that most systems fail because they encode the wrong model of the domain. Event storming surfaces the correct model from the people who know the domain, before code makes it expensive to change.

## The Sticky Note Vocabulary

**Orange — Domain Events** — something that happened in the domain, named in past tense: "Order Placed", "Invoice Approved", "Driver Assigned". Events are facts — they already happened. The business cares about them. Write one event per sticky; plaster them on a timeline (left = earlier, right = later). Do not rationalize or filter at this stage; capture everything.

**Blue — Commands** — an action that causes an event: "Place Order", "Approve Invoice". Commands are intentions; events are consequences. A command can fail (so use past-tense events to confirm it succeeded). Each orange sticky should have a corresponding blue if you can find one.

**Yellow — Aggregates** — the domain objects that accept commands and produce events: "Order", "Invoice", "Shipment". An aggregate clusters together the commands and events it owns. Aggregates should be named by the domain experts, not invented by engineers. Wrong aggregate names are a leading indicator of a wrong model.

**Pink (or red) — Hotspots** — questions, ambiguities, disagreements, areas where the domain is unclear or contested. Mark them aggressively and return to them after the initial pass. Unresolved hotspots late in a session often mark the most important design decisions.

**Purple — Policies** — automated reactions: "When Invoice Approved, send notification." Policies connect events to the commands they trigger. They reveal automation opportunities and business rules that might otherwise be buried in prose requirements.

## Finding Bounded Context Seams

After the timeline is mapped, look for:

- **Vocabulary shifts** — where the same concept gets a different name in different parts of the flow ("order" vs. "shipment" vs. "delivery"). Name shifts usually mark context boundaries.
- **Handoff points** — where one team or system hands responsibility to another. These are natural seam candidates.
- **Aggregates that belong to different concerns** — an aggregate that mixes financial state with operational state is a hint that two bounded contexts have been collapsed into one.

Do not try to find the "correct" bounded contexts during the event storming session. Use the session to make seams visible; assign contexts in a separate design session with the mapping in front of you.

## Running a Session

- Put the domain experts in the room, not just developers. Engineers tend to model what is easy to build; domain experts model what is actually true.
- Use a physical wall or a very large digital canvas. Space matters — cramped layouts hide the temporal structure.
- Start with a single person throwing events on the wall. Others add, correct, and challenge.
- Suppress data modeling questions. When someone asks "what fields does an order have?", redirect to "what events does an order produce?" Fields are an implementation concern; events are the domain.
- Plan for 2-4 hours for a non-trivial domain. Stop when the timeline is coherent and hotspots are captured, not when all hotspots are resolved.

## Key Rules

- Events are named in past tense — they are facts, not intentions
- Do not filter or rationalize during the initial event capture — quantity first, quality later
- Hotspots are valuable output; resolving them is not the goal of the session
- Domain experts name aggregates; engineer names for aggregates signal a wrong model
- Vocabulary shifts in the timeline are seam candidates — investigate them
- Event storming is discovery, not design — the system design follows after, informed by the map
- One session is rarely enough for a complex domain; plan for iteration
