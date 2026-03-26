# DevOps26_RE_minitwit

This repository contains a Go implementation of the MiniTwit application, designed for the ITU DevOps course. The project features a containerized development environment and automated cloud deployment on DigitalOcean.

## 🚀 Public Access

The application is deployed and reachable at the following endpoints:

| Service | URL |
| :--- | :--- |
| **MiniTwit Web UI** | [http://164.92.186.201:5001](http://164.92.186.201:5001) |
| **Simulator API** | [http://164.92.186.201:5001/api](http://164.92.186.201:5001/api) |

---

## 💻 Local Development Quickstart

To get the project running locally for the first time, follow these steps to set up your environment:

### 1. Initialize Local Files
We use template files to prevent local configuration or binary data from cluttering the version control.

```bash
# 1. Create your local working database from the template
cp tmp/minitwit.db.example tmp/minitwit.db

# 2. Create the DB IP configuration file at root 
# (Set to 127.0.0.1 for local SQLite or your remote DB server IP)
echo "127.0.0.1" > db_ip.txt
```

### 2. Run with Docker (Recommended)
Following modern DevOps practices, we recommend using a single Dockerfile with **multi-stage builds** to handle both development and production.

* **Build image**: `./develop.sh build`
* **Enter Container**: `./develop.sh run`
* **Inside the container**: The project root is synced to the container's workspace. You can run `go run main.go` directly.

### 3. Using Makefile (Shortcuts)
You can use the following commands for quick task execution:
* `make run`: Starts the Go application locally.
* `make build`: Compiles the Go binary.
* `make test-sim`: Runs the Python simulator against your local instance.

---

## � Docker Architecture

The project uses a **decoupled Docker setup** with three separate Dockerfiles and dedicated Docker Compose configurations:

### Dockerfiles

| File | Purpose | Used By |
| :--- | :--- | :--- |
| **Dockerfile-app** | Production Go application container | docker-compose-app.yaml (webserver) |
| **Dockerfile-db** | PostgreSQL database container | docker-compose-db.yaml (dbserver) |
| **Dockerfile-test** | Testing environment (Go + Python) | docker-compose-tests.yaml (local testing) |

### Docker Compose Files

- **docker-compose-db.yaml**: Database server only (persistent volume for data)
- **docker-compose-app.yaml**: Application server with remote database connectivity
- **docker-compose-tests.yaml**: Full stack (db + app + test runner) for local development

### Local Testing (All-in-One)

For local development, run the complete stack:
```bash
docker compose -f docker-compose-tests.yaml up --build --abort-on-container-exit --exit-code-from test
```

This starts:
- PostgreSQL database container
- Go application container
- Selenium Chromium container
- Python test runner container (integration + API simulator + UI/E2E)

---

## �🛠 Cloud Deployment (DigitalOcean)

Infrastructure provisioning and application deployment are automated using **Vagrant** with the DigitalOcean provider.

### 1. Prerequisites
Ensure the following environment variables are configured on your host machine:

| Variable | Description |
| :--- | :--- |
| `DIGITAL_OCEAN_TOKEN` | Your DigitalOcean Personal Access Token. |
| `SSH_KEY_NAME` | The name of the SSH key registered in your DigitalOcean account. |

```bash
export DIGITAL_OCEAN_TOKEN="your_actual_token_here"
export SSH_KEY_NAME="your_key_name"
```

### 2. Provisioning
To provision the Database and Web servers and deploy the latest code:
```bash
vagrant up --provider=digital_ocean
```

---

## 🧪 Testing & Troubleshooting

### Full CI Quality Gate (Local Reproduction)
The CI pipeline runs all suites as one quality gate. If any suite fails, build and deployment are blocked.

Included suites:
- Integration tests: auth flow, timeline visibility, follow/unfollow
- API simulator test: compatibility scenario from `test/minitwit_scenario.csv`
- UI/E2E tests: Selenium-based browser flow (including DB-side verification)

Run locally exactly like CI:
```bash
docker compose -f docker-compose-tests.yaml up --build --abort-on-container-exit --exit-code-from test
docker compose -f docker-compose-tests.yaml down -v
```

### Run Simulator API Tests
Test your API compatibility using the provided Python simulator:
```bash
# Ensure you are at the project root
python3 test/minitwit_simulator.py "http://localhost:5001/api"
python3 test/minitwit_simulator.py "http://164.92.186.201:5001/api"
```

### Monitor Webserver Logs
To view real-time application logs, SSH into the webserver:
```bash
vagrant ssh webserver
tail -f /var/log/minitwit.log
```

---

## 🏗 Design Decisions

### Language: Go
We chose Go for its simplicity, strong standard library, and excellent performance for web services. Its built-in concurrency model (goroutines), fast compile times, and single-binary output make it well-suited for a containerized, cloud-deployed application like MiniTwit.

### Infrastructure: Two VMs (App + DB)
We separate the web server and database into two distinct VMs following standard practice. The main benefit is independent scalability: if the app server becomes a bottleneck, we can scale it horizontally without touching the database, and vice versa. This also follows the structure of the provided example Vagrantfile from the course.

### DB Abstraction: GORM
We use **GORM** as our Object-Relational Mapper (ORM) to abstract database interactions. 
- **Type Safety**: Instead of raw SQL strings, we interact with Go structs (e.g., `User`, `Message`).
- **Decoupling**: The application logic remains independent of specific SQL syntax, making it easier to maintain or switch database engines.
- **Relationships**: GORM handles complex joins and foreign keys using `Preload`, keeping our data fetching logic clean and readable.

### CI/CD: GitHub Actions
Our project utilizes **GitHub Actions** for an automated pipeline:
- **Testing**: On every push/PR to `main`, we run integration + API simulator + UI/E2E tests via Docker Compose as a mandatory quality gate.
- **Continuous Deployment**: Successful pushes to the `main` branch trigger a Docker build, which is pushed to Docker Hub and automatically deployed to our DigitalOcean Droplet via SSH.
- **Releases**: Pushing a version tag (e.g., `v1.0.0`) automatically generates a GitHub Release with automated changelogs.
---

## 📂 Project Structure

```text
.
├── db/              # Database schema and initialization scripts (schema.sql is here)
├── docker/          # Dockerfiles (Multi-stage build strategy)
├── static/          # Static assets (CSS, Images, JS)
├── templates/       # HTML templates for the Gin framework
├── test/            # Python simulator and test scenario CSVs
├── tmp/             # Local DB templates (Real DB and legacy folder are ignored)
├── simulator_api.go          # Application entry point
├── minitwit.go          # Application entry point
├── Makefile         # Shortcuts for common tasks
└── Vagrantfile      # Infrastructure as Code (IaC) configuration
└── develop.sh    # for local developemnt
```
## Static tools: 
### GO
- golangci-lint is a fast parallel-running linters static tool for Go, desgined seamlessly        into a continuous integration (CI) pipelines. Rather than being a single linter, it bundles     over 100 different static analysis  toosl to check for errors, code style, security issues,
  and performance optimizations. It is highly configurable through a `golangci.yml` file,
  allowing you to specify which linters and checks are included during execution.
- gofumpt is a strict more opinionated fork of the standard `gofmt` Go code formatter. It is      desgined to enforce a higher level of consistency in Go codebases, providing more than 20       additional rules on top of  `gofmt` while remaining 100% backward compatible.
### Dockefile
- Hadolint is a specialized Dockerfile linter, analyzing and enforcing best practices. It
  serves as a static analysis tool that helps developers create secure, efficient, and
  maintainable container images by flagging error, inefficient instructions, and security risks
  before build occur. Hadolint also uses configuration file called `.hadolint.yaml` which is
  fully configurable. As modern developent leans havily on automating the tasks integrating
  Hadolint into Continuous Integration and Continuous Delivery (CI/CD).
### HTML
- HTMLhint is a tool (a linter) that analyzes your HTML code and warns about potential
  problems. It focuses on code quality, correctness and best practices. Like most tools of
  this kind, it can be customized to suit your needs. For this purpose, a configuration file
  called `.htmlhintrc` (or `.htmlhintrc.yaml`) is used.  
### yaml/yml
- yamllint is a tool that analyzes YAML (.yml/.yaml) files. It checks for syntax validity as
  well as common issues such as duplicate keys and formatting problems like line length,
  trailing spaces, and incorrect indentation. It uses a set of independent rules to detect
  problems, where each rule can be enabled, disabled, or customized. All of these settings can
  be configured through a .yamllint file.

## GitHub Actions Secrets Configuration

| Secret Name              | Category | Description                                                                                                                                                 |
|:-------------------------| :--- |:------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **`DOCKERHUB_USERNAME`** | Docker Hub | Your Docker Hub username.                                                                                                                                   |
| **`DOCKERHUB_TOKEN`**    | Docker Hub | A dedicated Docker Hub Access Token used for authentication.                                                                                                |
| **`DO_HOST`**            | Production | The IP address of your production DigitalOcean Droplet (triggered by the `main` branch).                                                                    |
| **`DO_DB`**              | Production | The IP address of your production database server.                                                                                                          |
| **`DO_USER`**            | SSH Auth | The SSH username used to log into the DigitalOcean servers (e.g., `root`). This is shared between production and staging environments.                      |
| **`DO_SSH_KEY`**         | SSH Auth | The SSH Private Key for server authentication. Make sure to paste the entire key block, including `-----BEGIN OPENSSH PRIVATE KEY-----` and the end marker.  This is shared between production and staging environments.|
| **`DO_DB_STAGE`**        | Staging | The IP address of your staging database server.                                                                                                             |
| **`DO_HOST_STAGE`**      | Staging | The IP address of your staging DigitalOcean Droplet (triggered by pull requests or test branches).                                                          |
| **`DO_SSH_KEY_STAGE`**   | SSH Auth | The SSH Private Key for server authentication. Make sure to paste the entire key block, including `-----BEGIN OPENSSH PRIVATE KEY-----` and the end marker.  This is shared between production and staging environments.|
