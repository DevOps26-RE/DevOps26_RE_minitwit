## Security hardening

Security is handled across the application, network and deployment pipeline. The following sections highlight specific implementations within the codebase.

### SQL Injection Prevention (GORM)
Raw SQL strings were replaced with GORM. It automatically parameterizes queries to prevent injection vulnerabilities. For example, in `minitwit.go`, user lookups are handled safely without string concatenation:

```go
// minitwit.go
func get_user_id(username string) (int, error) {
	var user User
	// GORM safely parameterizes the QueryUsername ("username = ?") variable
	result := db.Where(QueryUsername, username).First(&user)
	// ...
}
```

### Network Isolation and Firewalls
DigitalOcean firewalls restrict public ingress to HTTP and HTTPS. Internal Swarm traffic, SSH and the PostgreSQL database are isolated within a private VPC. This is defined as infrastructure-as-code in `terraform/production/main.tf`:

```hcl
# terraform/production/main.tf
resource "digitalocean_firewall" "minitwit_fw" {
  name = "minitwit-prod-firewall"
  # ...
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  # Internal traffic restricted to VPC IP range
  inbound_rule {
    protocol         = "tcp"
    port_range       = "5432" # PostgreSQL
    source_addresses = [digitalocean_vpc.minitwit_vpc.ip_range]
  }
}
```

### Data in Transit (TLS)
Traefik automatically provisions Let's Encrypt certificates for all public traffic. The routing and TLS termination are configured via Docker Swarm labels, ensuring that all external communication is encrypted before reaching the application containers.

### Secret Management
Environment variables are templated by Terraform. Highly sensitive credentials (SSH keys, Docker Hub tokens, application secrets) are injected exclusively via GitHub Secrets during CI/CD to keep them out of version control. For instance, the deployment step in `.github/workflows/main.yml` securely accesses the SSH key:

```yaml
# .github/workflows/main.yml
  deploy:
    # ...
    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.2.1
        env:
          SECRET_KEY: ${{ github.ref == 'refs/heads/main' && secrets.APP_SECRET_KEY || secrets.APP_SECRET_KEY_STAGE }}
        with:
          key: ${{ github.ref == 'refs/heads/main' && secrets.DO_SSH_KEY || secrets.DO_SSH_KEY_STAGE }}
          # ...
```
