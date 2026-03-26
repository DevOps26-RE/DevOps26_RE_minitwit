# Logging with Grafana Loki

This document explains how logging works in MiniTwit — what collects logs,
where they go, and how to query them in Grafana.

---

## Architecture

```
Go app  ──stdout──▶  Docker  ──socket──▶  Promtail  ──HTTP──▶  Loki  ◀──query──  Grafana
```

Each component has a single responsibility:

| Component | Role | Config |
|-----------|------|--------|
| **Go app** | Emits structured JSON log lines to stdout | `logger.go` |
| **Docker** | Captures container stdout/stderr automatically | (built-in) |
| **Promtail** | Reads Docker logs and ships them to Loki | `promtail/promtail-config.yaml` |
| **Loki** | Stores and indexes logs, answers LogQL queries | `loki/loki-config.yaml` |
| **Grafana** | Visualises logs via the Explore tab | `grafana/datasources.yaml` |

**Key design principle:** The Go app has **zero knowledge of Loki**. It only writes
to stdout. This means the logging infrastructure can be swapped out, scaled, or
disabled without touching application code.

---

## What each log line looks like

Every HTTP request produces one JSON log line. Example (pretty-printed):

```json
{
  "time": "2025-03-26T12:34:56Z",
  "level": "INFO",
  "msg": "request",
  "method": "GET",
  "path": "/alice",
  "route": "/:username",
  "status": 200,
  "latency_ms": 12,
  "client_ip": "1.2.3.4",
  "user_agent": "Mozilla/5.0 ...",
  "bytes_out": 4321
}
```

`route` is the Gin route template (e.g. `/:username`) rather than the
actual path (e.g. `/alice`). This matches the convention in `monitor.go`
for Prometheus labels and prevents unbounded label cardinality.

---

## Querying logs in Grafana

Navigate to **Grafana → Explore → select "Loki" datasource**.

### Useful LogQL queries

```logql
# All logs from the web service
{service="web"}

# Only error responses (status >= 500)
{service="web"} | json | status >= 500

# Slow requests (over 1 second)
{service="web"} | json | latency_ms > 1000

# Logs from a specific route
{service="web"} | json | route="/:username"

# All stderr output across all services (useful for crash debugging)
{stream="stderr"}

# Logs from a specific container
{container="minitwit-web-1"}

# Error rate over time (use as a metric in a dashboard panel)
sum(rate({service="web"} | json | status >= 500 [5m]))
```

### LogQL cheat sheet

| Syntax | What it does |
|--------|-------------|
| `{service="web"}` | Filter by label |
| `\| json` | Parse the JSON payload so fields become filterable |
| `\| status >= 500` | Filter on a parsed field (requires `\| json` first) |
| `\| line_format "{{.method}} {{.path}}"` | Reshape log output |
| `rate(...[5m])` | Compute per-second rate over 5-minute window |

---

## How Promtail auto-discovers containers

Promtail connects to the Docker daemon socket (`/var/run/docker.sock`).
It automatically finds every running container and starts tailing its logs.

Docker Compose applies a label `com.docker.compose.service` to every
container it starts (e.g. `web`, `prometheus`, `grafana`). Promtail
maps this to a `service` label in Loki, so `{service="web"}` works
without any manual configuration.

**Adding a new service** to `docker-compose-app.yaml` automatically makes
its logs available in Loki — no changes to Promtail config needed.

---

## How Grafana datasources are provisioned

Grafana reads `/etc/grafana/provisioning/datasources/` on startup.
The file `grafana/datasources.yaml` is bind-mounted to that path
in `docker-compose-app.yaml`.

This means:
- After any fresh deployment, both Prometheus and Loki are immediately
  available as datasources — no manual setup needed.
- Datasources show a lock icon in the Grafana UI, indicating they are
  managed by config (not deletable through the UI).
- Prometheus remains the default datasource so existing dashboards work
  without changes.

---

## Loki storage and retention

Logs are stored on the host in a Docker volume (`loki_data`).
Retention is set to **7 days** (`reject_old_samples_max_age: 168h`).
Log lines older than 7 days are rejected on ingestion.

The storage uses TSDB schema v13, which is the current standard for
Loki 3.x. Single-node filesystem storage is appropriate for this
deployment since there is only one server.

---

## Troubleshooting

**No logs appearing in Loki?**
1. Check Promtail is running: `docker compose logs promtail`
2. Check Loki is healthy: `docker compose logs loki`
3. Verify Promtail can reach Loki: look for `level=info msg="Successfully sent batch"` in Promtail logs

**Grafana shows "Loki datasource not found"?**
- The `grafana/datasources.yaml` file must exist on the server at
  `/opt/minitwit/grafana/datasources.yaml`. The CI/CD pipeline ships it
  automatically, but if deploying manually make sure to copy the `grafana/`
  directory alongside `docker-compose-app.yaml`.

**Log lines are duplicated?**
- This would mean `gin.Default()` was restored instead of `gin.New()`.
  `gin.Default()` bundles its own unstructured text logger. Check `minitwit.go`.
