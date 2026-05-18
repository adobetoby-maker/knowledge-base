# Notion MCP — Workflow Patterns

## Core Capabilities

The Notion MCP lets you create and update pages, query databases with filters and sorts, update page properties, and append content blocks. Every Notion operation requires knowing the target's ID — get it from the URL (the 32-character hex string) or by searching.

## Creating Pages

To create a page inside a database, supply the database ID as `parent.database_id` and populate `properties` with values matching the database's schema. Property keys are case-sensitive and must match the database column names exactly.

```
create_page(
  parent: { database_id: "abc123..." },
  properties: {
    "Name": { title: [{ text: { content: "Sprint 14 Review" } }] },
    "Status": { select: { name: "In Progress" } },
    "Due Date": { date: { start: "2026-05-25" } }
  }
)
```

To create a standalone page (not in a database), use `parent.page_id` pointing to a parent page.

## Querying Databases

Use `query_database` with `filter` and `sorts` to retrieve targeted records rather than fetching everything and filtering client-side. Notion's filter API supports property filters, compound `and`/`or`, and formula/rollup filters.

```
query_database(
  database_id: "def456...",
  filter: {
    and: [
      { property: "Status", select: { equals: "In Progress" } },
      { property: "Assignee", people: { contains: "user-id-here" } }
    ]
  },
  sorts: [{ property: "Due Date", direction: "ascending" }]
)
```

Always paginate large databases — pass `start_cursor` from the previous response's `next_cursor` field. Stop when `has_more` is false.

## Updating Page Properties

`update_page` patches only the properties you specify — it does not replace the entire page. Use this to change status, assign a date, or update a checkbox without touching other fields.

```
update_page(
  page_id: "page-id-here",
  properties: {
    "Status": { select: { name: "Done" } },
    "Completed At": { date: { start: "2026-05-18" } }
  }
)
```

## Appending Blocks

`append_block_children` adds content to an existing page. Each block has a `type` field that determines its shape. Paragraph, heading_1/2/3, bulleted_list_item, numbered_list_item, code, and toggle are the common types.

```
append_block_children(
  block_id: "page-or-block-id",
  children: [
    { type: "heading_2", heading_2: { rich_text: [{ text: { content: "Summary" } }] } },
    { type: "paragraph", paragraph: { rich_text: [{ text: { content: "Deploy completed at 14:32 UTC." } }] } }
  ]
)
```

## Syncing Project Status to a Notion Database

Workflow: a project reaches a milestone → update the project's Notion database row.

1. `query_database` with a filter on the project name to find the existing page ID.
2. If found: `update_page` with the new status property and a timestamp.
3. If not found: `create_page` in the database with the full initial property set.
4. Optionally `append_block_children` to the page with a changelog entry block.

Do not overwrite the entire page on every sync — use property patches so manual edits in Notion are not clobbered.

## Common Mistakes

- Fetching an entire database to find one record — always filter at the query level.
- Using display names for properties that have different internal names — verify property names with a `retrieve_database` call first.
- Appending blocks without checking if a section already exists — you will create duplicate content on repeated syncs.
- Treating `next_cursor` as optional — large databases silently truncate results without it.

## Key Rules

- **Always filter `query_database` calls** — never fetch all records and filter in memory.
- **Use `update_page` for property changes**, not a full page replacement.
- **Verify database property names** with `retrieve_database` before writing — case and spacing must match exactly.
- Paginate all database queries using `start_cursor` / `has_more` — results cap at 100 per request.
- When syncing external data to Notion, store the Notion page ID in your system so you can `update_page` rather than searching on every sync.
