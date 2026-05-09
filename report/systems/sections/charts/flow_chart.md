```mermaid

sequenceDiagram
%% Define participants
    participant Terraform
    participant DigitalOcean
    participant .ini
    participant .env
    participant Ansible
    participant VirtualMachines

%% Trigger Init/Apply
    Note left of Terraform: Terraform Init Apply
    activate Terraform

%% Terraform creates infrastructure on Digital Ocean
    Terraform->>DigitalOcean: Create Virtual Machines
    Terraform->>DigitalOcean: Create Firewalls

%% Terraform writes local files
    Terraform->>.ini: Generate Ansible Inventory file
    Terraform->>.env: Generate Env File

%% Terraform triggers Ansible Playbook
    Terraform->>Ansible: Run Ansible Playbook
    deactivate Terraform

%% Ansible sets up the VMs
    activate Ansible
    Ansible->>.ini: Read Inventory file
    Ansible->>VirtualMachines: Setup Docker Swarm Cluster
    Ansible->>.env: Read Environment Variables
    Ansible->>VirtualMachines: Run Docker Compose DB And Stack Yaml
    deactivate Ansible
```