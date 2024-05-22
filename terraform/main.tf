terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  #backend "remote" {
  # hostname     = "app.terraform.io"
  #organization = "ak-gitea"

  #workspaces {
  #name = "gitea"
  #}
  #}
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
  allocation_method   = "Dynamic"
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

runcmd:
  - systemctl start docker
  - systemctl enable docker
  - docker pull ghcr.io/f-eighty7/devops_midterm_examination_project/gitea:latest
  - docker run -d --name gitea -p 3000:3000 -p 222:22 ghcr.io/f-eighty7/devops_midterm_examination_project/gitea:latest
EOF
)
}