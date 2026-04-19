# SQLite Backups with Litestream

Litestream continuously replicates the production SQLite database to Hetzner Object Storage (S3-compatible). It runs as a Kamal accessory alongside the app container, sharing the same Docker volume.

## Architecture

- **Replication**: A `litestream/litestream` Docker container runs as a Kamal accessory, watching the WAL of `production.sqlite3` and streaming changes to S3.
- **Restore**: The `litestream` binary is also installed in the app image. On boot, `bin/docker-entrypoint` auto-restores from S3 if the database file is missing.
- **Scope**: Only `production.sqlite3` is backed up. Cache, queue, and cable databases are ephemeral (recreated by the Solid suite).
- **UID alignment**: The accessory runs as `user: 1000:1000` (set via `options:` in `config/deploy.yml`) to match the Rails app user. Without this, Litestream cannot read WAL files or create its metadata directory on the shared `hauptgang_storage` volume.

## Key files

| File | Role |
|---|---|
| `config/litestream.yml` | Replication config (DB path, S3 bucket, retention) |
| `config/deploy.yml` | Kamal accessory definition + `restore` alias |
| `.kamal/secrets` | Extracts Hetzner S3 credentials from Rails credentials |
| `bin/docker-entrypoint` | Auto-restore logic on missing DB |
| `Dockerfile` | Installs `litestream` binary in the app image |

## Credentials

Reuses the existing Hetzner Object Storage credentials (`hetzner.access_key_id`, `hetzner.secret_access_key`) from Rails credentials. Backup bucket: `hauptgang-backups` in `fsn1`.

## Common operations

```bash
# Check replication status
kamal accessory logs litestream

# Reboot the Litestream accessory
kamal accessory reboot litestream

# Manual restore (overwrites current DB — stop the app first)
kamal restore

# Test restore to a temporary file (non-destructive)
kamal app exec "litestream restore -config /rails/config/litestream.yml -o /tmp/test.sqlite3 storage/production.sqlite3"
kamal app exec "sqlite3 /tmp/test.sqlite3 'SELECT count(*) FROM recipes;'"
```

## Disaster recovery (fresh server)

On a new server, `kamal deploy` + `kamal accessory boot litestream` is all that's needed. The entrypoint detects the missing database and restores from S3 automatically before running `db:prepare`.

## Retention

Configured in `config/litestream.yml`: 72h WAL retention, 24h snapshot interval. Point-in-time recovery is possible within the retention window via `litestream restore -timestamp`.
