# SQLite Browser

Interactive SQLite database browser built with Munin.

## Run

```bash
odin run examples/sqlite_browser
```

Without arguments it opens a sample in-memory database. Pass a database path to browse a real file:

```bash
odin run examples/sqlite_browser -- path/to/database.sqlite
```

## Controls

- `Tab` cycles focus between tables, query, and results.
- `Up` / `Down` selects tables.
- `Enter` runs the current SQL query.
- `Left` / `Right` or `PageUp` / `PageDown` changes result pages.
- `q` quits.
