# Megazone Cloud Tech Assessment

This repository contains the Infrastructure as Code (IaC) for the Megazone Cloud Tech Assessment. For both the C1 and C3 assignments, I structured the solution using Terraform modules — this is my standard way of working because it promotes reusability and keeps everything clean and maintainable. In a real production environment, these modules would live in a centralized module repo, allowing any team or project to source and reuse them consistently with a simple reference:

```hcl
 source = "http://fqdn/path-to-module/shared-modules//submodule-name?param=param"
```

## Project Structure

*   `modules/`: Reusable Terraform modules.
    *   `infra`: Multi-AZ core networking (VPC, Subnets, IGW/NAT Gateways, Security Groups & ACLs, Bastion).
    *   `appstack`: Application layer (ALB, ASG, RDS, EC2).
*   `infra-C1/`: Instantiation of the infrastructure layer (VPC, Networking).
*   `appstack-C3/`: Instantiation of the application layer (Web App, DB).

## Quick Start

The solution must be deployed in order due to dependencies (`appstack-c3` relies on `infra-c1`).

1.  **Deploy Infrastructure:**
    ```bash
    cd infra-C1
    terraform init
    terraform apply
    ```
    *Note: Obtain the `ssh_private_key` output to ssh to the bastion.*
    ```bash
    terraform output -raw ssh_private_key > mzc-ssh-keypair.pem
    chmod 400 "mzc-ssh-keypair.pem"
    ssh -i "mzc-ssh-keypair.pem" ec2-user@1.2.3.4
    ```

2.  **Deploy App Stack:**
    ```bash
    cd ../appstack-C3
    terraform init
    terraform apply
    ```

## Solution Overview

*   **VPC:** `10.0.0.0/20` base CIDR.
*   **Dynamic Subnetting:** Uses `hashicorp/subnets/cidr` to calculate ranges automatically.
*   **Compute:** Auto Scaling Group running Nginx on Amazon Linux.
*   **Database:** RDS PostgreSQL.
*   **Security:** Strict Security Groups.
