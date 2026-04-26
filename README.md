# DevOps26_RE_minitwit

This repository contains a Go implementation of the MiniTwit application, designed for the ITU DevOps course. The project features a containerized development environment, automated cloud deployment on DigitalOcean, and a modern Infrastructure as Code (IaC) approach.

## 🚀 Public Access

The application is deployed as a Docker Swarm stack and is reachable at:

| Service | URL |
| :--- | :--- |
| **MiniTwit Web UI** | [http://runtimetwiterror.dev](http://runtimetwiterror.dev) |
| **Simulator API** | [http://runtimetwiterror.dev/api](http://runtimetwiterror.dev/api) |
| **Prometheus** | [http://runtimetwiterror.dev/prometheus](http://runtimetwiterror.dev/prometheus) |
| **Grafana** | [http://runtimetwiterror.dev/grafana](http://runtimetwiterror.dev/grafana) |

---

## 💻 Local Development Quickstart

### 1. Static Analysis (Quality Gate)
Before pushing code, ensure your changes follow the project's coding standards:
* `make lint`: Runs the full suite (`gofumpt`, `golangci-lint`, `hadolint`, `htmlhint`, `yamllint`).
* `make install-tools`: Installs all necessary local linting dependencies.

### 2. Local Integration Testing (All-in-One)
The local testing environment is **zero-config** and does not require a `.env` file or external scripts. It uses a self-contained ephemeral stack:

```bash
# Start the full test stack (App, DB, Selenium, and Test Runner)
docker compose -f docker-compose-tests.yaml up --build --abort-on-container-exit --exit-code-from test

# Clean up after tests
docker compose -f docker-compose-tests.yaml down -v
```

---

## 🏗 Docker Architecture

The project uses a **decoupled Docker setup** with optimized images and Docker Swarm for orchestration.

### Dockerfiles

| File | Purpose |
| :--- | :--- |
| **Dockerfile-app** | Production-ready Go application (Multi-stage build) |
| **Dockerfile-test** | Full testing environment (Go + Python + Selenium) |

### Docker Stack & Compose

- **docker-stack.yml**: Deployment manifest for the production Swarm cluster (App, Traefik, Monitoring).
- **docker-compose-db.yaml**: Standalone Database server configuration with persistent storage.
- **docker-compose-tests.yaml**: Ephemeral stack used for CI/CD and local integration testing.

---

## 🛠 Cloud Deployment (DigitalOcean)

Our infrastructure consists of **3 nodes** managed via **Terraform** and **Ansible**:
1. **Manager 1 (Leader)**: Swarm manager and main ingress node.
2. **Manager 2**: High-availability swarm manager.
3. **DB Server**: Dedicated node for PostgreSQL and the Monitoring stack.

### CI/CD Pipeline (GitHub Actions)
On every push/PR to `main`, the pipeline executes:
1. **Static Analysis**: Lints Go code, Dockerfiles, HTML, and YAML.
2. **Test**: Spins up the `docker-compose-tests.yaml` stack to run integration and simulator tests.
3. **Build & Push**: Builds production images and pushes them to Docker Hub with unique tags.
4. **Deploy**: SSHs into the Manager node to trigger `docker stack deploy` using the latest images and environment variables.

---

## 🏗 Design Decisions

### DB Management: GORM AutoMigrate
We utilize **GORM's AutoMigrate** feature, treating our Go structs as the **Single Source of Truth** for the database schema. This eliminates the need for manual `schema.sql` files and prevents accidental data loss during deployment.

### Infrastructure: Node Separation
We separate the App and DB/Monitoring nodes to ensure independent scalability:
- **App Nodes**: Lightweight nodes for Go services.
- **DB/Monitoring Node**: A high-resource node (2GB RAM / 50GB Disk) to handle PostgreSQL persistence and the resource-heavy monitoring stack (Prometheus, Loki, Grafana).

### Security: Secrets vs. Variables
We strictly separate sensitive credentials from general configuration:
- **Secrets**: Encrypted data (SSH Keys, Tokens, App Secret Keys).
- **Variables**: Plain-text settings (IPs, Domains, Usernames).

---

## 🔐 GitHub Actions Configuration

To run the CI/CD pipeline, the following Secrets and Variables must be configured in GitHub Actions:

### Secrets (Encrypted)
| Secret Name | Description |
| :--- | :--- |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token for image registry. |
| `DO_SSH_KEY` | Private Key for Production server SSH access. |
| `DO_SSH_KEY_STAGE` | Private Key for Staging server SSH access. |
| `APP_SECRET_KEY` | Secret Key for secure Production session cookies. |
| `APP_SECRET_KEY_STAGE` | Secret Key for secure Staging session cookies. |

### Variables (Plain-text)
| Variable Name | Description |
| :--- | :--- |
| `DOCKERHUB_USERNAME`| Your Docker Hub account username. |
| `DO_USER` | SSH username (e.g., `root`). |
| `DOMAIN` | Production domain (e.g., `runtimetwiterror.dev`). |
| `DOMAIN_STAGE` | Staging domain for PR testing. |
| `DO_HOST` | Public IP of Production Manager 1. |
| `DO_HOST_STAGE` | Public IP of Staging Manager 1. |
| `DO_HOST_2` | Public IP of Production Manager 2. |
| `DO_HOST_2_STAGE` | Public IP of Staging Manager 2. |
| `DB_PUBLIC_IP` | Public IP of Production DB Server (for SSH maintenance). |
| `DB_PUBLIC_IP_STAGE` | Public IP of Staging DB Server (for SSH maintenance). |
| `DB_PRIVATE_IP` | Internal VPC IP of Production DB Server (for App connectivity). |
| `DB_PRIVATE_IP_STAGE` | Internal VPC IP of Staging DB Server (for App connectivity). |

---

## 📂 Project Structure

```text
.
├── ansible/         # Ansible playbooks for server configuration
├── docker/          # Optimized Dockerfiles
├── grafana/         # Grafana dashboards and datasources
├── loki/            # Loki logging configuration
├── prometheus/      # Prometheus alerting and monitoring rules
├── promtail/        # Promtail log shipping configuration
├── static/          # Static assets (CSS, Images, JS)
├── templates/       # HTML templates for the Gin framework
├── test/            # Integration tests and API simulator
├── Makefile         # One-click local linting and shortcuts
├── main.go          # Application entry point
└── docker-stack.yml # Swarm deployment manifest
```