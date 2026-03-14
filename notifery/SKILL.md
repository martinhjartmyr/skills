---
name: notifery
description: Send notifications via Notifery API using curl. Use when the user wants to be notified about task completions, errors, or progress. Also use proactively after long-running tasks, failed operations, or when the user has asked to be kept informed. Triggers include "notify me", "send notification", "let me know when done", "alert me", "ping me", "notifery", or when a long task completes and the user previously asked for notifications. Requires NOTIFERY_API_KEY environment variable.
---

# Notifery

Send notifications to the user via the Notifery API.

## API Configuration

- **Base URL**: `https://api.notifery.com` (override with `NOTIFERY_API_URL` env var)
- **Auth**: `x-api-key: $NOTIFERY_API_KEY`

At the start of any workflow, verify the API key is set:

```bash
test -n "$NOTIFERY_API_KEY" || echo "ERROR: NOTIFERY_API_KEY is not set"
```

If `NOTIFERY_API_KEY` is not set, stop and tell the user to set it.

## Key Details

- `title` is the only required field.
- If `NOTIFERY_DEFAULT_GROUP` is set and no `group` is provided, use it as the default group.

## API Operations

### Send Notification

```bash
curl -s -f -X POST "${NOTIFERY_API_URL:-https://api.notifery.com}/event" \
  -H "x-api-key: $NOTIFERY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "TITLE",
    "message": "MESSAGE",
    "group": "GROUP"
  }'
```

Only include fields that have values. Omit fields that are not needed.

**Parameters:**

| Parameter | Type   | Required | Description                                           |
| --------- | ------ | -------- | ----------------------------------------------------- |
| title     | string | Yes      | Notification title (1-255 chars)                      |
| message   | string | No       | Body text (max 2048 chars)                            |
| group     | string | No       | Group alias (falls back to `NOTIFERY_DEFAULT_GROUP`)  |
| code      | number | No       | Status code: 0 = success, >0 = error                 |
| duration  | number | No       | Duration in milliseconds                              |
| ttl       | number | No       | Auto-expiry in seconds (60-31536000)                  |
| icon      | string | No       | Icon name                                             |
| iconColor | string | No       | Hex color for icon (e.g. "ff0000")                    |

**Response:** `{ "ok": true }` on success.

## Error Handling

- All curl commands use `-f` to fail on HTTP errors.
- If a command fails, check the HTTP status by running without `-f` and adding `-w "\n%{http_code}"`.
- Common errors: 401 (bad API key), 422 (invalid parameters).

## Proactive Usage

Send notifications proactively in these situations:

- After a long-running task completes (build, deploy, migration).
- When a task fails with an error.
- When the user explicitly asked to be notified ("let me know when done").

When sending proactively, use `code: 0` for success and `code: 1` for errors.

### Example: Task Completion

```bash
curl -s -f -X POST "${NOTIFERY_API_URL:-https://api.notifery.com}/event" \
  -H "x-api-key: $NOTIFERY_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"Build complete\",
    \"message\": \"Project built successfully in 42s\",
    \"code\": 0,
    \"duration\": 42000
  }"
```

### Example: Task Failure

```bash
curl -s -f -X POST "${NOTIFERY_API_URL:-https://api.notifery.com}/event" \
  -H "x-api-key: $NOTIFERY_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"Deploy failed\",
    \"message\": \"Error: container health check timed out\",
    \"code\": 1
  }"
```
