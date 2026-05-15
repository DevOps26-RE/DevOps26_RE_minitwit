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