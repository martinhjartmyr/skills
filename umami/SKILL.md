---
name: umami
description: "Fetch analytics from Umami. Use when the user asks about umami, analytics, website traffic, daily stats, pageviews, visitors, how is my site doing, traffic report, site performance, bounce rate, visitor count, active users, who is on my site, or website statistics."
metadata:
  version: 1.0.0
allowed-tools:
  - Bash(bash */umami-summary.sh*)
---

# Umami Analytics

Fetch traffic summaries and analytics data from an Umami instance.

## Configuration

Set these environment variables before running:

| Variable         | Required      | Description                                                     |
| ---------------- | ------------- | --------------------------------------------------------------- |
| `UMAMI_API_URL`  | Yes           | Base URL of your Umami instance (e.g. `https://cloud.umami.is`) |
| `UMAMI_API_KEY`  | One of these  | API key for Umami Cloud. Used as Bearer token directly.         |
| `UMAMI_USERNAME` | One of these  | Username for self-hosted login via `/api/auth/login`.           |
| `UMAMI_PASSWORD` | With username | Password for self-hosted login.                                 |

If `UMAMI_API_KEY` is set, it takes precedence over username/password.

## Workflow: Daily Traffic Summary

1. Run the script:
   ```bash
   bash ~/Projects/skills/umami/scripts/umami-summary.sh
   ```
2. Parse the JSON output.
3. Format as a markdown table:

| Website    | Domain           | Pageviews       | Visitors      | Visits        | Bounces       | Avg Time      | Active |
| ---------- | ---------------- | --------------- | ------------- | ------------- | ------------- | ------------- | ------ |
| My Blog    | blog.example.com | 1,234 (980)     | 567 (510)     | 890 (801)     | 123 (110)     | 45s (38s)     | 3      |
| **Totals** |                  | **1,234 (980)** | **567 (510)** | **890 (801)** | **123 (110)** | **45s (38s)** | **3**  |

- Show previous period values in parentheses after each metric (e.g. "1,234 (980)" means 1,234 current, 980 previous).
- Format numbers with commas for readability.
- Convert `totaltime` to human-readable duration (e.g. "1m 23s").
- Calculate average time as `totaltime / visits` for each site, using `prev_totaltime / prev_visits` for the previous period.
- Bold the totals row.

## Workflow: Active Users Only

For "who is on my site right now?" queries, use the lightweight flag:

```bash
bash ~/Projects/skills/umami/scripts/umami-summary.sh --active-only
```

This skips the stats API calls and only fetches current active visitor counts. Format as a simpler table:

| Website | Domain           | Active |
| ------- | ---------------- | ------ |
| My Blog | blog.example.com | 3      |

## Error Handling

The script exits non-zero and writes JSON to stderr on failure:

- **Missing env vars**: `{"error": "UMAMI_API_URL is not set"}`
- **Auth failure**: `{"error": "Authentication failed (HTTP 401)"}`
- **Unreachable server**: `{"error": "Could not connect to https://..."}`

Report these errors clearly to the user with the specific message. Suggest checking their environment variables.

## API Reference

For queries beyond the daily summary (time series, metrics breakdowns, custom date ranges), see [references/api.md](references/api.md).
