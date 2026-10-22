# Location cache state

`state.json` is the list of provinces, communes and GHN codes that the location migrations have written
to the `location_*` tables, as of the last sync. It is created by the first run of the workflow
**Location sync** (`.github/workflows/location-sync.yml`) and is rewritten by every run that changes
something. Do not edit it or the generated `*_location_sync_*.sql` migrations by hand.

How it works: the workflow downloads the Location Service snapshot, compares it with this file, writes one
data migration for the difference, tests it on an empty database and opens a pull request. Merging the pull
request runs the migration through "Supabase migrate". Units that stop being in force become `retired`; they
are never deleted. Run it again with the manual input `dry_run` to see the report only.

The same script runs locally: `node apps/web/scripts/location-sync/run.mjs --from-file snapshot.ndjson --dry-run`.
Plan: docs/ke-hoach-noi-dia-gioi.md, section 5.
