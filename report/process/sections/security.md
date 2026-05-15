## Security hardening

Security is handled across the application, network and deployment pipeline:

- **SQL Injection:** Raw SQL strings were replaced with GORM. It automatically parameterizes queries to prevent injection vulnerabilities.
- **Network Isolation:** DigitalOcean firewalls restrict public ingress to HTTP and HTTPS. Internal Swarm traffic, SSH and the PostgreSQL database are isolated within a private VPC.
- **TLS:** Traefik automatically provisions Let's Encrypt certificates for all public traffic.
- **Secrets:** Environment variables are templated by Terraform. Highly sensitive credentials (SSH keys, Docker Hub tokens, application secrets) are injected exclusively via GitHub Secrets during CI/CD to keep them out of version control.
