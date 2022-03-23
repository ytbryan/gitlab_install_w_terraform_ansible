## Install GitLab on Microsoft Azure, with pre-set configuration
## https://docs.gitlab.com/ee/install/azure/#deploy-and-configure-gitlab
## https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine

# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
  skip_provider_registration = true
}


## modify from the following resource template -------------------------------------------------
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine

resource "azurerm_virtual_network" "main" { # address range, 10.0.0.0 - 10.0.255.255
  name                = "${var.prefix}-virnet"
  address_space       = ["10.0.0.0/16"] # checked against manual deployment in Azure portal
  location            = var.location
  resource_group_name = var.resource_group_name

  timeouts {
    create = "60s"
  }
}

resource "azurerm_subnet" "internal" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  # address_prefixes     = ["10.0.2.0/24"]             
  address_prefixes = ["10.0.0.0/24"] # checked against manual deployment in Azure portal
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.prefix}-ipConfig"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface#public_ip_address_id
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_B2s" # mutable, see resource json

  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine#zones
  zones = [1] # set zone to '1' as per instruction from 'Install GitLab on Microsoft Azure'

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine#plan
  plan {                                 # this 'plan' block supports image from the marketplace 
    publisher = "gitlabinc1586447921813" # mutable, see resource json
    product   = "gitlabee"               # mutable, see resource json
    name      = "default"                # mutable, see resource json
  }
  storage_image_reference {
    publisher = "gitlabinc1586447921813" # mutable, see resource json
    offer     = "gitlabee"               # mutable, see resource json
    sku       = "default"                # mutable, see resource json
    version   = "latest"                 # mutable, see resource json
  }
  storage_os_disk {
    name              = "${var.prefix}-storage_os_disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS" # mutable, see resource json
    os_type           = "Linux"       # added by me
  }
  os_profile {
    computer_name  = "${var.prefix}-vm" # mutable, see resource json
    admin_username = var.admin_username
    admin_password = var.admin_password
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}
## end of resource template  ------------------------------------------

# Configure network tab -----------------------------------------------
# https://docs.gitlab.com/ee/install/azure/#configure-the-networking-tab
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group
#       setting --> networking; for priorities, port etc
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # To obtain rules from manual deployment of resources as per 'Install GitLab on Microsoft Azure' 
  # Azure Portal --> setting --> networking
  security_rule {
    name                       = "http"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "https"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ssh"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  timeouts {
    create = "60s"
  }
}

## set up Public IP address -------------------------------------------------------------

# for public IP address, fully qualified domain name
# https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string
resource "random_string" "fqdn" {
  length  = 5
  special = false
  upper   = false
  number  = false
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-publicip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"

  # to set up define sku when configuring availability zone
  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip#availability_zone
  availability_zone = 1          # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip#availability_zone
  sku               = "Standard" # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip#sku

  domain_name_label = random_string.fqdn.result

  timeouts {
    create = "60s"
  }
}

# to govern subnet with nsg
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.main.id
}
