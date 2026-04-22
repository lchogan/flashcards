# Sync wire format

Every synced entity payload uses these shared envelope fields on top of per-entity attributes.

| Field | Type | Notes |
|---|---|---|
| `id` | UUID string | Client-generated (UUIDv7 preferred). |
| `updated_at_ms` | int64 | Milliseconds since epoch. Monotonic per-client. |
| `deleted_at_ms` | int64 or null | null = live; non-null = tombstone. |

## Push
`POST /api/v1/sync/push`
```json
{
  "client_clock_ms": 1713700000000,
  "records": {
    "decks":      [ { "id": "...", "title": "...", ..., "updated_at_ms": ... }, ... ],
    "topics":     [ ... ],
    "sub_topics": [ ... ],
    "cards":      [ ... ],
    "card_sub_topics": [ ... ],
    "reviews":    [ ... ],
    "sessions":   [ ... ]
  }
}
```
Response: `{ "accepted": 42, "rejected": [{ "id": "...", "reason": "stale" }], "server_clock_ms": ... }`

## Pull
`GET /api/v1/sync/pull?since=<ms>&entities=decks,topics,...`

Response:
```json
{
  "server_clock_ms": 1713700000500,
  "records": { "decks": [...], "topics": [...], ... }
}
```

Page size cap: 500 per entity; response includes `"has_more": true` flag with a continuation `next_since` if truncated.
