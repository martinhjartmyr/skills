---
name: overvy
description: Interact with the Overvy kanban board via curl. Use when the user wants to list issues, list AI tickets, work on a ticket, move issues between lanes, or check board status. Triggers include "overvy", "list AI tickets", "show me ready tickets", "what tickets are available", "what should I work on", "work on ticket", "work on any ticket", "pick a ticket", "start a ticket", "pick up an issue", "my issues", "kanban board", "move issue", "list issues", "board status", or references to lanes like "ready", "in progress", "in review", "done". Requires OVERVY_API_KEY environment variable.
---

# Overvy

Manage issues on a kanban board. Issues are sourced from connected GitHub repositories.

## API Configuration

- **Base URL**: `https://app.overvy.com/api/v1` (override with `OVERVY_API_URL` env var)
- **Auth**: `Authorization: Bearer $OVERVY_API_KEY`

At the start of any workflow, verify the API key is set:

```bash
test -n "$OVERVY_API_KEY" || echo "ERROR: OVERVY_API_KEY is not set"
```

If `OVERVY_API_KEY` is not set, stop and tell the user to set it.

## Key Details

- Only board issues are accessible. Backlog issues are not exposed.
- Lane types: `ready` (to do), `progress` (active), `review` (in review), `done` (complete).
- Each issue has `projectRef` (`owner/repo`) and `externalNumber` (GitHub issue number).

## API Operations

### List Workspaces

```bash
curl -s -f "${OVERVY_API_URL:-https://app.overvy.com/api/v1}/workspaces" \
  -H "Authorization: Bearer $OVERVY_API_KEY" \
  -H "Content-Type: application/json"
```

Returns: JSON array of workspaces, each with `id`, `name`, and `lanes` (array of `id`, `label`, `sortOrder`, `type`).

### List Issues

```bash
curl -s -f "${OVERVY_API_URL:-https://app.overvy.com/api/v1}/issues?lane=LANE&ai=AI" \
  -H "Authorization: Bearer $OVERVY_API_KEY" \
  -H "Content-Type: application/json"
```

Query parameters (all optional):

- `workspace` -- workspace UUID, defaults to first workspace
- `lane` -- filter by lane: `ready`, `progress`, `review`, `done`
- `ai` -- filter by AI-created issues: `true` or `false`

Omit query parameters you don't need. Returns: JSON array of issues, each with `id`, `title`, `state`, `ai`, `provider`, `projectRef`, `externalNumber`, `assignees`, `lane` (`id`, `label`, `type`), `sortOrder`.

### Move Issue

```bash
curl -s -f -X PATCH "${OVERVY_API_URL:-https://app.overvy.com/api/v1}/issues/ISSUE_ID/move" \
  -H "Authorization: Bearer $OVERVY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"lane": "TARGET_LANE"}'
```

Replace `ISSUE_ID` with the issue UUID and `TARGET_LANE` with one of: `ready`, `progress`, `review`, `done`.

## Error Handling

- All curl commands use `-f` to fail on HTTP errors.
- If a command fails, check the HTTP status by running without `-f` and adding `-w "\n%{http_code}"`.
- Common errors: 401 (bad API key), 404 (invalid issue ID or workspace), 422 (invalid lane).

## Workflow: List AI Tickets

List AI-created tickets in the "ready" lane so the user can pick one to work on.

1. Run:

```bash
curl -s -f "${OVERVY_API_URL:-https://app.overvy.com/api/v1}/issues?lane=ready&ai=true" \
  -H "Authorization: Bearer $OVERVY_API_KEY" \
  -H "Content-Type: application/json"
```

1. If the response is an empty array, tell the user there are no AI-ready tickets.
2. Present results as a numbered list in this format:

```
AI-ready tickets:

1. <title> (<projectRef>#<externalNumber>) -- id: <id>
2. <title> (<projectRef>#<externalNumber>) -- id: <id>
...

Say "work on ticket <number>" to start, or "work on any ticket" to pick the first one.
```

## Workflow: Work on Ticket

End-to-end flow: pick a ticket, implement it, create a PR, update the board.

Prerequisites: `gh` CLI authenticated with GitHub. Working directory is the repo matching the ticket's `projectRef`.

### 1. Select the ticket

- **User gave a number from the list output** -- use that ticket's `id`, `projectRef`, `externalNumber`.
- **User said "work on any ticket"** -- list issues with `lane=ready&ai=true` and pick the first result.
- **No tickets available** -- tell the user and stop.

Store: `issueId`, `projectRef`, `externalNumber`, `title`.

### 2. Move to in progress

```bash
curl -s -f -X PATCH "${OVERVY_API_URL:-https://app.overvy.com/api/v1}/issues/$ISSUE_ID/move" \
  -H "Authorization: Bearer $OVERVY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"lane": "progress"}'
```

This is mandatory -- always move before starting work.

### 3. Research the issue

```bash
gh issue view <externalNumber> --repo <projectRef>
```

Read the full issue body, comments, and labels. Understand what needs to be done before writing code.

### 4. Create a working branch

```bash
git checkout -b <prefix>/<externalNumber>-<short-description>
```

Use `fix/` for bugs, `feat/` for features, `chore/` for maintenance. Example: `fix/42-handle-null-response`.

### 5. Implement the changes

Follow existing codebase patterns. Run tests if available.

### 6. Create a pull request

```bash
git push -u origin HEAD
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary

<1-3 bullet points explaining what changed and why>

Closes <projectRef>#<externalNumber>
EOF
)"
```

- PR title should match or closely reflect the issue title.
- PR body must include `Closes <projectRef>#<externalNumber>` (full `owner/repo#N` format).

### 7. Move to in review

```bash
curl -s -f -X PATCH "${OVERVY_API_URL:-https://app.overvy.com/api/v1}/issues/$ISSUE_ID/move" \
  -H "Authorization: Bearer $OVERVY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"lane": "review"}'
```

This is mandatory -- always move after the PR is created.

### 8. Report

```
Done. Worked on: <title> (<projectRef>#<externalNumber>)
PR: <pr-url>
Board: moved to "In Review"
```
