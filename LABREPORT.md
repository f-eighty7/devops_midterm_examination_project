**Documentation: Setup Gitea in Azure with some nice DevOps tools!**
---
- Gitea: https://ahin1.chas.dsnw.dev 
- Github repo:https://github.com/f-eighty7/devops_midterm_examination_project/
---

**1. Create Dockerfile and app.ini:**

**Dockerfile:**
```Dockerfile
FROM ubuntu:20.04

RUN apt-get update && \
    apt-get install -y wget git sqlite3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O /usr/local/bin/gitea https://dl.gitea.io/gitea/1.22/gitea-1.22-linux-amd64 && \
    chmod +x /usr/local/bin/gitea

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
# Skip setup page
INSTALL_LOCK = true
```
---

**2. Create Docker image and push to Repository with Github Actions:**

Create a `.github/workflows` folder in the root directory and put the workflow files in there.

Before utilizing this GitHub Actions Workflow, put the following secrets in the GitHub repository settings:
  - `DOCKER_TOKEN`: This token with write and read persmission, created with your GitHub account's personal access token, is required for pushing the image to Github Docker registry.
  - `ARM_CLIENT_ID`: Provided by the Azure subscription.
  - `CLIENT_SECRET`: Provided by the Azure subscription.
  - `ARM_SUBSCRIPTION_ID`: Provided by the Azure subscription.
  - `ARM_TENANT_ID`: Provided by the Azure subscription.
  - Additionally, generate an SSH key pair and place the public key and name it `SSH_PUBLIC_KEY` within the repository secret settings.

**docker-image.yaml:**
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

**3. Configuring Remote Backend:**

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

---

**4. Create an VM and pull the Gitea Docker image with cloud-config (plus Nginx configuration and SSL Certification with Certbot)**

After successfully deploying Terraform, Gitea can be accessed via the URL `ahin1.chas.dsnw.dev`. Note that you may need to update the DNS name as it is currently in use and also point it to the newly created host IP.

**main.tf**
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
---

**5. Create Deployment Workflow(that is activated by Build and Push Docker Image Runner or manually):**

Before utilizing the GitHub Actions Workflow, put the following secrets are in the GitHub repository settings:
- `ARM_CLIENT_ID`: Provided by the Azure subscription.
- `CLIENT_SECRET`: Provided by the Azure subscription.
- `ARM_SUBSCRIPTION_ID`: Provided by the Azure subscription.
- `ARM_TENANT_ID`: Provided by the Azure subscription.
- `TF_API_TOKEN`: This token, generated as a Terraform API token, is necessary for backend configuration.

To generate a Terraform API token (TF_API_TOKEN), you'll need to create an API token from Terraform Cloud.

1. **Log in to Terraform Cloud**:
   - Go to [Terraform Cloud](https://app.terraform.io/) and log in with your credentials.

2. **Navigate to User Settings**:
   - Click on your profile avatar and select "User Settings" from the dropdown menu.

3. **Generate a New API Token**:
   - In the "User Settings" page, find the "Tokens" section.
   - Click on "Create an API token".
   - Name it "Github Actions".
   - Click the "Create API Token" button.

4. **Copy the Token**:
   - After creation, the token will be displayed only once. Copy it and store it in Github repository secrets, as you won't be able to view it again.

**deploy.yaml**
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