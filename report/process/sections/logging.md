## Logging

<!-- What you log and how logs are aggregated (Loki, Promtail, …). -->

The application emits one structured JSON log line per HTTP request to stdout, produced by a `LoggingMiddleware` built on Go's `slog` package. Writing to stdout requires no direct coupling to the log storage backend, Docker captures container stdout automatically.

Each log entry contains the following fields:

| Field | Example | Description |
|---|---|---|
| `method` | `GET` | HTTP verb |
| `path` | `/alice` | Raw request path |
| `route` | `/:username` | Gin route template, avoids high-cardinality labels |
| `status` | `200` | HTTP response status code |
| `latency_ms` | `12` | Request duration in milliseconds |
| `client_ip` | `1.2.3.4` | Originating IP (respects X-Forwarded-For) |
| `user_agent` | `Mozilla/5.0 …` | Browser or client identifier |
| `bytes_out` | `1024` | Response body size in bytes |

### Log Aggregation

**Promtail** runs as a `global` service in the Docker Swarm (one instance per node). It connects to the Docker daemon via the Unix socket (`/var/run/docker.sock`) and automatically discovers all running containers, tailing their stdout and stderr, no hardcoded service names required.

Each log line is forwarded to **Loki** with three labels:

- **`service`**: Docker Compose service name (e.g. `web`). Used to scope queries to a single service, e.g. `{service="web"}`.
- **`container`**: Full container name (e.g. `minitwit-web-1`). Useful when multiple replicas run side by side and you need to isolate one instance.
- **`stream`**: Either `stdout` or `stderr`. Allows filtering out noisy stderr from libraries while keeping application logs clean.

These low-cardinality labels keep Loki queries efficient.

### Storage & Querying

Loki uses a single-node filesystem-backed setup with **7-day retention**. Logs are queryable via LogQL. The following queries are used in the Grafana dashboards:

```logql
# All logs from the web service
{service="minitwit_web"}

# All logs from any web container replica (regex match)
{container=~"minitwit_web.*"}

# Server errors (status >= 500)
{service="web"} | json | status >= 500

# Slow requests (latency > 1 second)
{service="web"} | json | latency_ms > 1000

# Error-level log lines
{service="minitwit_web"} | json | level =~ `(?i)error`
{service="db"} | json | level =~ `(?i)error`

# Timeout events
{service="minitwit_web"} |= "timeout"
{service="db"} |= "timeout"
```
