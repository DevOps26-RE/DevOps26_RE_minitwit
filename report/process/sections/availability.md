## Availability and scaling

Currently our Minitwit service runs on a 3-node Docker Swarm in DigitalOcean. Two manager nodes run 3 replicas of the Minitwit app, while the third node runs the database and our monitoring system.

We only have vertical scaling as an option for the database through upgrading the VM it is running on with more RAM and/or more CPU. The application can be scaled vertically like the database, and horizontally by deploying more instances of the application on one or more droplets. The configuration of how the system scales takes place in three systems:

1. **Terraform**
   - In Terraform the infrastructure of the system is defined in the form of "resources", which are the definitions of the VMs (Droplets) that are to be present. Each resource gets assigned a group in the Ansible inventory, such that Ansible knows the role of each machine at its disposal.

2. **Ansible**
   - Ansible runs the provisioning scripts when setting up a new VM. Based on the inventory and what group each resource is assigned to, Ansible will run the necessary commands to set up the VM such that it has the right resources (binaries, config files, etc.) and that it is assigned the correct role in the Docker network.

3. **Docker Swarm**
   - The swarm is defined in `docker-stack.yml`. Each service is constrained to only run on nodes that have a matching role assigned by Ansible during provisioning. The stack also defines the number of replicas that should be present, and Docker will then automatically make sure that the replicas are distributed among the nodes that are available with a matching role on the Docker network. If an instance crashes or goes down, Docker will automatically spin up another instance on one of the nodes.

When deploying a new version of the application, Docker Swarm performs a rolling update to keep the service available throughout the process. For each replica, the new container is started *before* the old one is stopped (`order: start-first`), meaning at least two healthy replicas remain available while each individual replica is being updated. If the new container fails to start, Docker automatically rolls back to the previous version (`failure_action: rollback`). This means a bad patch that causes the container to crash on startup is automatically reverted without manual intervention. However, if the new version starts successfully but behaves incorrectly (e.g. returns errors or has broken logic), no automatic rollback occurs — the CI/CD test suite is the primary guard against this scenario.
