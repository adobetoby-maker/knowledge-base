# MCP: Gmail and Google Drive

## Gmail Tools

```
mcp__claude_ai_Gmail__search_threads(query, maxResults)
mcp__claude_ai_Gmail__get_thread(threadId)
mcp__claude_ai_Gmail__create_draft(to, subject, body)
mcp__claude_ai_Gmail__list_labels
mcp__claude_ai_Gmail__label_thread(threadId, labelIds)
mcp__claude_ai_Gmail__create_label(name, color)
```

## Searching Email

```
search_threads("from:pablo@example.com subject:invoice")
search_threads("newer_than:7d label:inbox is:unread")
search_threads("from:stripe.com subject:payment")
```

Gmail search operators:
- `from:email` — from sender
- `to:email` — sent to
- `subject:text` — subject contains
- `label:name` — has this label
- `is:unread` — unread messages
- `newer_than:7d` — last 7 days
- `has:attachment` — has files
- `-label:spam` — exclude label

## Reading Thread Content

```
search_threads("from:client@company.com subject:project update")
→ Returns list with threadId values

get_thread("thread_id_here")
→ Returns full conversation with all messages, bodies, attachments metadata
```

## Creating Drafts

```
create_draft(
  to="client@company.com",
  subject="Invoice #1234 from Jr's Auto Repair",
  body="Hi Pablo,\n\nYour invoice is ready...\n\nBest,\nJr's Auto Repair"
)
```

This creates a draft in Gmail that you can review and send manually. Never auto-send without review — drafts give humans a checkpoint.

## Label-Based Organization

```
# Create a label
create_label("project-updates", color="blue")

# Apply label to thread
label_thread(threadId, [labelId])
```

## Google Drive Tools

```
mcp__claude_ai_Google_Drive__search_files(query)
mcp__claude_ai_Google_Drive__read_file_content(fileId)
mcp__claude_ai_Google_Drive__download_file_content(fileId)
mcp__claude_ai_Google_Drive__get_file_metadata(fileId)
mcp__claude_ai_Google_Drive__list_recent_files
mcp__claude_ai_Google_Drive__create_file(name, mimeType, content, parentFolderId)
mcp__claude_ai_Google_Drive__copy_file(fileId, name, parentFolderId)
```

## Searching Drive

```
search_files("blueprint client project name")
search_files("mimeType='application/vnd.google-apps.spreadsheet'")
search_files("modifiedTime > '2026-05-01T00:00:00'")
```

Google Drive query operators:
- `name contains 'text'`
- `fullText contains 'text'`
- `mimeType = 'application/pdf'`
- `'folder_id' in parents` — files in folder
- `trashed = false` — exclude trash

## Reading File Content

```
# Google Docs, Sheets, etc. — returns as plain text
read_file_content(fileId)

# Binary files (PDFs, images) — downloads content
download_file_content(fileId)
```

## Common Use Cases

### Check client email for project requirements
```
search_threads("from:client@email.com newer_than:30d")
get_thread(threadId)
```

### Find a Google Sheet with project data
```
search_files("project data sheet mimeType='application/vnd.google-apps.spreadsheet'")
read_file_content(fileId)
```

### Create a draft response to a client
```
# Read their message first
search_threads("from:client label:inbox is:unread")
get_thread(threadId)

# Draft a response (don't send automatically)
create_draft(
  to=clientEmail,
  subject=replySubject,
  body=draftBody
)
```

Note: Gmail MCP cannot send email directly — only create drafts. This is intentional — all outgoing email should have a human review before delivery.
