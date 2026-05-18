# MCP: Microsoft Docs Patterns

## Overview

The Microsoft Learn MCP provides access to official Microsoft and Azure documentation. Use it for: Azure service configuration, .NET APIs, Microsoft 365 integration, TypeScript/JavaScript SDK usage.

## Three Tools

### microsoft_docs_search

Fast search returning up to 10 doc excerpts (500 tokens each):

```
Tool: microsoft_docs_search
  query: "Azure Blob Storage upload file Node.js"

→ Returns: title, URL, excerpt for each match
```

Use first — gives breadth across multiple docs pages.

### microsoft_code_sample_search

Finds code examples specifically:

```
Tool: microsoft_code_sample_search
  query: "Azure Blob Storage upload"
  language: "javascript"

→ Returns: up to 20 code samples with context
```

Supports `language` filter: `javascript`, `typescript`, `python`, `csharp`, `java`, `powershell`.

### microsoft_docs_fetch

Full page content when you need details:

```
Tool: microsoft_docs_fetch
  url: "https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-nodejs"

→ Returns: full page as markdown
```

Use after search — when an excerpt isn't enough and you need the complete guide.

## Workflow

```
1. microsoft_docs_search → find which page covers your topic
2. microsoft_code_sample_search → get relevant code examples
3. microsoft_docs_fetch → get full page if you need complete setup steps
```

Don't fetch pages blindly. Search first to identify the right page, then fetch only if needed.

## Common Query Patterns

### Azure Services

```
Query patterns that work well:
- "Azure [ServiceName] [operation] [language]"
- "Azure Key Vault get secret Node.js SDK"
- "Azure Service Bus send message TypeScript"
- "Azure SQL Database connection string"
- "Azure Functions trigger [type] example"
```

### Authentication / Entra ID (formerly Azure AD)

```
- "Microsoft Entra ID OAuth 2.0 access token"
- "MSAL Node.js client credentials flow"
- "Azure AD app registration API permissions"
- "Microsoft Graph API authentication"
```

### Microsoft Graph

```
- "Microsoft Graph send email Node.js"
- "Graph API user calendar events"
- "Microsoft Graph webhooks setup"
```

## SDK Version Matters

Azure SDK is in the `@azure/*` namespace. When looking up docs, specify the SDK version context:

```
microsoft_code_sample_search
  query: "@azure/storage-blob upload BlobServiceClient"
  language: "typescript"
```

Using the package name in the query helps find examples that match the current SDK (v12+) rather than legacy SDKs.

## Finding Configuration References

For environment variables, connection strings, or configuration options:

```
microsoft_docs_search
  query: "Azure Cosmos DB connection string format"

→ Returns the exact format with placeholders
```

Always verify format against docs — connection strings vary by service and auth method.

## REST API vs SDK

Microsoft has both REST API docs and SDK docs. For most use cases, prefer SDK:

```
Prefer: "Azure Blob Storage SDK BlobClient upload"
Over:   "Azure Blob Storage REST API PUT blob"
```

Unless you're implementing a client from scratch, SDK docs have more relevant examples.

## Limitations

- Docs may lag behind latest SDK releases by 1-2 weeks
- Code samples may use older async patterns (callbacks, not promises) — check the date
- Architecture diagrams and interactive content aren't returned in text
- PowerShell examples may use legacy `AzureRM` instead of current `Az` module
