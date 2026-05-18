# Agent Tool Selection

## The Core Rule

Match the tool to the job. Using a heavy tool for a simple task wastes tokens and time. Using a weak tool for a complex task produces wrong results.

## Tool Selection by Task

| Task | Right Tool | Wrong Tool |
|---|---|---|
| Read a known file | `Read` | `Bash cat` |
| Read unknown files in a directory | `Bash ls`, then `Read` | `Bash cat *` |
| Edit a specific section | `Edit` | `Write` (full rewrite) |
| Create a new file | `Write` | `Bash echo >>` |
| Find files by pattern | `Bash find` or `Glob` | Reading every directory |
| Search for a string in files | `Bash grep` | Opening each file to check |
| Run tests or builds | `Bash` | Reading test files manually |
| Explore unknown codebase | `Agent(Explore)` | Reading files one by one |
| Multi-file research | `Agent` | Sequential tool calls |

## Read vs Bash cat

Always prefer `Read` for reading files — it provides line numbers, respects the tool harness, and surfaces permission prompts cleanly. `cat` output has no line numbers and clutters bash output.

Exception: When you need multiple files concatenated for a single pipeline command, `cat` makes sense.

## Edit vs Write

- **Edit**: Surgical replacement of a specific string. Fails if the string isn't unique — good, because it means you're being precise.
- **Write**: Overwrites the entire file. Use only for creating new files or when the change is so large that the entire file needs to be rewritten.

Before using `Write` on an existing file: `Read` it first. The harness requires this. `Write` without a prior `Read` will be blocked.

## Bash Find vs Glob

Use `Bash find` when:
- You need complex filtering (by date, size, type combination)
- You need to execute commands on results (`-exec`)

Use `Glob` when:
- You have a simple file pattern (`**/*.ts`, `src/components/*.tsx`)
- You just need the list of matching paths

## Agent vs Direct Tool Calls

Spawn an `Agent(Explore)` when:
- The research spans more than 3 directory locations
- You don't know where something is defined
- You need to understand patterns across the whole codebase

Do it yourself when:
- You know the file path already (use `Read`)
- You know the symbol to search for (use `grep`)
- It's a single targeted lookup

Spawning agents has overhead. Don't spawn for simple lookups.

## Parallel Tool Calls

When multiple independent pieces of information are needed, call tools in parallel:

```
// SLOW — sequential:
1. Read file A
2. Read file B
3. Read file C

// FAST — parallel:
Read(A), Read(B), Read(C)  // all in one message
```

Tools are independent when: the result of one is NOT needed to know what to call next.

Tools are sequential when: the output of one determines the input of the next.

## Grep Pattern

When searching, make the pattern specific enough to not produce hundreds of results:

```bash
# TOO BROAD — matches everywhere:
grep -r "import" src/

# SPECIFIC — what you actually need:
grep -r "from '@/lib/supabase/admin'" src/

# WITH FILE TYPE FILTER:
grep -r "useQuery" --include="*.tsx" src/components/

# WITH CONTEXT LINES:
grep -rn "getSession" --include="*.ts" -A2 -B2 src/
```

## When to Read the Whole File

Read the whole file when:
- You need to understand overall structure before making changes
- The change touches multiple sections
- You're debugging and don't know where the issue is

Skip full reads when:
- You know exactly which function or line to change
- `grep` already showed you the relevant context

Reading large files wastes context window. When a file is large (>300 lines), consider reading specific sections with `offset` and `limit` parameters.

## MCP Tool Selection

MCP tools (Supabase, Vercel, Cloudflare) are the right choice when:
- You need to query actual live data (not static files)
- You're making service-level changes (deploy, create branch)
- CLI tools aren't available in the current environment

Don't use MCP tools to read data that's already in source files — that's slower and uses more tokens.
