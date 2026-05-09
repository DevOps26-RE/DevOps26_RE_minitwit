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
### Minitwit Deployment Infrastructure (VPC Private Network)

```mermaid
flowchart LR
Internet(("Internet\n(HTTPS Traffic)"))
PostgresDB[("PostgresDB\n(Standalone)")]

Overlay(["UDP 4789 (VXLAN Overlay)"])
WebTraffic(["TCP 80/443 (Web Traffic)"])
SSH(["TCP 22 (SSH Remote)"]) ~~~
MgmtBus(["TCP 2377 (Mgmt)<br/>TCP/UDP 7946 (Gossip)"])
CnDB(["TCP 5432 (Connect to DB)"])

subgraph SwarmCluster ["Swarm Cluster (VPC)"]
    direction LR
    
    subgraph Node1 ["Manager 1"]
        direction LR
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
Overlay ==> W1
Overlay ==> W2
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
class MgmtBus,CnDB,SSH,Overlay,WebTraffic bus;

```

#### Graph Key & Legend

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

<!-- List and briefly describe: languages, frameworks, DB, orchestration, IaC, CI platform, observability components, etc. -->

## Static analysis and quality

<!-- e.g. make lint, golangci-lint, test coverage, integration-test strategy; optional trends or screenshots (store images under report/images/). -->

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

<!-- Describe and illustrate stages (lint, test, build, deploy); staging vs production, tag-based releases, manual DB workflows, etc. -->

## Monitoring

<!-- What you monitor, which tools (Prometheus, Grafana, …), key metrics and dashboard links (may reference appendix). -->

## Logging

<!-- What you log and how logs are aggregated (Loki, Promtail, …). -->

## Security hardening

<!-- Brief notes: authentication, TLS, network isolation, Basic Auth, secrets handling, etc. -->

## Availability and scaling

Our Minitwit service runs on a 3-node Docker Swarm in DigitalOcean. Two manager nodes run 3 replicas of the Minitwit app, while the third node runs the database and monitoring stack. Node roles are defined via Terraform resource groups, which Ansible uses to apply Docker Swarm placement labels during provisioning. Services in `docker-stack.yml` are constrained to nodes with matching labels, and Swarm automatically reschedules replicas if a node goes down.

The database can only be scaled vertically (larger VM). The application supports horizontal scaling by adding droplets to the Terraform configuration and assigning them the ingress role.

When deploying a new version, Swarm performs a rolling update: each new replica starts before the old one stops (`order: start-first`), keeping at least two instances available throughout. If the new container fails to start, Swarm automatically rolls back (`failure_action: rollback`). Silent failures — where the container starts but behaves incorrectly — are not caught automatically; the CI/CD test suite is the primary guard here.

**Known limits:** The database is a single point of failure with no replication or automated backups. Traefik runs as a single replica, so if its host node fails, ingress is lost until Swarm reschedules it. The app containers have no health checks beyond TCP port availability, so a broken-but-running instance will continue receiving traffic.

<a id="reflection-perspective"></a>

# Reflection Perspective

Describe the biggest issues, how you solved them, and which are major lessons learned with regards to:
- evolution and refactoring
- operation, and
- maintenance
of your ITU-MiniTwit systems. Link back to respective commit messages, issues, tickets, etc. to illustrate these.

Also reflect and describe what was the "DevOps" style of your work. For example, what did you do differently to previous development projects and how did it work?

Use of Generative AI

ITU's rules on the use of generative AI apply for this report too. They are described here and in detail here. Please follow them. For your report that means that you have to state which generative AI tools have been used for which task(s) in your projects. Additionally, describe how generative AI tools have been used and briefly reflect and discuss how they supported or hindered your work process.


<!-- Cover: major issues and how you solved them; lessons on evolution/refactoring, operation, and maintenance. Link to commits, issues, tickets. Reflect on your DevOps-style work vs previous projects. -->

## Major issues, resolutions, and lessons learned

### Evolution and refactoring

<!-- Link: relevant commits / PRs / issues. -->

### Operation

<!-- Link: on-call, incidents, alerts (if any). -->

### Maintenance

<!-- Link: technical debt, documentation, dependency upgrades, etc. -->

## DevOps-style work compared to earlier projects

<!-- e.g. automation, small batches, IaC, observability-first practices. -->

## Use of Generative AI

<!-- e.g. how we use ai. -->
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
