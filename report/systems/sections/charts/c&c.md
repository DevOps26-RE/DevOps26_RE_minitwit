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