## Availability and scaling

Our Minitwit service runs on a 3-node Docker Swarm in DigitalOcean. Two manager nodes run 3 replicas of the Minitwit app, while the third node runs the database and monitoring stack. Node roles are defined via Terraform resource groups, which Ansible uses to apply Docker Swarm placement labels during provisioning. Services in `docker-stack.yml` are constrained to nodes with matching labels and Swarm automatically reschedules replicas if a node goes down.

The database can only be scaled vertically (larger VM). The application supports horizontal scaling by adding droplets to the Terraform configuration and assigning them the ingress role.

When deploying a new version, Swarm performs a rolling update: each new replica starts before the old one stops (`order: start-first`), keeping at least two instances available throughout. If the new container fails to start, Swarm automatically rolls back (`failure_action: rollback`). Silent failures (where the container starts but behaves incorrectly) are not caught automatically; the CI/CD test suite is the primary guard here.

**Known limits:** The database is a single point of failure with no replication or automated backups. Traefik runs as a single replica, so if its host node fails, ingress is lost until Swarm reschedules it. The app containers have no health checks beyond TCP port availability, so a broken-but-running instance will continue receiving traffic.
