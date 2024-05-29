**Documentation: Setup Gitea in Azure with some nice DevOps tools!**
---
**1. Creating Dockerfile and app.ini:**

**Dockerfile:**
```Dockerfile
FROM ubuntu:20.04

RUN apt-get update && \
    apt-get install -y wget git sqlite3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O /usr/local/bin/gitea https://dl.gitea.io/gitea/1.22/gitea-1.22-linux-amd64 && \
    chmod +x /usr/local/bin/gitea

EXPOSE 3000
EXPOSE 22

RUN adduser \
    --system \
    --shell /bin/bash \
    --gecos 'Git Version Control' \
    --group \
    --disabled-password \
    --home /home/git \
    git

RUN mkdir -p /var/lib/gitea/{custom,data,log,repositories} && \
    chown -R git:git /var/lib/gitea/ && \
    chmod -R 750 /var/lib/gitea/ && \
    mkdir /etc/gitea && \
    chown root:git /etc/gitea && \
    chmod 770 /etc/gitea

RUN mkdir -p /usr/local/bin/data && \
    chown -R git:git /usr/local/bin/data && \
    chmod -R 750 /usr/local/bin/data

COPY app.ini /etc/gitea/app.ini

RUN chown git:git /etc/gitea/app.ini && chmod 660 /etc/gitea/app.ini

USER git

CMD ["gitea", "web", "-c", "/etc/gitea/app.ini"]
```

**app.ini:**
```ini
APP_NAME = Gitea: Git with a cup of tea
RUN_USER = git
RUN_MODE = prod

[database]
DB_TYPE = sqlite3
PATH = /var/lib/gitea/data/gitea.db

[repository]
ROOT = /var/lib/gitea/data/repositories

[server]
DOMAIN = localhost
HTTP_PORT = 3000
ROOT_URL = http://localhost:3000/
DISABLE_SSH = false
SSH_PORT = 22
START_SSH_SERVER = true
OFFLINE_MODE = false

[log]
MODE = console, file
LEVEL = Info
ROOT_PATH = /var/lib/gitea/log

[security]
INSTALL_LOCK = true
```
---
**2. **Creating Docker Image and Pushing to Repository:**

- Before utilizing the GitHub Actions Workflow, ensure the following secrets are configured in the GitHub repository settings:
  - `DOCKER_TOKEN`: This token with write and read persmission, created with your GitHub account's personal access token, is required for pushing the image to Github Docker registry.
  - `ARM_CLIENT_ID`: Provided by the Azure subscription.
  - `CLIENT_SECRET`: Provided by the Azure subscription.
  - `ARM_SUBSCRIPTION_ID`: Provided by the Azure subscription.
  - `ARM_TENANT_ID`: Provided by the Azure subscription.
- Additionally, generate an SSH key pair and place the public key and name it `SSH_PUBLIC_KEY` within the repository secret settings.

GitHub Actions Workflow:
```yaml
name: Build and Push Docker Image

on:
  workflow_dispatch:

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{github.actor}}
          password: ${{ secrets.DOCKER_TOKEN }}

      - name: Build and Push Docker image to Package Registry
        run: |
          REPO_NAME=$(echo ${{ github.repository }} | tr '[:upper:]' '[:lower:]')
          DOCKER_IMAGE=ghcr.io/$REPO_NAME/gitea:${{ github.sha }}
          docker build -t $DOCKER_IMAGE .
          docker tag $DOCKER_IMAGE ghcr.io/$REPO_NAME/gitea:latest
          docker push $DOCKER_IMAGE
          docker push ghcr.io/$REPO_NAME/gitea:latest

      - name: Trigger Deployment Workflow
        if: always()
        uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          repository: f-eighty7/devops_midterm_examination_project
          event-type: deploy-gitea
```
---

4. **Configuring Remote Backend:**
Before applying the Terraform configuration, a remote setup for the tfstate is needed. Follow these steps to configure the remote backend:

- **Access Terraform Cloud:**
   - Log in or create a Terraform Cloud account at [app.terraform.io](https://app.terraform.io).

- **Create an Organization:**
   - Create an organization called "ak-gitea".

- **Create a Workspace:**
   - Inside the organization, create a new workspace and pick "API-Driven Workflow". Then name it "gitea".

- **Choose Execution Mode:**
   - After creating the workspace, navigate to its settings.
   - In the workspace settings, locate the "Execution Mode" section.
   - Choose "Local" as the execution mode.
   - Save the settings to apply the changes.

By selecting the "Local" execution mode, Terraform operations will be executed on github runners machine.

**3. Create an VM and pull the Gitea Docker image with cloud-config(plus Nginx configuration and SSL Certification with Certbot)**

After a successful Terraform deployment, Gitea can be accessed via the URL ahin1.chas.dsnw.dev. Ensure that the DNS is correctly configured to point to the public IP address of the deployed Azure VM.

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

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "gitea_rg" {
  name     = "gitea-resource"
  location = "West Europe"
}

resource "azurerm_virtual_network" "gitea_vnet" {
  name                = "gitea-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.gitea_rg.location
  resource_group_name = azurerm_resource_group.gitea_rg.name
}

resource "azurerm_subnet" "gitea_subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.gitea_rg.name
  virtual_network_name = azurerm_virtual_network.gitea_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "gitea_pip" {
  name                = "gitea-public-ip"
  location            = azurerm_resource_group.gitea_rg.location
  resource_group_name = azurerm_resource_group.gitea_rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "gitea_nic" {
  name                = "gitea-nic"
  location            = azurerm_resource_group.gitea_rg.location
  resource_group_name = azurerm_resource_group.gitea_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.gitea_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.gitea_pip.id
  }
}

resource "azurerm_network_security_group" "gitea_sg" {
  name                = "gitea-sg"
  location            = azurerm_resource_group.gitea_rg.location
  resource_group_name = azurerm_resource_group.gitea_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Gitea"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"

  }
}

resource "azurerm_linux_virtual_machine" "gitea_vm" {
  name                = "gitea-vm"
  resource_group_name = azurerm_resource_group.gitea_rg.name
  location            = azurerm_resource_group.gitea_rg.location
  size                = "Standard_B1s"
  admin_username      = "ak"
  network_interface_ids = [
    azurerm_network_interface.gitea_nic.id,
  ]

  admin_ssh_key {
    username   = "ak"
    public_key = file("~/.ssh/gitea.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(<<EOF
#cloud-config
package_update: true
package_upgrade: true
packages:
  - docker.io
  - nginx
  - certbot
  - python3-certbot-nginx

runcmd:
  - systemctl start docker
  - systemctl enable docker
  - docker volume create gitea_data
  - docker run -d --name gitea -p 3000:3000 -p 222:22 -v gitea_data:/data --restart always ghcr.io/f-eighty7/devops_midterm_examination_project/gitea:latest


  - echo "server {
        listen 80;
        server_name ahin1.chas.dsnw.dev;

        location / {
            proxy_pass http://localhost:3000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }" > /etc/nginx/sites-available/gitea

  - ln -s /etc/nginx/sites-available/gitea /etc/nginx/sites-enabled/
  - systemctl restart nginx

  - certbot --nginx --non-interactive --agree-tos -d ahin1.chas.dsnw.dev -m ahin.khan1@gmail.com
EOF
  )
}
```

**4. Creating Deployment Workflow(that is activated by Build and Push Docker Image Runner):**

On the `deploy-gitea` repository dispatch event workflow, ensure the following secrets are configured in the GitHub repository settings:

- `ARM_CLIENT_ID`: Provided by the Azure subscription.
- `CLIENT_SECRET`: Provided by the Azure subscription.
- `ARM_SUBSCRIPTION_ID`: Provided by the Azure subscription.
- `ARM_TENANT_ID`: Provided by the Azure subscription.
- `TF_API_TOKEN`: This token, generated as a Terraform API token, is necessary for backend configuration.

To generate the Terraform API token, you can use the `terraform login` command, authenticate with Terraform Cloud, and then generate an API token. This token should be stored in the GitHub repository secrets.

```yaml
name: Deploy Gitea

on:
  repository_dispatch:
    types: [deploy-gitea]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Azure Login
        run: |
          export ARM_CLIENT_ID="${{ secrets.ARM_CLIENT_ID }}"
          export ARM_CLIENT_SECRET="${{ secrets.CLIENT_SECRET }}"
          export ARM_SUBSCRIPTION_ID="${{ secrets.ARM_SUBSCRIPTION_ID }}"
          export ARM_TENANT_ID="${{ secrets.ARM_TENANT_ID }}"
          az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
          
      - name: Create SSH directory if not exists
        run: mkdir -p $HOME/.ssh

      - name: Set up SSH key
        run: |
          echo "${{ secrets.SSH_PUBLIC_KEY }}" > $HOME/.ssh/gitea.pub
        shell: bash
    
      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init -backend-config="token=${{ secrets.TF_API_TOKEN }}"
        working-directory: terraform

      - name: Terraform Apply
        env:
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_CLIENT_SECRET: ${{ secrets.CLIENT_SECRET }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
        run: terraform apply -auto-approve
        working-directory: terraform
```
---

**Conclusion**

I've established a Docker image housing the Gitea application binary and automated the deployment process using Terraform for infrastructure provisioning and Cloud-init for configuration. Additionally, I've implemented a workflow to automatically deploy the Terraform infrastructure, streamlining the deployment of Gitea in Azure (Ofcourse you can just apply terraform locally and have everything setup.) With this setup, it's possible to reboot the VM and retain access to Gitea without any manual intervention. The automated deployment process ensures that the necessary configurations persist even after a reboot, allowing users to seamlessly log in and access Gitea without interruption.