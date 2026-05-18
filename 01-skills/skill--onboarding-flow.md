# Skill: User Onboarding Flow

## Purpose
Move a newly signed-up user to their first activation event as quickly as possible. Activation is the moment they experience the core value of the product (sent first invoice, connected first data source, invited a teammate). Every step before activation is friction. The goal is to minimize friction, not to collect information.

## Progressive Profiling — Collect Only What You Need Now
The biggest onboarding mistake is front-loading a 10-question form. Ask for each piece of information at the moment it's needed:
- **At signup**: email + password (or OAuth). Nothing else.
- **First login**: name and account name. Optional: role/use-case to personalize.
- **Before first core action**: whatever that action requires (e.g., company name before first invoice).
- **Later, in settings**: billing, team preferences, integrations.

If a field isn't needed to reach the activation event, don't collect it during onboarding. "Complete your profile" prompts can live in settings forever — they don't block activation.

## Step Persistence
Store each completed step in the DB, not just in the session or localStorage. Users switch devices, clear cookies, and come back days later. When they return, resume where they left off — don't restart the flow.

```sql
onboarding_progress (
  user_id uuid primary key,
  completed_steps text[],   -- ['profile', 'first_project']
  activated_at timestamptz, -- null until activation event fires
  updated_at timestamptz
)
```

Once `activated_at` is set, stop showing onboarding UI entirely. Don't re-show steps the user has already completed.

## Skippable Steps
Every step except the absolute minimum should be skippable. Some users know what they're doing and resent being guided through basics. A skip doesn't mean they won't come back — it means they want to explore on their own terms. Track skipped steps so you can surface them later with contextual nudges ("You skipped the integration setup — connect your tools in Settings").

Never block navigation to the main app during onboarding. The checklist is a guide, not a gate.

## Activation Event Definition
Define one activation event before building onboarding. It must be:
- A specific, measurable action (not "used the app for 5 minutes")
- Correlated with long-term retention in your cohort analysis
- Reachable in a single session for a motivated user

Examples: "created and published first post," "sent first invoice," "ran first query." Once a user fires this event, mark `activated_at` and switch them from onboarding mode to normal mode.

## Email Nudge Sequence for Incomplete Onboarding
Trigger this sequence only for users who signed up but haven't activated:
- **Day 1** (4h after signup): "Ready to get started?" — direct link to where they left off
- **Day 3**: Highlight a specific feature with social proof ("Teams using X save 3h/week")
- **Day 7**: "Need help?" — offer a quick demo or live chat
- **Day 14**: Breakup email — "Is this still relevant?" with an unsubscribe option

Stop the sequence immediately on activation. Never send step-reminders after the user has activated — it signals you don't know they're already using the product, which erodes trust.

## Success Metric
The only metric that matters for onboarding: **activation rate** = (users who reached the activation event) / (users who signed up) within a given window (typically 7 or 14 days). Track this per cohort, per traffic source, per plan type. A/B test onboarding steps against this metric, not against "completed step 2."

## Checklist UI
A persistent checklist (like Intercom's Product Tours or a custom sidebar widget) is more effective than a linear wizard for non-linear products. Users can complete steps in any order. Check off steps as they complete them. Show progress (3 of 5 complete). Auto-collapse the checklist once all steps are done.

## Key Rules
- **Ask for each field at the moment it's needed** — front-loading forms kills activation
- **Persist progress to the DB** — users return from different devices and clear cookies
- **Define the activation event before building** — it shapes every step's prioritization
- **Stop onboarding sequences at activation** — sending step reminders to active users is a trust destroyer
- **Make every non-critical step skippable** — a guide, not a gate
- **Measure activation rate, not completion rate** — completing the checklist without activating is a vanity metric
