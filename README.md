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

## 🏗 Architecture & Design Decisions

### 1. Infrastructure: Node Separation
We separate the App and DB/Monitoring nodes to ensure independent scalability and stability.
* **App Nodes (Manager 1 & 2):** Lightweight nodes acting as Swarm Managers to serve the Go application and Traefik proxy.
* **DB/Monitoring Node (Database):** A high-resource node dedicated to PostgreSQL persistence and the resource-heavy monitoring stack (Prometheus, Loki, Grafana).

### 2. Database Management: GORM AutoMigrate
We utilize GORM's AutoMigrate feature, treating our Go structs as the Single Source of Truth for the database schema. This eliminates the need for manual `schema.sql` files and prevents accidental data missing during deployment.

### 3. Security: Secrets vs. Variables
We strictly separate sensitive credentials from general configuration in GitHub Actions.
* **Secrets:** Encrypted data (Docker Hub Tokens, SSH Keys, App Secret Keys).
* **Variables:** Plain-text settings (IP Addresses, Domains, Usernames).

---

## 🛠 Infrastructure Setup (First-Time Provisioning)

We use a modern IaC approach. **Terraform** provisions the raw cloud resources, and **Ansible** configures the operating systems and Docker Swarm cluster.

### Step 1: Provision Cloud Resources (Terraform)
Terraform manages the DigitalOcean VPC, Firewalls, and Droplet creation.

* **Environment Variables Required:** Export `TF_VAR_do_token` (DigitalOcean API Token) and `TF_VAR_ssh_key_name` (Your SSH Key Name registered on DigitalOcean).
This command will map your $DIGITAL_OCEAN_TOKEN and $SSH_KEY_NAME one time (will be cleaned once the terminal is closed)
```bash
export TF_VAR_do_token=$DIGITAL_OCEAN_TOKEN
export TF_VAR_ssh_key_name=$SSH_KEY_NAME
```
* **Execution:** Navigate to `terraform/stage` (or `prod`), then run `terraform init`, `terraform plan`, and `terraform apply`.
If this is not the first time you run, you may encounter a lock file, in that way, use `terraform init -reconfigure` or `terraform plan -lock=false`
* **State Management:** The `terraform.tfstate` file tracks the real-world infrastructure and must be ignored in Git. The `variables.tf` defines required inputs.
* **Artifact Generation:** Upon successful application, Terraform dynamically generates the Ansible inventory file (`inventory_stage.ini`) mapping Droplets to their respective roles (`[swarm_managers]` and `[swarm_leaders]`).

*Migration Note for Production:* To avoid downtime, the existing production system will only be migrated to this Terraform-managed structure during the next scheduled release window.

### Step 2: Configure Server Environments (Ansible)
Ansible connects to the newly created Droplets to install dependencies and initialize the cluster.

* **Execution:** Navigate to the `ansible/` directory and run `ansible-playbook -i inventory_stage.ini site.yml`.
    * Reminder: Change `inventory_stage.ini` to `inventory.ini` for production
* **Configuration (ansible.cfg):** Disables strict host key checking to allow seamless automation for newly created IP addresses.
* **Playbook Execution Flow:**
    * Uses the `apt` package manager to update Ubuntu systems.
    * Installs the Docker Engine (which natively includes Swarm capabilities).
    * Initializes the Docker Swarm leader on Manager 1 and joins Manager 2.
    * Prepares necessary directories for database mounts and application configurations.

---

## 🚀 CI/CD Pipeline (GitHub Actions)

Once the infrastructure is up, GitHub Actions takes over the continuous deployment.

### Main Workflow (App Updates)
Triggered automatically on every push or PR to the `main` branch.
* **Static Analysis:** Runs linters for Go, Dockerfiles, HTML, and YAML.
* **Test:** Spins up an ephemeral local stack (`docker-compose-tests.yaml`) to run integration and simulator tests.
* **Build & Push:** Builds multi-stage production images and pushes them to Docker Hub.
* **Deploy:** SSHs into the Swarm Manager to execute `docker stack deploy`, updating the web services with zero downtime.

### Database Workflow (DB Updates)
Triggered **manually** via the `workflow_dispatch` button in the Actions tab.
* **Purpose:** Updates the `docker-compose-db.yaml` configuration on the DB node.
* **Safety Protocol:** Requires explicit selection of the target environment (Stage or Prod). Because replacing the database container introduces a few seconds of downtime, this workflow is decoupled from automatic code pushes and should only be triggered manually during low-traffic maintenance windows.

### Release Workflow
Triggered automatically when a semantic version tag is pushed to `main`, creating an official GitHub Release.

---

## 💻 Local Development Quickstart

### 1. Static Analysis (Quality Gate)
Ensure your changes follow the project's coding standards before pushing.
* Run `make install-tools` to install local linting dependencies.
* Run `make lint` to execute the full suite (`gofumpt`, `golangci-lint`, `hadolint`, `htmlhint`, `yamllint`).

### 2. Local Integration Testing
The local testing environment is zero-config and uses a self-contained ephemeral stack.
* Run `docker compose -f docker-compose-tests.yaml up --build --abort-on-container-exit --exit-code-from test` to execute the full test suite (App, DB, Selenium, and Test Runner).
* Run `docker compose -f docker-compose-tests.yaml down -v` to clean up volumes after testing.

---

## 🔐 Required GitHub Actions Variables & Secrets

To replicate this deployment, configure the following in your repository settings:

### Secrets (Encrypted)
| Secret Name | Description |
| :--- | :--- |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token for the image registry. |
| `DO_SSH_KEY` | Private SSH Key for Production deployment access. |
| `DO_SSH_KEY_STAGE` | Private SSH Key for Staging deployment access. |
| `APP_SECRET_KEY` | Secret Key for secure Production session cookies. |
| `APP_SECRET_KEY_STAGE` | Secret Key for secure Staging session cookies. |

### Variables (Plain-text)
| Variable Name | Description |
| :--- | :--- |
| `DOCKERHUB_USERNAME`| Your Docker Hub account username. |
| `DO_USER` | SSH username (e.g., `root`). |
| `DOMAIN` | Production domain (e.g., `runtimetwiterror.dev`). |
| `DOMAIN_STAGE` | Staging domain or IP for PR testing. |
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
├── ansible/         # Playbooks for server configuration and Swarm initialization
├── docker/          # Optimized Dockerfiles for App and Test environments
├── grafana/         # Dashboards and datasources configuration
├── loki/            # Logging backend configuration
├── prometheus/      # Alerting and monitoring metric rules
├── promtail/        # Log shipping agent configuration
├── static/          # Static web assets (CSS, Images, JS)
├── templates/       # HTML templates for the Go Gin framework
├── test/            # Integration tests and Python API simulator
├── Makefile         # One-click shortcuts for local development
├── minitwit.go      # Application entry point
├── monitor.go       # Monitor API entry point
├── simulator_api.go # Simulator API entry point
├── docker-stack.yml # Production Swarm deployment manifest
├── docker-compose-db.yaml # Database server manifest
└── docker-compose-tests.yaml # Ephemeral testing environment stack
```