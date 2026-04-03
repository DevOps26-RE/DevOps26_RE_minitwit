# Docker Swarm Migration Guide

This document explains every change made to migrate MiniTwit from a 2-node docker-compose setup to a 3-node Docker Swarm cluster. It covers the problem being solved, the architectural decisions, every changed file, and the step-by-step runbook for executing the migration.

---

## Table of Contents

1. [Why We Are Doing This](#1-why-we-are-doing-this)
2. [Architecture: Before and After](#2-architecture-before-and-after)
3. [How Zero-Downtime Works](#3-how-zero-downtime-works)
4. [Every Changed File Explained](#4-every-changed-file-explained)
5. [Prerequisites Before Running the Migration](#5-prerequisites-before-running-the-migration)
6. [Migration Runbook](#6-migration-runbook)
7. [GitHub Actions Changes](#7-github-actions-changes)
8. [Verification Steps](#8-verification-steps)
9. [Rollback Procedures](#9-rollback-procedures)
10. [Common Problems and Fixes](#10-common-problems-and-fixes)

---

## 1. Why We Are Doing This

### The Problem: Single Point of Failure

The previous setup:
- **Node 1 (webserver):** Runs Traefik + the web application + all monitoring (Prometheus, Loki, Promtail, Grafana) via `docker-compose`
- **Node 2 (dbserver):** Runs PostgreSQL via `docker-compose`

If Node 1 crashes, or if you need to restart Docker on Node 1, the entire application goes offline. The simulator keeps sending requests; they all fail. This is a **Single Point of Failure (SPOF)**.

### The Solution: Docker Swarm

By adding a third node and forming a Docker Swarm cluster, we get:

- **Container replication:** The web application runs as 2 replicas spread across nodes. If one container crashes, Swarm immediately starts a replacement on another node.
- **Manager redundancy (Raft consensus):** With 3 managers, the cluster can lose any 1 node and continue operating. The Raft algorithm requires `(N/2)+1` votes to elect a leader — with 3 managers, 2 is enough.
- **Rolling updates with zero downtime:** Swarm's `start-first` update policy starts the new container version, waits for it to be healthy, and only then terminates the old version. No request is ever dropped during a deployment.

---

## 2. Architecture: Before and After

### Before (2-Node docker-compose)

```
Internet / Simulator
        │
        ▼ :5001
┌───────────────────┐         ┌───────────────────┐
│    Node 1         │         │    Node 2         │
│    (webserver)    │ ──────▶ │    (dbserver)     │
│                   │  :5432  │                   │
│  docker-compose:  │         │  docker-compose:  │
│  - traefik        │         │  - postgres        │
│  - web            │         │                   │
│  - prometheus     │         │                   │
│  - loki           │         │                   │
│  - promtail       │         └───────────────────┘
│  - grafana        │
└───────────────────┘
         SPOF: if this dies, everything is down
```

### After (3-Node Docker Swarm)

```
Internet / Simulator
        │
        ▼ :5001 (any node — Swarm routing mesh)
┌────────────────────────────────────────────────────────────┐
│                    Docker Swarm Cluster                    │
│                                                            │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│  │  Node 1      │   │  Node 2      │   │  Node 3      │  │
│  │  webserver   │   │  dbserver    │   │  swarmnode   │  │
│  │  (Manager)   │   │  (Manager)   │   │  (Manager)   │  │
│  │              │   │              │   │              │  │
│  │  Swarm:      │   │  Compose:    │   │  Swarm:      │  │
│  │  - web       │   │  - postgres  │   │  - traefik   │  │
│  │  - prometheus│   │              │   │  - web       │  │
│  │  - loki      │   │  (unchanged) │   │              │  │
│  │  - promtail  │   │              │   │              │  │
│  │  - grafana   │   │              │   │              │  │
│  └──────────────┘   └──────────────┘   └──────────────┘  │
│                          VPC Private Network               │
└────────────────────────────────────────────────────────────┘
  Can lose ANY 1 node without cluster failure or dropped requests
```

**Key design decisions:**
- PostgreSQL stays on Node 2 running via docker-compose. Swarm can reschedule containers to different nodes on failure, which would lose the DB volume unless shared storage (NFS, Ceph, etc.) is set up. docker-compose on a fixed node is simpler and sufficient.
- Monitoring services (Prometheus, Loki, Promtail, Grafana) are pinned to Node 1 via placement constraints. Named Docker volumes are node-local; pinning all monitoring to one node keeps all data together.
- Node 3 (swarmnode) is the initial Traefik ingress during migration, and becomes part of the routing mesh in Phase 4.

---

## 3. How Zero-Downtime Works

### During the Migration (Phase 3): iptables Traffic Hijacking

The simulator is pointed at Node 1's public IP and we cannot change that IP. The migration cutover works like this:

```
Before Phase 3:
  Simulator → Node 1:5001 → old docker-compose Traefik → old web containers

During Phase 3:
  Simulator → Node 1:5001
               │
               └──iptables PREROUTING DNAT──▶ Node 3 private IP:5001
                                                      │
                                                      ▼
                                               Swarm Traefik → new web containers
```

The Linux kernel intercepts the incoming packets at the `PREROUTING` hook (before any local process sees them) and rewrites the destination IP to Node 3's private VPC IP. To the simulator, nothing changes — it still sends to Node 1's public IP and gets valid responses. But the actual traffic is being served by the new Swarm setup on Node 3.

Once the iptables rule is in place and we confirm Node 3 is healthy, we shut down the old docker-compose stack on Node 1 and join it to the Swarm. At no point is there a gap where traffic is dropped.

### During Daily Deployments (GitHub Actions): Rolling Updates

When you push to `main`, GitHub Actions runs:

```bash
docker service update \
  --image runtimeerroritu/minitwit:<new-sha> \
  --update-order start-first \
  --update-failure-action rollback \
  minitwit_stack_web
```

Swarm's `start-first` update order:
```
State during rolling update:
  container_v1 (serving traffic)
  container_v2 (starting up)   ← starts FIRST
       │
       ▼ (v2 passes health check)
  container_v1 (still serving) ← traffic moves to v2
  container_v2 (now serving)
       │
       ▼
  container_v1 (stopped)       ← only now removed
  container_v2 (serving all traffic)
```

If `container_v2` fails its health check, Swarm automatically rolls back to `container_v1` — `--update-failure-action rollback` ensures this.

---

## 4. Every Changed File Explained

### `Vagrantfile`

**What changed:** Added a third VM definition (`swarmnode`) and added `ansible.inventory_path = "ansible/inventory"` to the Ansible provisioner.

**Why:**
- `swarmnode` is Node 3. It needs to exist before the Swarm can be formed.
- `ansible.inventory_path` switches Ansible from Vagrant's auto-generated dynamic inventory to our new static inventory. Without this, Ansible cannot use host groups like `[swarm_managers]` or read per-host variables.
- `s-1vcpu-2gb` vs `s-1vcpu-1gb`: Node 3 runs Traefik + Swarm manager heartbeat simultaneously. 2GB prevents OOM kills during the Phase 2/3 window.

```ruby
# NEW: swarmnode droplet
config.vm.define "swarmnode" do |swarm|
  swarm.vm.provider :digital_ocean do |provider|
    provider.size = 's-1vcpu-2gb'
    provider.privatenetworking = true
    # ...
  end
end

# CHANGED: add inventory_path
ansible.inventory_path = "ansible/inventory"
```

---

### `ansible/inventory/hosts.ini`

**What is this:** A static Ansible inventory file replacing the dynamic Vagrant-generated inventory.

**Why a static inventory:**
Vagrant generates an inventory mapping VM names to IPs automatically. This works for `hosts: all` playbooks, but breaks when you need:
- Host group targeting (`hosts: swarm_managers`)
- Per-host variables (`private_ip` for each node)
- Group variables (`swarm_stack_name` shared by all hosts)

The static inventory also survives `vagrant destroy` cycles without losing group structure.

**Groups defined:**
| Group | Hosts | Purpose |
|---|---|---|
| `[swarm_managers]` | swarmnode | Primary Swarm manager, initial Traefik host |
| `[db_server]` | dbserver | PostgreSQL, secondary Swarm manager |
| `[app_nodes]` | swarmnode, webserver | Nodes that run web replicas |

**Important:** Fill in the actual `<NODE*_PUBLIC_IP>` and `<NODE*_PRIVATE_IP>` placeholders after running `vagrant up`.

---

### `ansible/inventory/host_vars/swarmnode.yml`

```yaml
private_ip: <NODE3_PRIVATE_IP>
node_role_label: ingress
```

- `private_ip`: Used as Docker Swarm's `--advertise-addr`. All inter-node Swarm traffic (Raft consensus on port 2377, gossip on 7946, overlay VXLAN on 4789) uses this IP. It is also the DNAT target in Node 1's iptables rule.
- `node_role_label: ingress`: The value of the Docker node label `role=ingress`. In `docker-stack.yml`, Traefik's placement constraint is `node.labels.role == ingress`, so it runs only on swarmnode during Phase 2 and 3.

---

### `ansible/inventory/host_vars/webserver.yml`

```yaml
private_ip: <NODE1_PRIVATE_IP>
node_role_label: monitoring
```

- `node_role_label: monitoring`: All monitoring services (Prometheus, Loki, Promtail, Grafana) are pinned to this node. Named volumes are node-local in Swarm, so pinning all monitoring to one node prevents data loss if a service is rescheduled.

**Why does webserver join the swarm last?**
Node 1 is handling live production traffic when the migration starts. It cannot join the swarm until the iptables forwarding is active (so traffic keeps flowing) and the old Compose stack is stopped (so port 5001 is free for Swarm to bind).

---

### `ansible/inventory/host_vars/dbserver.yml`

```yaml
private_ip: <NODE2_PRIVATE_IP>
node_role_label: database
```

- `private_ip`: Used in the stack `.env` file: `DB_ADDR=postgres://minitwit:minitwit@<NODE2_PRIVATE_IP>:5432/minitwit`. Database traffic stays on the VPC private network — no public egress costs, more secure.

**Why does dbserver join as a manager (not worker)?**
Raft consensus requires `(N/2)+1` votes. With only swarmnode as manager, losing it means the cluster has no quorum — no deployments, no scheduling. Joining dbserver as a second manager gives partial HA during the cutover. True full HA (can lose any 1 node) is achieved after webserver joins in Phase 3 as the third manager.

---

### `ansible/inventory/group_vars/all.yml`

Shared variables across all hosts:
- `swarm_stack_name: minitwit_stack` — Docker prefixes all service names with this. The GitHub Actions deploy step uses `minitwit_stack_web` and `minitwit_stack_prometheus`.
- `app_deploy_dir` / `db_deploy_dir` — Filesystem paths used by multiple roles.

---

### `ansible/requirements.yml`

```yaml
collections:
  - name: community.docker   # docker_swarm, docker_stack, docker_node, etc.
  - name: ansible.posix      # sysctl module for IP forwarding
```

Run before the playbook: `ansible-galaxy collection install -r ansible/requirements.yml`

---

### `ansible/site.yml`

**What changed:** Completely rewritten from a single `hosts: all` play to 8 targeted plays.

**Play order and dependencies:**

| Play | Hosts | Purpose | Dependency |
|---|---|---|---|
| 1 | all | docker_install | Must run first |
| 2 | swarm_managers | swarm_init | After Docker installed |
| 3 | db_server | join dbserver to swarm | After swarm_init sets tokens |
| 4 | swarm_managers | swarm_labels | After dbserver joined |
| 5 | db_server | db_setup | Before web stack starts |
| 6 | swarm_managers | swarm_stack_deploy | After labels + DB ready |
| 7 | webserver | [phase3] iptables_forward | Manual trigger |
| 8 | webserver | [phase4] iptables_cleanup | Manual trigger |

The `never` tag on plays 7 and 8 means they are **never run by default**. You must explicitly request them with `--tags phase3` or `--tags phase4`. This prevents accidentally triggering the live-traffic cutover during a routine re-provisioning run.

---

### `ansible/roles/docker_install/tasks/main.yml`

**What is this:** Extracted from the original `docker_app` role (all the Docker installation logic that applies to every node).

**What it does:** APT lock wait → remove conflicting Docker packages → install docker.io + containerd + plugins → configure containerd → Docker Hub login (locally) → build and push images (locally) → start Docker daemon.

**Why extracted:** The original role mixed Docker installation (needed by all nodes) with app-specific logic (needed only by specific nodes). Separating them makes `site.yml` plays easier to reason about and re-run selectively.

---

### `ansible/roles/swarm_init/tasks/main.yml`

**What is this:** New role that initializes the Swarm cluster.

**Key pattern — join token distribution:**

```yaml
# On swarmnode:
- community.docker.docker_swarm_info:
  register: swarm_manager_info

- ansible.builtin.set_fact:
    swarm_manager_token: "{{ swarm_manager_info.swarm_facts.JoinTokens.Manager }}"
    swarm_worker_token:  "{{ swarm_manager_info.swarm_facts.JoinTokens.Worker }}"
```

After `set_fact`, any other play in the same Ansible run can read these via `hostvars['swarmnode']['swarm_manager_token']`. This is how the dbserver-join play in `site.yml` gets the token without needing `delegate_to`.

Join tokens change if you run `docker swarm join-token --rotate`. Since Ansible re-fetches them on every run, the join tasks are always idempotent — if a node is already a member, `docker_swarm: state=join` is a no-op.

---

### `ansible/roles/swarm_labels/tasks/main.yml`

**What is this:** New role that assigns Docker node labels.

**Why labels matter:**
In `docker-stack.yml`, placement constraints look like:
```yaml
constraints:
  - node.labels.role == monitoring
```
If this label is not set on any node, the service will fail to schedule and remain in `pending` state. Labels must be applied before stack deployment.

`labels_state: merge` preserves existing labels instead of replacing them. The webserver label task uses `ignore_errors: true` because webserver is not in the swarm during the first provisioning run — it will be re-applied successfully after Phase 3.

---

### `ansible/roles/db_setup/tasks/main.yml`

**What is this:** Extracted from `docker_app` (all the dbserver-specific tasks).

**What it does:** Creates directories, copies `docker-compose-db.yaml` + `Dockerfile-db` + `schema.sql`, starts the PostgreSQL container.

**Nothing about the database mechanism changes.** PostgreSQL continues to run via docker-compose on Node 2. The only difference is that the web service now connects via the private IP instead of a public IP.

---

### `ansible/roles/swarm_stack_deploy/tasks/main.yml`

**What is this:** New role that deploys the application stack to the Swarm.

**What it does:**
1. Creates `/opt/minitwit` on swarmnode
2. Copies `loki/`, `promtail/`, `grafana/` config directories to `/opt/minitwit/` on swarmnode (needed for bind mounts)
3. Copies `docker-stack.yml`
4. Templates `.env` with `DB_ADDR`, `PROM_URL`, `GRAFANA_URL`
5. Runs `docker stack deploy` via `community.docker.docker_stack`

**Why copy config dirs to swarmnode?**
Config files are bind-mounted in `docker-stack.yml`:
```yaml
- /opt/minitwit/loki/loki-config.yaml:/etc/loki/loki-config.yaml:ro
```
Bind mounts require the file to exist on the node where the container runs. Since all monitoring services are constrained to `node.labels.role == monitoring` (webserver), we actually copy the files there too. But the Ansible role copies them to swarmnode initially; re-running after Phase 3 copies them to webserver as well.

---

### `ansible/roles/swarm_stack_deploy/templates/stack-env.j2`

The `.env` file templated with Ansible variables:

```jinja2
DB_ADDR=postgres://minitwit:minitwit@{{ hostvars['dbserver']['private_ip'] }}:5432/minitwit
PROM_URL=http://{{ hostvars['swarmnode']['ansible_host'] }}:5001/prometheus
GRAFANA_URL=http://{{ hostvars['swarmnode']['ansible_host'] }}:5001/grafana/
```

`hostvars['dbserver']['private_ip']` resolves to the `private_ip` set in `host_vars/dbserver.yml`. This is how Ansible injects node-specific values across different hosts.

---

### `ansible/tasks/iptables_forward.yml`

**What is this:** Phase 3 task file — the actual zero-downtime cutover.

**Step-by-step:**

| Step | What happens | Why |
|---|---|---|
| sysctl IP forward | `net.ipv4.ip_forward = 1` | Ubuntu disables kernel packet forwarding by default. Without this, DNAT'd packets are dropped. |
| PREROUTING DNAT | Incoming TCP:5001 on Node 1 → Node 3 private IP:5001 | Intercepts packets at kernel level before any process sees them. Simulator traffic transparently reaches Node 3. |
| POSTROUTING MASQUERADE | Rewrite source IP of forwarded packets | Ensures response packets from Node 3 come back through Node 1 (which can reverse-NAT them to the original client). |
| Health check | `curl Node3:5001` with 5 retries | Safety gate: Compose is only torn down if Node 3 is confirmed healthy. |
| docker_compose_v2 absent | Stops old Compose stack on Node 1 | Port 5001 on Node 1 is now free for Swarm to bind. |
| docker_swarm join | Node 1 joins swarm as manager | Completes the 3-manager cluster. Swarm schedules monitoring services here due to `role=monitoring` label. |
| docker_node label | Applies `role=monitoring` to webserver | Was skipped with `ignore_errors` in swarm_labels role; applied now that webserver is in the swarm. |

---

### `ansible/tasks/iptables_cleanup.yml`

**What is this:** Phase 4 task file — removes the iptables forwarding rules after all nodes have Traefik running.

Runs after you:
1. Edit `docker-stack.yml` to change Traefik to `mode: global`
2. Re-deploy the stack with `--tags swarm_stack_deploy`
3. Confirm `docker service ps minitwit_stack_traefik` shows Traefik on all 3 nodes

---

### `docker-stack.yml`

**What is this:** The new Swarm stack definition, replacing `docker-compose-app.yaml` for production deployments. `docker-compose-app.yaml` is kept for local development and testing.

**Critical differences from `docker-compose-app.yaml`:**

#### 1. Overlay network

```yaml
# docker-compose-app.yaml
# (uses default bridge network — single host only)

# docker-stack.yml
networks:
  overlay_net:
    driver: overlay
    attachable: true
```

Bridge networks are local to one Docker daemon. Overlay networks use VXLAN tunnels over the private VPC IPs to span all swarm nodes. Services on different nodes can reach each other by service name (`http://loki:3100`) only if they are on the same overlay network.

#### 2. Traefik swarm mode

```yaml
# docker-compose-app.yaml
- "--providers.docker=true"

# docker-stack.yml
- "--providers.docker=true"
- "--providers.docker.swarmMode=true"   # ← REQUIRED
```

In Swarm mode, Traefik reads **service** labels instead of **container** labels. Without `swarmMode=true`, Traefik ignores all `traefik.*` labels on Swarm services entirely. Nothing will be routed.

#### 3. `traefik.docker.network` label (critical)

```yaml
# docker-stack.yml — on EVERY service that Traefik should route to
- "traefik.docker.network=minitwit_stack_overlay_net"
```

When a Swarm service has multiple network interfaces (e.g. overlay + host networking), Traefik cannot automatically determine which IP to use for routing. Without this label, Traefik picks the wrong interface and requests fail silently. This is the most common silent failure in Swarm + Traefik setups.

The network name follows the pattern `<stack_name>_<network_name>`:
- Stack name: `minitwit_stack` (from `swarm_stack_name` in group_vars/all.yml)
- Network name: `overlay_net` (defined in docker-stack.yml)
- Full name: `minitwit_stack_overlay_net`

#### 4. Port mode: host

```yaml
ports:
  - target: 5001
    published: 5001
    protocol: tcp
    mode: host   # ← not the default `ingress`
```

`mode: ingress` (default) uses Swarm's routing mesh: a VIP (virtual IP) is created and traffic hitting any node is load-balanced. `mode: host` binds directly to the host's network interface.

We use `host` in Phase 2/3 because the iptables DNAT rule on Node 1 rewrites the destination to Node 3's private IP. The routing mesh adds its own DNAT layer which can interfere with this. Using `host` binding makes Traefik respond directly on that IP without Swarm's VIP layer in between.

In Phase 4, when Traefik runs on all nodes (`mode: global`) and the iptables rules are removed, you can change this to `mode: ingress` to use Swarm's built-in load balancing.

#### 5. Placement constraints

| Service | Constraint | Reason |
|---|---|---|
| traefik | `node.labels.role == ingress` | Must be on Node 3 for iptables DNAT to target the right host |
| web | `node.hostname != dbserver` | Keep app containers off the DB node to avoid resource contention |
| prometheus | `node.labels.role == monitoring` | Named volume `prometheus_data` must stay on one node |
| loki | `node.labels.role == monitoring` | Named volume `loki_data`, config bind mount on same node |
| promtail | `node.labels.role == monitoring` | Needs `/var/run/docker.sock` on the monitoring node |
| grafana | `node.labels.role == monitoring` | Named volume `grafana_data`, datasources config bind mount |

#### 6. Rolling update config

```yaml
deploy:
  update_config:
    parallelism: 1          # update 1 replica at a time
    order: start-first      # start new BEFORE stopping old = zero downtime
    failure_action: rollback
    delay: 5s               # wait 5s between replica updates
```

`start-first` requires spare capacity: for a brief period both the old and new container run simultaneously. With 2 web replicas across 2 nodes, the cluster temporarily needs capacity for 3 containers. Ensure Node 3 and Node 1 together have enough RAM.

---

### `.github/workflows/main.yml` — deploy job

**What changed:** Replaced `scp + docker compose up` with `docker service update`.

**Old flow:**
```
scp: copy docker-compose-app.yaml, loki/, promtail/, grafana/ → server
ssh: write .env → docker compose pull → docker compose up -d → image prune
```

This restarted all containers on every deploy, causing brief downtime.

**New flow:**
```
ssh: docker service update --image <new-tag> minitwit_stack_web
ssh: docker service update --image <new-tag> minitwit_stack_prometheus
```

**Why two separate SSH steps:**
If the web service update fails and rolls back, the prometheus update is not blocked. Each step is independently visible in the Actions UI.

**New secrets required (add in GitHub repo Settings → Secrets):**

| Secret | Value |
|---|---|
| `DO_SWARM_HOST` | Node 3 (swarmnode) public IP |
| `DO_SWARM_HOST_STAGE` | Stage swarmnode public IP (for non-main branches) |

The following secrets are unchanged: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `DO_USER`, `DO_SSH_KEY`, `DO_SSH_KEY_STAGE`.

---

## 5. Prerequisites Before Running the Migration

1. **Install Vagrant DigitalOcean provider:**
   ```bash
   vagrant plugin install vagrant-digitalocean
   ```

2. **Set environment variables:**
   ```bash
   export DIGITAL_OCEAN_TOKEN="your-do-api-token"
   export SSH_KEY_NAME="your-do-ssh-key-name"
   ```

3. **Install Ansible collections:**
   ```bash
   ansible-galaxy collection install -r ansible/requirements.yml
   ```

4. **Provision Node 3 (while Node 1 is still serving live traffic):**
   ```bash
   vagrant up swarmnode
   ```

5. **Fill in private IPs in host_vars:**
   After `vagrant up`, find the private IPs in the DigitalOcean control panel (Droplets → Networking) or by running `ip addr show eth1` on each droplet. Update:
   - `ansible/inventory/host_vars/swarmnode.yml` → `private_ip`
   - `ansible/inventory/host_vars/webserver.yml` → `private_ip`
   - `ansible/inventory/host_vars/dbserver.yml` → `private_ip`

   Also fill in public IPs in `ansible/inventory/hosts.ini`.

6. **Create `ansible/credentials.yml`** (gitignored):
   ```yaml
   DOCKERHUB_USERNAME: "your-dockerhub-username"
   DOCKERHUB_TOKEN: "your-dockerhub-token"
   ```

---

## 6. Migration Runbook

### Step 1: Provision and validate Node 3

```bash
vagrant up swarmnode
```

Confirm Docker is running:
```bash
ssh root@<NODE3_PUBLIC_IP> "docker version"
```

### Step 2: Run Phase 1 provisioning (no live traffic impact)

This sets up the Swarm on Nodes 2 and 3, assigns labels, starts the DB, and deploys the stack. Node 1 is untouched.

```bash
ansible-playbook ansible/site.yml --skip-tags phase3,phase4
```

Watch for errors. Common issues are listed in Section 10.

### Step 3: Validate the Swarm stack on Node 3

Before touching Node 1, confirm the new stack is working:

```bash
# Check all services are running
ssh root@<NODE3_PUBLIC_IP> "docker service ls"

# Check web replicas specifically
ssh root@<NODE3_PUBLIC_IP> "docker service ps minitwit_stack_web"

# Test that HTTP traffic reaches the app
curl http://<NODE3_PUBLIC_IP>:5001/

# Check logs if something is wrong
ssh root@<NODE3_PUBLIC_IP> "docker service logs minitwit_stack_web --tail 50"
```

All services should show `2/2` or `1/1` replicas. The `curl` should return a valid HTTP response (200, 301, or 302).

### Step 4: Execute Phase 3 — zero-downtime cutover

```bash
ansible-playbook ansible/site.yml --tags phase3
```

This play:
1. Enables IP forwarding on Node 1
2. Adds iptables DNAT forwarding on Node 1
3. Health-checks Node 3 (if this fails, nothing else happens)
4. Stops docker-compose on Node 1
5. Joins Node 1 to the Swarm

Watch the Ansible output. If the health check task fails, investigate Node 3 before re-running.

### Step 5: Validate traffic still works via Node 1's IP

```bash
# This should still work — iptables is forwarding to Node 3
curl http://<NODE1_PUBLIC_IP>:5001/

# Confirm Node 1 is now in the swarm
ssh root@<NODE3_PUBLIC_IP> "docker node ls"
```

Expected `docker node ls` output:
```
ID         HOSTNAME    STATUS   AVAILABILITY   MANAGER STATUS
xxx *      swarmnode   Ready    Active         Leader
yyy        dbserver    Ready    Active         Reachable
zzz        webserver   Ready    Active         Reachable
```

### Step 6: Switch Traefik to global mode (Phase 4 prerequisite)

Edit `docker-stack.yml` — find the traefik service `deploy` section and change it to:

```yaml
  traefik:
    # ... (keep everything else the same)
    ports:
      - target: 5001
        published: 5001
        protocol: tcp
        mode: ingress   # ← change from host to ingress for routing mesh
    deploy:
      mode: global      # ← change from replicated/1 to global
      # ↓ remove the placement constraints block entirely
```

Re-deploy the stack:
```bash
ansible-playbook ansible/site.yml --tags swarm_stack_deploy
```

Confirm Traefik is running on all 3 nodes:
```bash
ssh root@<NODE3_PUBLIC_IP> "docker service ps minitwit_stack_traefik"
```

### Step 7: Execute Phase 4 — remove iptables rules

```bash
ansible-playbook ansible/site.yml --tags phase4
```

### Step 8: Final validation

```bash
# All nodes respond directly
curl http://<NODE1_PUBLIC_IP>:5001/
curl http://<NODE2_PUBLIC_IP>:5001/
curl http://<NODE3_PUBLIC_IP>:5001/

# Grafana is reachable
curl http://<NODE3_PUBLIC_IP>:5001/grafana

# Swarm is healthy
ssh root@<NODE3_PUBLIC_IP> "docker service ls"
ssh root@<NODE3_PUBLIC_IP> "docker node ls"
```

---

## 7. GitHub Actions Changes

### Updated secrets (add these in GitHub Settings → Secrets → Actions)

| Secret | Value | Notes |
|---|---|---|
| `DO_SWARM_HOST` | Node 3 public IP | New — replaces `DO_HOST` in deploy job |
| `DO_SWARM_HOST_STAGE` | Stage Node 3 public IP | New |

### Unchanged secrets

`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `DO_USER`, `DO_SSH_KEY`, `DO_SSH_KEY_STAGE`, `DO_DB`, `DO_DB_STAGE`

### How to verify the new deploy works

Push a test commit to main (or merge a PR) and watch the Actions run. The deploy job should show two steps:
1. "Deploy app image to Swarm (rolling update)"
2. "Deploy prometheus image to Swarm (rolling update)"

Each should complete in under 60 seconds. To see the rollout in real time:
```bash
ssh root@<NODE3_PUBLIC_IP> "docker service ps minitwit_stack_web --no-trunc"
```

---

## 8. Verification Steps

After completing the full migration, verify each component:

```bash
# 1. Cluster health
docker node ls  # all 3 nodes Ready, 3 managers

# 2. All services running
docker service ls  # all REPLICAS match desired count

# 3. Web application reachable from each node's public IP
curl http://<NODE1_PUBLIC_IP>:5001/
curl http://<NODE2_PUBLIC_IP>:5001/
curl http://<NODE3_PUBLIC_IP>:5001/

# 4. Prometheus accessible (basic auth: admin / check credentials)
curl -u admin:<password> http://<NODE3_PUBLIC_IP>:5001/prometheus/-/healthy

# 5. Grafana accessible
curl http://<NODE3_PUBLIC_IP>:5001/grafana

# 6. Check no services are in failed/shutdown state
docker service ps minitwit_stack_web --filter "desired-state=running"
docker service ps minitwit_stack_traefik
docker service ps minitwit_stack_prometheus

# 7. Database still accessible (from any app node)
docker run --rm --network minitwit_stack_overlay_net postgres:15-alpine \
  psql "postgres://minitwit:minitwit@<NODE2_PRIVATE_IP>:5432/minitwit" -c "\dt"
```

---

## 9. Rollback Procedures

### If Phase 3 health check fails

Phase 3 has a built-in safety guard: if Node 3's health check fails, docker-compose on Node 1 is NOT stopped. The iptables rules are still in place but Node 1's Compose stack is still running (it just isn't receiving traffic through the forward path yet). To revert:

```bash
# On Node 1 — manually remove iptables rules
ssh root@<NODE1_PUBLIC_IP>
iptables -t nat -D PREROUTING -p tcp --dport 5001 -j DNAT --to-destination <NODE3_PRIVATE_IP>:5001
iptables -t nat -D POSTROUTING -j MASQUERADE
```

Compose on Node 1 never stopped, so traffic is immediately restored once the DNAT rule is removed.

### If a deployment fails after Phase 3

`--update-failure-action rollback` in `docker service update` means Swarm auto-reverts the service to its previous image. To manually trigger rollback:

```bash
docker service rollback minitwit_stack_web
```

### To fully revert to docker-compose (last resort)

```bash
# Remove Node 1 from swarm
ssh root@<NODE1_PUBLIC_IP> "docker swarm leave --force"

# Start old Compose stack
ssh root@<NODE1_PUBLIC_IP> "cd /opt/minitwit && docker compose -f docker-compose-app.yaml up -d"
```

---

## 10. Common Problems and Fixes

### Problem: Services stuck in `pending` state

**Symptom:** `docker service ls` shows `0/2` replicas; `docker service ps minitwit_stack_web` shows `pending`.

**Cause:** Placement constraints don't match any node. Either:
- The node label was not applied (check `docker node inspect webserver --format '{{.Spec.Labels}}'`)
- The node is not in `Active` availability (check `docker node ls`)

**Fix:**
```bash
# Re-apply labels
ansible-playbook ansible/site.yml --tags swarm_labels

# Or manually
docker node update --label-add role=monitoring webserver
```

### Problem: Traefik not routing to services (502/503)

**Symptom:** Requests reach Traefik (you see access logs) but get 502 Bad Gateway.

**Cause:** Missing `traefik.docker.network` label, or the web containers are on a different network.

**Fix:** Verify the label is correct:
```bash
docker service inspect minitwit_stack_web --format '{{json .Spec.Labels}}' | jq .
# Should include: "traefik.docker.network": "minitwit_stack_overlay_net"
```

Verify the actual overlay network name:
```bash
docker network ls | grep overlay
# Should show: minitwit_stack_overlay_net
```

### Problem: Database connection refused

**Symptom:** Web service logs show `connection refused` or `no route to host` for the DB address.

**Cause:** `private_ip` in `host_vars/dbserver.yml` is wrong, or PostgreSQL isn't bound on that IP.

**Fix:**
```bash
# On dbserver — check PostgreSQL is listening on the private IP
ss -tlnp | grep 5432

# Verify the private IP from inside a web container
docker run --rm --network minitwit_stack_overlay_net alpine nc -z <NODE2_PRIVATE_IP> 5432 && echo "OK"
```

### Problem: ansible-playbook fails with "community.docker not found"

**Fix:**
```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

### Problem: webserver label fails in swarm_labels role

**This is expected.** The `ignore_errors: true` on that task means the play continues. The label is applied during Phase 3 once webserver is in the swarm. Re-running the full playbook after Phase 3 will apply it successfully.

### Problem: `docker service update` in GitHub Actions fails with "no such service"

**Cause:** The stack name in the service update command doesn't match the actual stack name.

**Fix:** Verify the service names:
```bash
ssh root@<NODE3_PUBLIC_IP> "docker service ls"
# Look for the exact service name — it will be <stack_name>_web
```

Update `swarm_stack_name` in `ansible/inventory/group_vars/all.yml` if needed, re-deploy the stack, and update the service names in `.github/workflows/main.yml`.
