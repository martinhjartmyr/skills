# Umami API Reference

Base URL: `{UMAMI_API_URL}/api`

All requests require `Authorization: Bearer <token>` header.

## Authentication

### POST /api/auth/login

Self-hosted only. Cloud uses API key directly as Bearer token.

**Request:**
```json
{"username": "admin", "password": "secret"}
```

**Response:**
```json
{
  "token": "eyJ...",
  "user": {"id": "uuid", "username": "admin", "role": "admin", "isAdmin": true}
}
```

### POST /api/auth/verify

Validate whether a token is still active. Returns user object on success.

## Websites

### GET /api/websites

List all websites for the authenticated user.

| Param | Type | Default | Description |
|---|---|---|---|
| `includeTeams` | boolean | false | Include team-owned websites |
| `search` | string | | Filter by name/domain |
| `page` | number | 1 | Page number |
| `pageSize` | number | 10 | Results per page |

**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "My Site",
      "domain": "example.com",
      "shareId": null,
      "resetAt": null,
      "userId": "uuid",
      "teamId": null,
      "createdAt": "2024-01-01T00:00:00.000Z"
    }
  ],
  "count": 1,
  "page": 1,
  "pageSize": 10
}
```

### GET /api/websites/:websiteId

Get a single website by ID. Returns same object shape as list item.

### POST /api/websites

Create a website. Body: `{"name": "...", "domain": "..."}`.

### POST /api/websites/:websiteId

Update a website. Body: partial fields to update.

### DELETE /api/websites/:websiteId

Delete a website.

### POST /api/websites/:websiteId/reset

Clear all tracking data for a website.

## Website Statistics

All stat endpoints accept common filter parameters:

| Param | Type | Description |
|---|---|---|
| `startAt` | number | Start timestamp in UTC milliseconds |
| `endAt` | number | End timestamp in UTC milliseconds |
| `path` | string | Filter by URL path |
| `referrer` | string | Filter by referrer |
| `title` | string | Filter by page title |
| `query` | string | Filter by query string |
| `browser` | string | Filter by browser |
| `os` | string | Filter by operating system |
| `device` | string | Filter by device type |
| `country` | string | Filter by country code |
| `region` | string | Filter by region |
| `city` | string | Filter by city |
| `hostname` | string | Filter by hostname |
| `tag` | string | Filter by custom tag |

### GET /api/websites/:websiteId/stats

Aggregate stats for a date range.

**Required:** `startAt`, `endAt`

**Response:**
```json
{
  "pageviews": 15171,
  "visitors": 4415,
  "visits": 5680,
  "bounces": 3567,
  "totaltime": 809968
}
```

Some API versions return nested format:
```json
{
  "pageviews": {"value": 15171, "prev": 12000},
  "visitors": {"value": 4415, "prev": 3800}
}
```

### GET /api/websites/:websiteId/active

Current active visitors (last 5 minutes). No parameters required.

**Response:**
```json
{"visitors": 5}
```

### GET /api/websites/:websiteId/pageviews

Time series of pageviews and sessions.

**Required:** `startAt`, `endAt`, `unit`

| Param | Type | Values |
|---|---|---|
| `unit` | string | `minute` (up to 60m), `hour` (up to 30d), `day` (up to 6mo), `month`, `year` |
| `timezone` | string | e.g. `America/Los_Angeles` |
| `compare` | string | `prev` (previous period) or `yoy` (year-over-year) |

**Response:**
```json
{
  "pageviews": [{"x": "2025-01-01T00:00:00Z", "y": 4129}],
  "sessions": [{"x": "2025-01-01T00:00:00Z", "y": 1397}]
}
```

### GET /api/websites/:websiteId/metrics

Top values for a given metric type.

**Required:** `startAt`, `endAt`, `type`

| Type value | Description |
|---|---|
| `path` | URL paths |
| `entry` | Entry pages |
| `exit` | Exit pages |
| `title` | Page titles |
| `query` | Query strings |
| `referrer` | Referrer URLs |
| `channel` | Traffic channels |
| `domain` | Referrer domains |
| `country` | Country codes |
| `region` | Regions |
| `city` | Cities |
| `browser` | Browsers |
| `os` | Operating systems |
| `device` | Device types |
| `language` | Languages |
| `screen` | Screen sizes |
| `event` | Custom events |
| `hostname` | Hostnames |
| `tag` | Custom tags |

**Optional:** `limit` (default 500), `offset` (default 0)

**Response:**
```json
[{"x": "Chrome", "y": 1918}]
```

### GET /api/websites/:websiteId/metrics/expanded

Same parameters as `/metrics` but returns detailed breakdown.

**Response:**
```json
[
  {
    "name": "Chrome",
    "pageviews": 74020,
    "visitors": 16982,
    "visits": 24770,
    "bounces": 15033,
    "totaltime": 149156302
  }
]
```

### GET /api/websites/:websiteId/events/series

Event counts over time.

**Required:** `startAt`, `endAt`, `unit`

**Response:**
```json
[{"x": "button-click", "t": "2025-01-01T00:00:00Z", "y": 42}]
```

## Example Queries

**Last 7 days stats:**
```bash
START=$(($(date -u +%s) * 1000 - 604800000))
END=$(($(date -u +%s) * 1000))
curl -H "Authorization: Bearer $TOKEN" \
  "$URL/api/websites/$ID/stats?startAt=$START&endAt=$END"
```

**Top 10 pages today:**
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "$URL/api/websites/$ID/metrics?startAt=$START&endAt=$END&type=path&limit=10"
```

**Hourly pageviews for past week:**
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "$URL/api/websites/$ID/pageviews?startAt=$START&endAt=$END&unit=hour&timezone=UTC"
```

**Traffic from a specific country:**
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "$URL/api/websites/$ID/stats?startAt=$START&endAt=$END&country=US"
```
