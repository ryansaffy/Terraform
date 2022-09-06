terraform {
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = "=3.0.2"
        }
    }
}

provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "tf-rg" {
    name = "tf-rg"
    location = "East Us"
    tags = {
        environment = "dev"
    }
}

resource "azurerm_virtual_network" "tf-vn" {
    name = "tf-network"
    resource_group_name = azurerm_resource_group.tf-rg.name
    location = azurerm_resource_group.tf-rg.location
    address_space = ["10.100.0.0/16"]

    tags = {
        environment = "dev"
    }
}

resource "azurerm_subnet" "tf-subnet" {
    name = "tf-subnet"
    resource_group_name = azurerm_resource_group.tf-rg.name
    virtual_network_name = azurerm_virtual_network.tf-vn.name
    address_prefixes = ["10.100.1.0/24"]
}

resource "azurerm_network_security_group" "tf-sg" {
    name = "tf-sg"
    location = azurerm_resource_group.tf-rg.location
    resource_group_name = azurerm_resource_group.tf-rg.name

    tags = {
        environment = "dev"
    }
}

resource "azurerm_network_security_rule" "tf-dev-rule" {
  name                        = "tf-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.tf-rg.name
  network_security_group_name = azurerm_network_security_group.tf-sg.name
}

resource "azurerm_subnet_network_security_group_association" "tf-sga" {
  subnet_id                 = azurerm_subnet.tf-subnet.id
  network_security_group_id = azurerm_network_security_group.tf-sg.id
}

resource "azurerm_public_ip" "tf-ip" {
  name                = "tf-ip"
  resource_group_name = azurerm_resource_group.tf-rg.name
  location            = azurerm_resource_group.tf-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "tf-nic" {
  name                = "tf-nic"
  location            = azurerm_resource_group.tf-rg.location
  resource_group_name = azurerm_resource_group.tf-rg.name


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tf-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tf-ip.id
  }
  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "tf-vm" {
  name                  = "tf-vm"
  resource_group_name   = azurerm_resource_group.tf-rg.name
  location              = azurerm_resource_group.tf-rg.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.tf-nic.id]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtcazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "Latest"
  }
#Make sure to put the identityfile as where your ssh key is located
provisioner "local-exec" {
  command = templatefile("${var.host_os}-ssh-script.tpl", {
    hostname = self.public_ip_address,
    user = "adminuser",
    identityfile = "~/.ssh/mtcazurekey"
  })
  interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
}

  tags = {
    environment = "dev"
  }
}

data "azurerm_public_ip" "tf-ip-data" {
  name = azurerm_public_ip.tf-ip.name
  resource_group_name = azurerm_resource_group.tf-rg.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.tf-vm.name}: ${data.azurerm_public_ip.tf-ip-data.ip_address}"
}