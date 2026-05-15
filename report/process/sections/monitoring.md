## Monitoring

<!-- What you monitor, which tools (Prometheus, Grafana, …), key metrics and dashboard links (may reference appendix). -->

Monitoring is split across two tools: Prometheus for metrics and Loki for logs. Both visualized through Grafana, with both datasources provisioned automatically on deployment.

### Metrics (Prometheus)

Prometheus scrapes two targets every 15 seconds:

- **Application**: the `/metrics` endpoint exposed on port 5001.
- **Node Exporter**: running on every Swarm node, discovered via DNS service discovery (`tasks.node_exporter`).

The application instruments two custom metrics via a `PrometheusMiddleware`:

| Metric | Type | Labels | Purpose |
|---|---|---|---|
| `minitwit_http_requests_total` | Counter | `method`, `path`, `status` | Tracks total request volume; rate gives requests/sec |
| `minitwit_http_request_duration_seconds` | Histogram | `method`, `path` | Bucketed from 10ms to 10s; enables p50/p95/p99 calculations |

The route template (e.g. `/:username`) is used instead of the raw path to prevent unbounded label cardinality. Node Exporter provides host-level metrics including CPU and memory utilisation.

### Visualization (Grafana)

Two dashboards are maintained:

**Metrics dashboard** (Prometheus datasource):

- **CPU utilisation**: shows host CPU usage over time per node; helps detect runaway processes or traffic spikes. A color indicator reflects current consumption: green (healthy), yellow (moderate), red (critical).
- **Memory utilisation**: tracks RAM usage per node; useful for catching memory leaks through the timeline. Same green/yellow/red color coding indicates current memory usage at a glance.
- **HTTP request rate**: derived from `minitwit_http_requests_total`; shows how many requests/sec the app is handling.
- **Average & p95 response time**: derived from the duration histogram; p95 highlights tail latency that averages would hide.
- **Successful requests**: counts https status code successful code (2xx) responses; a sudden drop signals an outage or regression.
- **Traffic by endpoint**: breaks request rate down by route template; reveals which endpoints are under the most load.

**Log dashboard** (Loki datasource):

- **Minitwit log**: log volume over time across all web app replicas; a quick check for whether the app is receiving requests.
- **DB error log**: filters for error-level log lines from the `db` service.

Grafana's Explore view allows correlating a spike in a Prometheus graph with the corresponding Loki log lines from the same time window, enabling faster incident investigation.
