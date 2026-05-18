# Principle: Customer Feedback Loops

## Overview
Customer feedback is the correction signal for product direction. Without it, the product drifts toward what the team finds interesting rather than what solves real customer problems. The failure mode is not lacking feedback — it's having feedback and not acting on it (or acting on it literally rather than solving the underlying need).

## Implementation / Key Points

### Feedback Sources (Use All, Not Just One)
```
Quantitative:
  - NPS (monthly, post-value-moment)
  - In-app micro-surveys ("Is this feature useful?")
  - Feature adoption rates (are people using what was built?)
  - Support ticket themes (aggregate, not individual)
  - Feature request vote counts

Qualitative:
  - User interviews (monthly, 5–8 users per interview cycle)
  - Beta program (power users who get early access)
  - Customer advisory board (4–6 key accounts, quarterly)
  - Churn exit surveys (every churned customer gets one)
```

### User Interviews (Monthly Cadence)
A 30-minute structured interview reveals more than 1,000 survey responses. Goals:
1. Observe how they use the product (screen share)
2. Ask about their top frustrations
3. Ask what they wish the product did that it currently doesn't
4. Ask what would make them leave

```
Interview guide template:
  "Tell me about the last time you used [feature]."
  "What happened when you tried to [task]? Walk me through it."
  "If you could change one thing about this product, what would it be?"
  "What would cause you to stop using this product?"
```
Never ask "would you use X?" — people answer yes to hypotheticals. Ask about past behavior.

### Support Ticket Themes
```ts
// Weekly: categorize support tickets into themes
// Don't read individual tickets — count themes
const themes = {
  'cannot_find_feature': 23,      // UX/discoverability problem
  'billing_confusion': 12,        // pricing page problem
  'import_fails': 8,              // reliability problem
  'api_rate_limits': 6,           // pricing tier problem
};

// Top theme this week drives one action item, not many
```

### Feature Request Voting
Use a public roadmap tool (Canny, ProductBoard, Linear) where customers vote on requests. The vote count is a proxy for demand — it does not capture intensity or segment.

### The Underlying Need Trap
When a customer requests "CSV export," the underlying need might be:
- Sharing data with their accountant
- Importing data into another tool
- Keeping a backup copy

Ask "what would you do with that?" before building. The right solution might be a native integration, not CSV export.

### Closing the Loop
```
When you ship something that came from customer feedback:
1. Notify users who requested it (via product announcement or personal email for top requesters)
2. Update the feature request thread with "shipped in v2.4"
3. Ask them to validate it solved their need

This converts customers into advocates and incentivizes future feedback.
```

## Key Rules
- Collect feedback from at least 3 different sources — no single channel gives the full picture.
- User interviews must happen monthly, not "when we have time."
- Churn exit surveys are mandatory — loss is the most honest feedback.
- Identify the underlying need before designing a solution to a literal request.
- Close the loop: tell customers what was shipped from their feedback.
- Support ticket themes are input to the product roadmap, reviewed weekly.
- Feature request votes are a demand signal, not a specification — they tell you what, not why or how.
