## Logging

<!-- What you log and how logs are aggregated (Loki, Promtail, …). -->
The application emits one structured JSON log line per HTTP request to stdout, produced by a LoggingMiddleware built on Go's slog package. Each entry contains the following fields: method, path, route (Gin's route template, e.g. /:username rather than the raw path /alice, to avoid high-cardinality labels), status, latency_ms, client_ip, user_agent, and bytes_out. Writing to stdout requires no direct coupling to the log storage backend — Docker captures container stdout automatically.
Log aggregation is handled by Promtail, which runs as a global service in the Docker Swarm (one instance per node). It connects to the Docker daemon via the Unix socket and automatically discovers all running containers, tailing their stdout and stderr without any hardcoded service names. Each log line is forwarded to Loki with three labels: service (the Docker Compose service name, e.g. web), container (the full container name), and stream (stdout or stderr). These low-cardinality labels keep Loki queries efficient.
Loki stores logs using a single-node filesystem-backed setup with 7-day retention. Logs are queryable via LogQL — for example {service="web"} | json | status >= 500 to filter server errors, or {service="web"} | json | latency_ms > 1000 to surface slow requests.

