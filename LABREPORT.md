## Documentation: Setup Gitea in Azure with some nice DevOps tools!

### Steps:

#### 1. Set Up Terraform Remote Backend:
Ensure Terraform uses a remote backend to store its state file securely. This allows for collaboration and state management across multiple environments.

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "ak-gitea"

    workspaces {
      name = "gitea"
    }
  }
}
```

#### 2. Define Azure Resources with Terraform:
Use Terraform to define Azure resources required for the Gitea deployment, including a resource group, virtual network, subnet, public IP, network interface, security group, and the Linux virtual machine itself.

```hcl
# Define Azure resources with Terraform
# See the Terraform configuration provided in the conversation
```

#### 3. Configure Custom Data for VM Initialization:
Customize the initialization process of the VM using cloud-init. This includes installing Docker, Nginx, Certbot, and configuring them, as well as running the Gitea Docker container.

```hcl
# Custom data for VM initialization
# See the Terraform configuration provided in the conversation
```

#### 4. Apply Terraform Configuration:
Apply the Terraform configuration to create the Azure resources and provision the VM.

```bash
terraform init
terraform plan
terraform apply
```

#### 5. Access Gitea:
Once the Terraform deployment is complete, access Gitea via the public IP or domain name configured. The domain name should point to the public IP of the VM.

```plaintext
http://<public_ip_or_domain_name>
```

#### 6. Set Up SSL/TLS Certificate:
Automatically obtain and configure SSL/TLS certificate using Certbot and Nginx.

```bash
certbot --nginx --non-interactive --agree-tos -d <your_domain_name> -m <your_email_address>
```

### Conclusion:
You have successfully deployed a Gitea instance on an Azure VM using Terraform. The Gitea instance is accessible via the provided public IP or domain name, with SSL/TLS encryption enabled.

---