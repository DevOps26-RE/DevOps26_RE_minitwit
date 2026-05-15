# ITU-MiniTwit — Final Report (Main Index)

<!-- Formal requirements checklist (verify against the full course brief before writing / exporting PDF):
  - Maximum ~2500 words for the final report; figures do not count toward the word limit.
  - Sources must be in a markup language (this repo uses Markdown) and version-controlled here.
  - Place all report images under report/images/ (e.g. report/images/demo.gif).
  - CI must build a single PDF from the report sources into report/build/, filename must match: MSc_group_[a-z].pdf (e.g. MSc_group_a.pdf).
  - Link and briefly describe constitutional artifacts: repos, issue trackers, monitoring/logging, etc. (see appendix after expansion).
-->

<!-- Edit this file (main.template.md). Run `make report` to expand @include lines into report/main.md for PDF/GitHub preview. -->

## Abstract

<!-- One short paragraph. You may draft this after the body is complete. -->

## Outline

| Perspective | Topics |
|-------------|--------|
| [System](#system-perspective) | Architecture, dependencies, static analysis and quality |
| [Process](#process-perspective) | CI/CD, monitoring, logging, security, availability and scaling |
| [Reflection](#reflection-perspective) | Issues and lessons, evolution/ops/maintenance, DevOps-style work |
| [Appendix](#appendix) | External artifact links |

<a id="system-perspective"></a>

# System's Perspective

A description and illustration of the:
- Design and architecture of your ITU-MiniTwit systems.
- All dependencies of your ITU-MiniTwit systems on all levels of abstraction and development stages. That is, list and briefly describe all technologies and tools you applied and depend on. 
- Describe the current state of your systems, for example using results of static analysis and quality assessments.

<!-- Cover: MiniTwit design and architecture (with diagrams), dependencies and tools at each abstraction level and development stage, and the current state from static analysis and quality assessments. -->




## Design and architecture

<!-- Describe and illustrate: service boundaries, data flows, deployment topology (Swarm / node roles), main components (app, DB, Traefik, observability stack, etc.). -->

### Module Viewpoint
```mermaid
flowchart TB
%% ==========================================
%% Define Folders using Subgraphs with invisible nodes
%% ==========================================

subgraph PkgMain ["Main"]
N_Main[" "]
end

subgraph CoreApplication ["Core Application"]
direction TB
User[User]
Follower[Follower]
Message[Message]
ApplicationState[Application State]

%% Internal dependencies
User --> Follower
User --> Message
end

subgraph PkgGin ["Gin"]
N_Gin[" "]
end

subgraph PkgGorm ["Gorm"]
N_Gorm[" "]
end

subgraph PkgPrometheus ["Prometheus"]
N_Prom[" "]
end

%% ==========================================
%% Dependencies 
%% ==========================================

%% Main entry point triggers User logic
PkgMain --> User

%% Frameworks depending on Core Application (Clean Architecture inward flow)
PkgGin --> CoreApplication
PkgGorm --> CoreApplication
PkgPrometheus --> CoreApplication

%% ==========================================
%% FOLDER HACK: Make inner nodes completely invisible
%% ==========================================
style N_Main fill:none,stroke:none,color:transparent
style N_Gin fill:none,stroke:none,color:transparent
style N_Gorm fill:none,stroke:none,color:transparent
style N_Prom fill:none,stroke:none,color:transparent

%% Style the subgraphs to look more like solid packages
classDef packageStyle fill:#f8f9fa,stroke:#adb5bd,stroke-width:2px,color:#212529;
class PkgMain,PkgGin,PkgGorm,PkgPrometheus,CoreApplication packageStyle;
```



### Component and Connector Viewpoint
#### Component and Connector View

This view highlights the components of the Minitwit system and the specific network protocols (connectors) they use to interact:

* **External Connectors:** The Traefik proxy component receives user traffic via HTTPS (TCP 443) and communicates with Let's Encrypt using the ACME protocol for automated TLS certificate management.
* **Application Routing:** Traefik load-balances incoming requests to the 3 Minitwit Web Service components over HTTP (TCP 5001).
* **Data Persistence:** The web application components interact with the standalone PostgreSQL database component using the native Postgres protocol (TCP 5432).
* **Observability Connectors:**
  * **Metrics (Pull):** The Prometheus component scrapes telemetry data via HTTP from the application (TCP 5001) and global Node Exporters (TCP 9100).
  * **Logs (Push):** Promtail agents stream logs to the Loki component over HTTP (TCP 3100).
  * **Visualization:** Grafana queries both Prometheus (TCP 9090) and Loki (TCP 3100) via HTTP to render dashboards.

```mermaid
flowchart LR
    Client((Client))
    LetsEncrypt(("Let's Encrypt\n(External CA)"))

    subgraph TraefikIngress ["Traefik Ingress"]
        Proxy["Traefik Reverse Proxy\n(TLS Termination & Routing)"]
    end

    subgraph AppNet ["App (app-net)"]
        App_Web["Minitwit Web Service\n(replicas: 3)"]
    end

    subgraph VPCInfra ["VPC Infrastructure (Non-Swarm)"]
        App_DB[("PostgreSQL Database\n(Standalone Compose)")]
    end

    subgraph Monitoring ["Monitoring and Logging (app-net)"]
        direction TB
        App_Grafana["Grafana"]
        App_Prometheus["Prometheus"]
        App_Loki["Loki"]

        Agent_Promtail["Promtail (Global)"]
        Agent_NodeExp["Node Exporter (Global)"]
    end

%% External Traffic & TLS
    Client -->|"HTTPS [TCP: 443]"| Proxy
    Client -.->|"HTTP [TCP: 80]\n(Redirect)"| Proxy
    Proxy <-->|"ACME Protocol\n(Auto Cert Renewal)"| LetsEncrypt

%% Traefik Routing
    Proxy ==>|"HTTP [TCP: 5001]\nLoad Balanced"| App_Web
    Proxy -->|"HTTP [TCP: 3000]\nPathPrefix(`/grafana`)"| App_Grafana

%% Database Connection (Leaving Overlay, entering VPC)
    App_Web ==>|"PostgreSQL\n[TCP: 5432]"| App_DB

%% Monitoring Data Flow (Grafana Querying)
    App_Grafana -.->|"HTTP [TCP: 9090]\nQuery Metric"| App_Prometheus
    App_Grafana -.->|"HTTP [TCP: 3100]\nQuery Log"| App_Loki

%% Monitoring Data Flow (Prometheus Scraping)
    App_Prometheus -.->|"HTTP [TCP: 5001]"| App_Web
    App_Prometheus -.->|"HTTP [TCP: 9100]"| Agent_NodeExp

%% Monitoring Data Flow (Promtail Pushing)
    Agent_Promtail -.->|"HTTP [TCP: 3100]\nPush Logs"| App_Loki

%% Styles
    classDef proxy fill:#ffe0b2,stroke:#f57c00,color:#000000,stroke-width:2px;
    classDef app fill:#c8e6c9,stroke:#388e3c,color:#000000,stroke-width:2px;
    classDef monitor fill:#e1bee7,stroke:#8e24aa,color:#000000,stroke-width:2px;
    classDef agent fill:#cfd8dc,stroke:#455a64,color:#000000,stroke-width:2px;
    classDef db fill:#bbdefb,stroke:#1976d2,color:#000000,stroke-width:2px;
    classDef ext fill:#eceff1,stroke:#607d8b,color:#000000,stroke-dasharray: 5 5;

    class Proxy proxy;
    class App_Web app;
    class App_Grafana,App_Prometheus,App_Loki monitor;
    class Agent_Promtail,Agent_NodeExp agent;
    class App_DB db;
    class LetsEncrypt ext;
```
```mermaid
flowchart TB

%% Line definitions
L1(A) ==>|"Thick Line:\n Business Data Flow"| L2(B)
L3(C) -->|"Normal Line:\n Web Traffic Routing"| L4(D)
L5(E) -.->|"Dashed Line:\n Monitoring / Logging "| L6(F)

%% Shape and Component Style definitions linked with invisible lines for vertical alignment
L_Proxy[Traefik Proxy Role]
L_Proxy ~~~ L_App[Application Web Role]
L_Monitor[Monitoring Stack Role]
L_Monitor ~~~ L_Agent[Global Agent Role]
L_DB[(Database Role)]
L_DB ~~~ L_Ext((External Entity))

%% Duplicated Style Definitions matching the main diagram
classDef proxy fill:#ffe0b2,stroke:#f57c00,color:#000000,stroke-width:2px;
classDef app fill:#c8e6c9,stroke:#388e3c,color:#000000,stroke-width:2px;
classDef monitor fill:#e1bee7,stroke:#8e24aa,color:#000000,stroke-width:2px;
classDef agent fill:#cfd8dc,stroke:#455a64,color:#000000,stroke-width:2px;
classDef db fill:#bbdefb,stroke:#1976d2,color:#000000,stroke-width:2px;
classDef ext fill:#eceff1,stroke:#607d8b,color:#000000,stroke-dasharray: 5 5;

%% Binding styles
class L_Proxy proxy;
class L_App app;
class L_Monitor monitor;
class L_Agent agent;
class L_DB db;
class L_Ext ext;
```

### Allocation Viewpoint

#### Deployment View

This is the deployment view for our 3-node Minitwit Swarm cluster:
* **Cluster Topology:** The environment consists of 3 virtual machines. All act as Swarm Managers to maintain a highly available quorum, ensuring seamless leader election if a node fails.
* **Workload Allocation:** 
  * **Node 1:** Acts as the ingress node, hosting the Traefik proxy.
  * **Node 1 & 2:** Host the distributed Minitwit application replicas.
  * **Node 3:** Dedicated to the centralized observability stack (Grafana, Prometheus, Loki).
  * **Global:** Promtail and Node Exporter agents are deployed universally across all three nodes.
* **External Infrastructure:** The PostgreSQL database is deployed on a standalone instance outside the Swarm cluster, but remains secured within the same VPC.
* **Network Infrastructure:**
  * **Control Plane:** Swarm management and node discovery (TCP 2377, 7946) operate on a dedicated infrastructure bus.
  * **Data Plane:** Inter-node container traffic is encapsulated via the Swarm Overlay network (UDP 4789), while intra-node traffic is routed directly through local network.

```mermaid
flowchart LR
Internet(("Internet\n(HTTPS Traffic)"))
PostgresDB[("PostgresDB\n(Standalone)")]


WebTraffic(["TCP 80/443\n (Web Traffic)"])
SSH(["TCP 22 (SSH Remote)"]) ~~~
MgmtBus(["TCP 2377 (Mgmt)<br/>TCP/UDP 7946 (Gossip)"])
CnDB(["TCP 5432 (Connect to DB)"])

subgraph SwarmCluster ["Swarm Cluster"]
    direction LR
    Overlay(["Swarm Overlay Network\n(Underlay: UDP 4789)"])
    subgraph Node1 ["Manager 1"]
        direction LR
        NodeInternal(["Node Internal Network"])
        T1[Traefik] ~~~ P1[Promtail] ~~~ NE1[Node Exporter]
        W1[APP] ~~~ W2[APP]
    end
        
    subgraph Node2 ["Manager 2"]
        direction TB
        P2[Promtail] ~~~ NE2[Node Exporter] ~~~ W3[APP]
    end
    
    subgraph Node3 ["DB/Monitoring"]
        direction TB
        Lok[Loki] 
        P3[Promtail]
        Graf[Grafana]
        Prom[Prometheus]
        NE3[Node Exporter]
        end
end

%% Cluster Internal Communication
Node1 <==> MgmtBus
Node2 <==> MgmtBus
Node3 <==> MgmtBus

%% External Entry Points (Routing through Firewall)
Internet ==> WebTraffic
WebTraffic ==> T1

Internet -.-> SSH
SSH -.-> SwarmCluster

%% Overlay Networking (Inter-node Traffic)
T1 ==> Overlay
T1 ==> NodeInternal
NodeInternal ==> W1
NodeInternal ==> W2
Overlay ==> W3

%% Database Access Path
W1 -.-> CnDB
W2 -.-> CnDB
W3 -.-> CnDB
CnDB -.-> PostgresDB





%% Styles
classDef ingress fill:#e1f5fe,stroke:#0288d1,color:#000000;
classDef monitor fill:#f3e5f5,stroke:#7b1fa2,color:#000000;
classDef db fill:#bbdefb,stroke:#1976d2,color:#000000,stroke-width:2px;
classDef bus fill:#fafafa,stroke:#616161,color:#424242,stroke-width:1px,stroke-dasharray: 5 5;

class Node1,Node2 ingress;
class Node3 monitor;
class PostgresDB db;
class MgmtBus,CnDB,SSH,Overlay,WebTraffic,NodeInternal bus;

```
```mermaid
%% Deployment Graph Key & Legend
flowchart TB

%% Line definitions
L1(A) ==>|"Thick Line:\n User Traffic"| L2(C)
L3(B) -.->|"Dashed Line:\n Management\n / DB Traffic"| L4(D)

%% Shape and Style definitions (Removed quotes inside brackets to fix parse error)
L_DB[(Database Storage)]
L_FW([Security / Firewall Rule])
L_Ingress[Application / Ingress Nodes]
L_Monitor[DB / Monitoring Nodes]

%% Duplicated Style Definitions
classDef ingress fill:#e1f5fe,stroke:#0288d1,color:#000000;
classDef monitor fill:#f3e5f5,stroke:#7b1fa2,color:#000000;
classDef db fill:#bbdefb,stroke:#1976d2,color:#000000,stroke-width:2px;
classDef bus fill:#fafafa,stroke:#616161,color:#424242,stroke-width:1px,stroke-dasharray: 5 5;


%% Binding styles
class L_Ingress ingress;
class L_Monitor monitor;
class L_DB db;
class L_FW bus;

```
#### One Click Deployment Flow Chart
```mermaid

sequenceDiagram
%% Define participants
    participant Terraform
    participant DigitalOcean
    participant .ini
    participant .env
    participant Ansible
    participant VirtualMachines

%% Trigger Init/Apply
    Note left of Terraform: Terraform Init Apply
    activate Terraform

%% Terraform creates infrastructure on Digital Ocean
    Terraform->>DigitalOcean: Create Virtual Machines
    Terraform->>DigitalOcean: Create Firewalls

%% Terraform writes local files
    Terraform->>.ini: Generate Ansible Inventory file
    Terraform->>.env: Generate Env File

%% Terraform triggers Ansible Playbook
    Terraform->>Ansible: Run Ansible Playbook
    deactivate Terraform

%% Ansible sets up the VMs
    activate Ansible
    Ansible->>.ini: Read Inventory file
    Ansible->>VirtualMachines: Setup Docker Swarm Cluster
    Ansible->>.env: Read Environment Variables
    Ansible->>VirtualMachines: Run Docker Compose DB And Stack Yaml
    deactivate Ansible
```

## Dependencies and technology stack

This project’s core application is written in Go (1.25) using Gin for routing, Gin sessions for auth state, GORM with the PostgreSQL driver for persistence, and Prometheus client libraries for app metrics. The UI is server-rendered from HTML templates plus static assets. Locally and in CI, Docker Compose runs the app, PostgreSQL, Selenium, and Python-based integration tests. Production deployment uses Docker Swarm with Traefik as ingress and TLS termination. Infrastructure is managed as code with Terraform (DigitalOcean VPC, droplets, firewalls) and Ansible (Docker/Swarm bootstrap and deploy). Observability is handled by Prometheus, Loki, Promtail, Grafana, and node_exporter; CI/CD runs in GitHub Actions.

## Static Analysis and Quality

<!-- e.g. make lint, golangci-lint, test coverage, integration-test strategy; optional trends or screenshots (store images under report/images/). -->

To maintain code quality and reduce security risks, the project applies a multi-layered static analysis strategy covering all languages used in the system.

**Layer 1 — Language-specific linters** are integrated into the CI/CD pipeline via GitHub Actions:

- `gofumpt` — automatically formats Go code and commits any style fixes
- `golangci-lint` — performs comprehensive Go static analysis including security checks
- `hadolint` — enforces Dockerfile best practices
- `htmlhint` — validates HTML structure
- `yamllint` — checks YAML syntax and indentation

Minor formatting issues are corrected automatically, while errors and security warnings cause the pipeline to fail with a clear message indicating the file and line number. These tools can also be run locally via `make lint`, ensuring developers receive the same feedback before pushing. Each tool is configurable — rules and thresholds can be adjusted to ignore specific warnings or tighten checks per project needs.

**Layer 2 — SonarQube Cloud** performs deeper cross-language analysis, scanning for bugs, security vulnerabilities, and code smells. It is tightly integrated with GitHub, providing real-time feedback on pull requests.

Together, these two layers act as a quality gate that all code must pass before deployment, reducing the risk of shipping defects or security issues and enforcing consistent coding standards throughout the project.

<a id="process-perspective"></a>

# Process' Perspective

This perspective should clarify how code or other artifacts come from idea into the running system and everything that happens on the way.
In particular, the following descriptions should be included:
- A complete description and illustration of stages and tools included in the CI/CD pipelines, including deployment and release of your systems.
- How do you monitor your systems and what precisely do you monitor?
- What do you log in your systems and how do you aggregate logs?
- Brief description of how you security hardened your systems.
- How do you handle availability and scaling in your systems?

<!-- Section bodies live under sections/*.md (one file per topic). @include lines are expanded when you run `make report` (report/main.template.md → report/main.md). -->

## CI/CD pipelines, deployment, and release

Our delivery process evolved incrementally from manual operations to commit-driven automation:

1. **Manual local phase (Python):** The project started as a local Python app with manual startup/testing. We used helper bash scripts for local control (legacy examples are still kept under `tmp/legacy/`).
2. **Containerized but still manual:** We then introduced Docker, but builds and runs were still triggered manually on local machines.
3. **Vagrant + DigitalOcean provisioning:** Next, we used `Vagrantfile`-based provisioning for droplets. Early provisioning relied on inline shell scripts (Docker install, DB/app startup, IP handoff via `db_ip.txt`), so deployment was cloud-based but still operator-driven.
4. **Ansible replacing shell provisioning:** We migrated host setup and deployment logic into Ansible (`ansible/site.yml`, `ansible/roles/docker_app`), making bootstrap and re-runs more repeatable.
5. **GitHub Actions CI/CD adoption:** We added commit-triggered automation in `.github/workflows/main.yml`, moving from manual build/deploy to pipeline-based quality gates, image build/push, and remote deployment.
6. **Pipeline hardening and release split:** The pipeline matured into lint → test → build/push → deploy, with branch-aware image tags and PR traceability comments; releases were separated into `release.yml` (`v*` tags).
7. **Environment separation + controlled DB updates:** We introduced stage/prod handling and a dedicated manual DB workflow (`deploy-db.yml`) because DB compose updates can cause brief downtime and require explicit operator intent.
8. **Terraform + Ansible one-click bootstrap:** Finally, infrastructure provisioning moved to Terraform (`terraform/stage`, `terraform/production`), which generates inventory/env artifacts and triggers Ansible via `local-exec` to bootstrap a full environment.

The current operating model is therefore: **Terraform + Ansible for environment creation/bootstrap**, and **GitHub Actions for ongoing application delivery per commit**. Historical files such as `Vagrantfile` and `Vagrantfile_staging` remain in the repository for process documentation but are no longer the primary deployment path.

## Monitoring

<!-- What you monitor, which tools (Prometheus, Grafana, …), key metrics and dashboard links (may reference appendix). -->

Monitoring is split across two tools — Prometheus for metrics and Loki for logs — both visualized through Grafana, with both datasources provisioned automatically on deployment (no manual setup required).

### Metrics (Prometheus)

Prometheus scrapes two targets every 15 seconds:

- **Application** — the `/metrics` endpoint exposed on port 5001.
- **Node Exporter** — running on every Swarm node, discovered via DNS service discovery (`tasks.node_exporter`).

The application instruments two custom metrics via a `PrometheusMiddleware`:

| Metric | Type | Labels | Purpose |
|---|---|---|---|
| `minitwit_http_requests_total` | Counter | `method`, `path`, `status` | Tracks total request volume; rate gives requests/sec |
| `minitwit_http_request_duration_seconds` | Histogram | `method`, `path` | Bucketed from 10ms to 10s; enables p50/p95/p99 calculations |

The route template (e.g. `/:username`) is used instead of the raw path to prevent unbounded label cardinality. Node Exporter provides host-level metrics including CPU and memory utilisation.

### Visualization (Grafana)

Two dashboards are maintained:

**Metrics dashboard** (Prometheus datasource):

- **CPU utilisation** — shows host CPU usage over time per node; helps detect runaway processes or traffic spikes. A color indicator reflects current consumption: green (healthy), yellow (moderate), red (critical).
- **Memory utilisation** — tracks RAM usage per node; useful for catching memory leaks. Same green/yellow/red color coding indicates current memory pressure at a glance.
- **HTTP request rate** — derived from `minitwit_http_requests_total`; shows how many requests/sec the app is handling.
- **Average & p95 response time** — derived from the duration histogram; p95 highlights tail latency that averages would hide.
- **Successful requests** — counts 2xx responses; a sudden drop signals an outage or regression.
- **Traffic by endpoint** — breaks request rate down by route template; reveals which endpoints are under the most load.

**Log dashboard** (Loki datasource):

- **Overall traffic** — log volume over time across all services; a quick sanity-check for whether the app is receiving requests.
- **Database errors** — filters for error-level log lines from the `db` service; these panels may not function correctly due to incomplete error handling in the application code.
- **Service errors** — filters for error-level log lines from the web service; same caveat applies.

Grafana's Explore view allows correlating a spike in a Prometheus graph with the corresponding Loki log lines from the same time window, enabling faster incident investigation.

## Logging

<!-- What you log and how logs are aggregated (Loki, Promtail, …). -->

The application emits one structured JSON log line per HTTP request to stdout, produced by a `LoggingMiddleware` built on Go's `slog` package. Writing to stdout requires no direct coupling to the log storage backend — Docker captures container stdout automatically.

Each log entry contains the following fields:

| Field | Example | Description |
|---|---|---|
| `method` | `GET` | HTTP verb |
| `path` | `/alice` | Raw request path |
| `route` | `/:username` | Gin route template — avoids high-cardinality labels |
| `status` | `200` | HTTP response status code |
| `latency_ms` | `12` | Request duration in milliseconds |
| `client_ip` | `1.2.3.4` | Originating IP (respects X-Forwarded-For) |
| `user_agent` | `Mozilla/5.0 …` | Browser or client identifier |
| `bytes_out` | `1024` | Response body size in bytes |

### Log Aggregation

**Promtail** runs as a `global` service in the Docker Swarm (one instance per node). It connects to the Docker daemon via the Unix socket (`/var/run/docker.sock`) and automatically discovers all running containers, tailing their stdout and stderr — no hardcoded service names required.

Each log line is forwarded to **Loki** with three labels:

- **`service`** — Docker Compose service name (e.g. `web`). Used to scope queries to a single service, e.g. `{service="web"}`.
- **`container`** — Full container name (e.g. `minitwit-web-1`). Useful when multiple replicas run side by side and you need to isolate one instance.
- **`stream`** — Either `stdout` or `stderr`. Allows filtering out noisy stderr from libraries while keeping application logs clean.

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

## Security hardening

<!-- Brief notes: authentication, TLS, network isolation, Basic Auth, secrets handling, etc. -->

## Availability and scaling

Our Minitwit service runs on a 3-node Docker Swarm in DigitalOcean. Two manager nodes run 3 replicas of the Minitwit app, while the third node runs the database and monitoring stack. Node roles are defined via Terraform resource groups, which Ansible uses to apply Docker Swarm placement labels during provisioning. Services in `docker-stack.yml` are constrained to nodes with matching labels, and Swarm automatically reschedules replicas if a node goes down.

The database can only be scaled vertically (larger VM). The application supports horizontal scaling by adding droplets to the Terraform configuration and assigning them the ingress role.

When deploying a new version, Swarm performs a rolling update: each new replica starts before the old one stops (`order: start-first`), keeping at least two instances available throughout. If the new container fails to start, Swarm automatically rolls back (`failure_action: rollback`). Silent failures — where the container starts but behaves incorrectly — are not caught automatically; the CI/CD test suite is the primary guard here.

**Known limits:** The database is a single point of failure with no replication or automated backups. Traefik runs as a single replica, so if its host node fails, ingress is lost until Swarm reschedules it. The app containers have no health checks beyond TCP port availability, so a broken-but-running instance will continue receiving traffic.

<a id="reflection-perspective"></a>

# Reflection Perspective
## Major issues, resolutions, and lessons learned
Initially each member ported part of the Python-to-Go rewrite alone, which left some disconnected; we fixed this by moving our most knowledgeable member to a pure peer-review role and holding weekly syncs.

### Maintenance
Our biggest failure was the Compose-to-Swarm migration: the deploy automation had only ever worked against Compose, so the cutover broke live and took four successive fixes to stabilise [#36–#39]. The deeper cause was treating the migration itself as the first real test of the new automation. Lesson: major infrastructure changes need a deployment path proven on staging first, and shared edge components like Traefik must be decoupled so they survive migrations.

### DevOps-style work compared to earlier projects
Unlike earlier projects, a CI/CD pipeline ran analysis, staging deployment, and tests on every PR <!-- We might want to link to the actual PR in which this was implemented? -->, making integration continuous rather than last-minute.
Generative AI. Used for boilerplate route porting, documentation, and as a searchable interface to our own codebase; results were useful but occasionally over-complex.

### Use of Generative AI
We used generative AI for several tasks, with mixed results:

- __Documentation:__ Generating documentation for new implementations, which we used in Thursday meetings to recap the week's work.
- __As a documentation search engine:__ Querying specific, hard-to-understand parts of technologies instead of reading official docs. This sometimes worked well but sometimes produced unnecessarily complex suggestions.
- __Boilerplate porting:__ Translating the routing layer from Python to Go.
- __Understanding our own codebase:__ Feeding the full codebase to AI to "interview" it about behaviour we found unclear — most usefully, the interactions between DigitalOcean's network, Docker's network, and each VM's network.

<!-- around 286 words total -->

<a id="appendix"></a>

# Appendix — Linked artifacts
Just a placeholder for now
<!-- List each constitutional artifact with a one-line description and URL. Replace placeholders with your real links. -->

## Source code and version control

<!-- - Main repository: ... -->

## Issue tracking

<!-- - GitHub Issues / Projects: ... -->

## Monitoring, logging, and dashboards

<!-- - Grafana: ... -->
<!-- - If not public, describe how reviewers can access it. -->

## Other

<!-- - Simulator API docs, course wiki, additional documentation repos, etc. -->

## Figures and illustrations

<!-- Use relative paths from report/main.md after expansion, e.g. ![Demo](images/demo.gif) -->
