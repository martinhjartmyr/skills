#!/usr/bin/env bash
set -euo pipefail

# umami-summary.sh - Fetch daily traffic summary from Umami analytics
#
# Usage:
#   bash umami-summary.sh              # Full daily summary with stats + active users
#   bash umami-summary.sh --active-only # Only fetch active user counts
#
# Environment variables:
#   UMAMI_API_URL   (required) Base URL, e.g. https://cloud.umami.is
#   UMAMI_API_KEY   (optional) API key (Cloud) - takes precedence
#   UMAMI_USERNAME  (optional) Username for self-hosted login
#   UMAMI_PASSWORD  (optional) Password for self-hosted login

ACTIVE_ONLY=false
if [[ "${1:-}" == "--active-only" ]]; then
  ACTIVE_ONLY=true
fi

err() {
  echo "{\"error\": \"$1\"}" >&2
  exit 1
}

# --- Validate env vars ---

if [[ -z "${UMAMI_API_URL:-}" ]]; then
  err "UMAMI_API_URL is not set"
fi

# Strip trailing slash
UMAMI_API_URL="${UMAMI_API_URL%/}"

if [[ -z "${UMAMI_API_KEY:-}" ]] && [[ -z "${UMAMI_USERNAME:-}" || -z "${UMAMI_PASSWORD:-}" ]]; then
  err "Set UMAMI_API_KEY (Cloud) or both UMAMI_USERNAME and UMAMI_PASSWORD (self-hosted)"
fi

# --- Check dependencies ---

for cmd in curl jq date; do
  command -v "$cmd" >/dev/null 2>&1 || err "$cmd is required but not found"
done

# --- Authenticate ---

TOKEN=""

if [[ -n "${UMAMI_API_KEY:-}" ]]; then
  TOKEN="$UMAMI_API_KEY"
else
  AUTH_RESPONSE=$(curl -sf --max-time 10 \
    -X POST "${UMAMI_API_URL}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"${UMAMI_USERNAME}\", \"password\": \"${UMAMI_PASSWORD}\"}" \
    2>/dev/null) || err "Authentication failed - could not connect to ${UMAMI_API_URL} or bad credentials"

  TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.token // empty')
  if [[ -z "$TOKEN" ]]; then
    err "Authentication failed - no token in response"
  fi
fi

AUTH_HEADER="Authorization: Bearer ${TOKEN}"

# --- Helper: API GET ---

api_get() {
  local url="$1"
  local response
  response=$(curl -sf --max-time 15 \
    -H "Accept: application/json" \
    -H "$AUTH_HEADER" \
    "$url" 2>/dev/null) || {
    err "API request failed: $url"
  }
  echo "$response"
}

# --- Fetch all websites (paginated) ---

WEBSITES="[]"
PAGE=1
PAGE_SIZE=100

while true; do
  RESPONSE=$(api_get "${UMAMI_API_URL}/api/websites?page=${PAGE}&pageSize=${PAGE_SIZE}&includeTeams=true")
  BATCH=$(echo "$RESPONSE" | jq '.data // []')
  COUNT=$(echo "$BATCH" | jq 'length')

  if [[ "$COUNT" -eq 0 ]]; then
    break
  fi

  WEBSITES=$(echo "$WEBSITES" "$BATCH" | jq -s '.[0] + .[1]')
  TOTAL=$(echo "$RESPONSE" | jq '.count // 0')
  FETCHED=$(echo "$WEBSITES" | jq 'length')

  if [[ "$FETCHED" -ge "$TOTAL" ]]; then
    break
  fi

  PAGE=$((PAGE + 1))
done

SITE_COUNT=$(echo "$WEBSITES" | jq 'length')

if [[ "$SITE_COUNT" -eq 0 ]]; then
  err "No websites found"
fi

# --- Compute time range: last 24 hours in UTC ms ---

NOW_S=$(date -u +%s)
START_S=$((NOW_S - 86400))
NOW_MS=$((NOW_S * 1000))
START_MS=$((START_S * 1000))

PREV_START_S=$((START_S - 86400))
PREV_START_MS=$((PREV_START_S * 1000))
PREV_END_MS=$((START_S * 1000))

# --- Fetch data for each website ---

RESULTS="[]"

for i in $(seq 0 $((SITE_COUNT - 1))); do
  SITE_ID=$(echo "$WEBSITES" | jq -r ".[$i].id")
  SITE_NAME=$(echo "$WEBSITES" | jq -r ".[$i].name")
  SITE_DOMAIN=$(echo "$WEBSITES" | jq -r ".[$i].domain")

  ENTRY="{\"id\": \"${SITE_ID}\", \"name\": $(echo "$SITE_NAME" | jq -Rs .), \"domain\": $(echo "$SITE_DOMAIN" | jq -Rs .)}"

  if [[ "$ACTIVE_ONLY" == "false" ]]; then
    STATS=$(api_get "${UMAMI_API_URL}/api/websites/${SITE_ID}/stats?startAt=${START_MS}&endAt=${NOW_MS}")

    # Handle both flat and nested response formats
    # Flat: {"pageviews": 123, ...}
    # Nested: {"pageviews": {"value": 123}, ...}
    STATS=$(echo "$STATS" | jq '{
      pageviews: (if .pageviews | type == "object" then .pageviews.value else .pageviews end // 0),
      visitors: (if .visitors | type == "object" then .visitors.value else .visitors end // 0),
      visits: (if .visits | type == "object" then .visits.value else .visits end // 0),
      bounces: (if .bounces | type == "object" then .bounces.value else .bounces end // 0),
      totaltime: (if .totaltime | type == "object" then .totaltime.value else .totaltime end // 0)
    }')

    ENTRY=$(echo "$ENTRY" "$STATS" | jq -s '.[0] + .[1]')

    PREV_STATS=$(api_get "${UMAMI_API_URL}/api/websites/${SITE_ID}/stats?startAt=${PREV_START_MS}&endAt=${PREV_END_MS}")
    PREV_STATS=$(echo "$PREV_STATS" | jq '{
      prev_pageviews: (if .pageviews | type == "object" then .pageviews.value else .pageviews end // 0),
      prev_visitors: (if .visitors | type == "object" then .visitors.value else .visitors end // 0),
      prev_visits: (if .visits | type == "object" then .visits.value else .visits end // 0),
      prev_bounces: (if .bounces | type == "object" then .bounces.value else .bounces end // 0),
      prev_totaltime: (if .totaltime | type == "object" then .totaltime.value else .totaltime end // 0)
    }')

    ENTRY=$(echo "$ENTRY" "$PREV_STATS" | jq -s '.[0] + .[1]')
  fi

  ACTIVE_RESPONSE=$(api_get "${UMAMI_API_URL}/api/websites/${SITE_ID}/active")
  ACTIVE_COUNT=$(echo "$ACTIVE_RESPONSE" | jq '.visitors // 0')
  ENTRY=$(echo "$ENTRY" | jq --argjson active "$ACTIVE_COUNT" '. + {active: $active}')

  RESULTS=$(echo "$RESULTS" | jq --argjson entry "$ENTRY" '. + [$entry]')
done

# --- Build output ---

if [[ "$ACTIVE_ONLY" == "true" ]]; then
  SUMMARY=$(echo "$RESULTS" | jq '{active: [.[].active] | add}')
  OUTPUT=$(jq -n \
    --arg period "now" \
    --argjson websites "$RESULTS" \
    --argjson summary "$SUMMARY" \
    '{period: $period, websites: $websites, summary: $summary}')
else
  SUMMARY=$(echo "$RESULTS" | jq '{
    pageviews: [.[].pageviews] | add,
    prev_pageviews: [.[].prev_pageviews] | add,
    visitors: [.[].visitors] | add,
    prev_visitors: [.[].prev_visitors] | add,
    visits: [.[].visits] | add,
    prev_visits: [.[].prev_visits] | add,
    bounces: [.[].bounces] | add,
    prev_bounces: [.[].prev_bounces] | add,
    totaltime: [.[].totaltime] | add,
    prev_totaltime: [.[].prev_totaltime] | add,
    active: [.[].active] | add
  }')

  PREV_START_ISO=$(date -u -r "$PREV_START_S" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$PREV_START_S" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "${PREV_START_S}")
  START_ISO=$(date -u -r "$START_S" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$START_S" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "${START_S}")
  END_ISO=$(date -u -r "$NOW_S" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$NOW_S" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "${NOW_S}")

  OUTPUT=$(jq -n \
    --arg prev_start "$PREV_START_ISO" \
    --arg start "$START_ISO" \
    --arg end "$END_ISO" \
    --argjson websites "$RESULTS" \
    --argjson summary "$SUMMARY" \
    '{period: {prev_start: $prev_start, start: $start, end: $end}, websites: $websites, summary: $summary}')
fi

echo "$OUTPUT"
