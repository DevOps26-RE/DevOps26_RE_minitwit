## CI/CD pipelines, deployment and release

Our delivery process evolved incrementally from manual operations to commit-driven automation:

1. **Manual local phase (Python):** The project started as a local Python app with manual startup/testing. We used helper bash scripts for local control (legacy examples are still kept under `tmp/legacy/`).
2. **Containerized but still manual:** We then introduced Docker, but builds and runs were still triggered manually on local machines.
3. **Vagrant + DigitalOcean provisioning:** Next, we used `Vagrantfile`-based provisioning for droplets. Early provisioning relied on inline shell scripts (Docker install, DB/app startup, IP handoff via `db_ip.txt`), so deployment was cloud-based but still operator-driven.
4. **Ansible replacing shell provisioning:** We migrated host setup and deployment logic into Ansible (`ansible/site.yml`, `ansible/roles/docker_app`), making bootstrap and re-runs more repeatable.
5. **GitHub Actions CI/CD adoption:** We added commit-triggered automation in `.github/workflows/main.yml`, moving from manual build/deploy to pipeline-based quality gates, image build/push and remote deployment.
6. **Pipeline hardening and release split:** The pipeline matured into lint → test → build/push → deploy, with branch-aware image tags and PR traceability comments; releases were separated into `release.yml` (`v*` tags).
7. **Environment separation + controlled DB updates:** We introduced stage/prod handling and a dedicated manual DB workflow (`deploy-db.yml`) because DB compose updates can cause brief downtime and require explicit operator intent.
8. **Terraform + Ansible one-click bootstrap:** Finally, infrastructure provisioning moved to Terraform (`terraform/stage`, `terraform/production`), which generates inventory/env artifacts and triggers Ansible via `local-exec` to bootstrap a full environment.

The current operating model is therefore: **Terraform + Ansible for environment creation/bootstrap** and **GitHub Actions for ongoing application delivery per commit**. Historical files such as `Vagrantfile` and `Vagrantfile_staging` remain in the repository for process documentation but are no longer the primary deployment path.
