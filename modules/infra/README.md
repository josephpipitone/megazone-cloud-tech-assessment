# Infrastructure Module

This module deploys a secure, multi-AZ VPC networking infrastructure including public subnets, private application subnets, and private database subnets. Subnet CIDRs are automatically calculated from the VPC CIDR using the `hashicorp/subnets/cidr` module based on `subnet_config`. Via `terraform.tfvars`, a user can customize the VPC CIDR, AZs, an allowlist for bastion, instance types, naming, etc.

## Resources Created

*   **VPC:** Core VPC with base CIDR.
*   **Public Subnets:** Internet-facing subnets across AZs with IGW.
*   **Private App Subnets:** Isolated subnets with NAT for outbound internet.
*   **Private Database Subnets:** Highly available, no direct internet access.
*   **Internet Gateway (IGW):** Enables public inbound for bastion.
*   **NAT Gateways & EIPs:** Per-AZ outbound for private subnets.
*   **Route Tables & Associations:** Public, private-app, private-database.
*   **Security Groups:** ALB (HTTP/HTTPS), App (from ALB/bastion), Database (from app), Bastion (SSH from IP).
*   **Network ACLs:** Stateless rules.
*   **Bastion Host (optional):** Amazon Linux EC2 in public subnet with auto-generated SSH keypair.
*   **SSH Key Pair:** TLS-generated for bastion and app server access.

## Input Variables

| Name                  | Description                                      | Type                                      | Default                  |
|-----------------------|--------------------------------------------------|-------------------------------------------|--------------------------|
| `vpc_cidr`            | CIDR block for the VPC                           | `string`                                  | `"10.0.0.0/20"`          |
| `azs`                 | Availability zones                               | `list(string)`                            | `["us-east-1a", "us-east-1b"]` |
| `region`              | AWS region                                       | `string`                                  | `"us-east-1"`            |
| `vpc_name`            | Name of the VPC                                  | `string`                                  | N/A                      |
| `environment`         | Deployment environment                           | `string`                                  | N/A                      |
| `bastion_allowed_ip`  | IP address allowed to SSH to bastion             | `string`                                  | `"74.44.134.129/32"`     |
| `create_bastion`      | Whether to create bastion host                   | `bool`                                    | `true`                   |
| `bastion_key_name`    | SSH key pair name for bastion                    | `string`                                  | `null`                   |
| `bastion_instance_type` | Instance type for bastion host                 | `string`                                  | `"t3.micro"`             |
| `ssh_keypair_name`    | Name of the SSH keypair                          | `string`                                  | `"mzc-ssh-keypair"`      |
| `name_prefix`         | Prefix for resource names                        | `string`                                  | `"mzcinfra"`             |
| `subnet_config`       | Subnet configurations: list of `{name, new_bits}`| `list(object({name=string, new_bits=number}))` | N/A                      |

**Note:** Example:
```hcl
`subnet_config = [
  {
    name     = "public-a"
    new_bits = 8
  },
  {
    name     = "public-b"
    new_bits = 8
  },
  {
    name     = "private-app-a"
    new_bits = 7
  },
  {
    name     = "private-app-b"
    new_bits = 7
  },
  {
    name     = "private-database-a"
    new_bits = 7
  },
  {
    name     = "private-database-b"
    new_bits = 7
  },
  {
    name     = null
    new_bits = 7
  },
  {
    name     = null
    new_bits = 7
  }
]
```

## Output Variables

*   `vpc_id`: ID of the VPC.
*   `public_subnet_ids`: List of public subnet IDs.
*   `private_app_subnet_ids`: List of private app subnet IDs.
*   `private_database_subnet_ids`: List of private database subnet IDs.
*   `igw_id`: ID of the Internet Gateway.
*   `nat_gw_id`: List of NAT Gateway IDs.
*   `bastion_sg_id`: ID of the bastion security group.
*   `app_sg_id`: ID of the app security group.
*   `data_sg_id`: ID of the database security group.
*   `alb_sg_id`: ID of the ALB security group.
*   `bastion_instance_id`: ID of the bastion instance (null if not created).
*   `bastion_public_ip`: Public IP of the bastion instance (null if not created).
*   `ssh_private_key`: PEM private key for SSH (sensitive).
*   `subnet_addrs_keys`: Keys from subnet address module.