# Agents: Code Execution Sandbox

## Overview
Agents that execute code on behalf of users are running arbitrary instructions on a machine. Without sandboxing, a user (or a tool-use chain that processes untrusted input) can read sensitive files, exfiltrate data, delete files, or spawn persistent processes. Sandboxing is non-negotiable for any system that executes user-provided or LLM-generated code.

## Sandbox Requirements

**Process isolation**
- Execute code in a subprocess, not via eval() or exec() in the host process
- Use an isolated process with no access to the host's file system, environment variables, or network (unless explicitly required)
- Containers (Docker) or VMs provide the strongest isolation; subprocess with restricted capabilities is a lighter option

**Resource limits**
Set hard limits before spawning:
- CPU time: max execution time (wall clock, not just CPU usage — loops can bypass CPU limits)
- Memory: OOM kill threshold
- Disk writes: disallow or limit to /tmp within sandbox
- Open file descriptors: limit to prevent descriptor exhaustion
- Network: block outbound by default; whitelist specific hosts if required

**Timeout enforcement**
- SIGKILL (not SIGTERM) on timeout — SIGTERM can be caught and ignored by the process
- Timeout must be enforced by the parent process, not the subprocess
- Default timeout: 10–30 seconds for interactive code; longer for batch jobs with explicit justification

**Stdout/stderr capture**
- Capture separately
- Limit output size (truncate after N bytes) — buggy code can write infinite output
- Return both to the caller; never discard stderr (it often contains the meaningful error)

## Strong Isolation via Docker

For maximum isolation, run code in a throwaway container:

  docker run --rm \
    --network=none \
    --memory=256m \
    --cpus=0.5 \
    --read-only \
    --tmpfs /tmp:size=50m \
    python:3.12-slim python3 -c "<code>"

Flags explained:
- --network=none: no outbound or inbound network
- --memory=256m: hard memory cap
- --read-only: filesystem is read-only (writes only to tmpfs /tmp)
- --rm: container auto-deleted after exit

## What Never to Do

- Never eval() LLM-generated code in the host process
- Never pass host environment variables into the sandbox (contains secrets)
- Never allow sandbox access to the same filesystem as the agent (file system escapes are real)
- Never use SIGTERM as the timeout kill signal — use SIGKILL
- Never trust that the sandbox cannot break out — apply defense-in-depth

## Output Handling

The sandbox output is user-controlled data — treat it as untrusted when using in downstream steps:
- Do not render sandbox output as HTML without sanitization
- Do not pass sandbox stdout directly as a shell command argument
- Validate expected output format (JSON, CSV) before parsing

## Key Rules

- Sandbox every code execution without exception
- SIGKILL on timeout — SIGTERM allows malicious processes to ignore the signal
- Capture stdout AND stderr — discard neither
- Minimal environment: no host env vars, no host filesystem mount, no host network by default
- Log all code execution: input hash, execution time, return code, output size — for audit trail
- Never trust sandbox output — it is user-controlled data
