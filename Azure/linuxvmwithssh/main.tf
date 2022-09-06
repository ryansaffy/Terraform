terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.2"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "mtc-rg3" {
  name     = "mtc-redources3"
  location = "East Us"
  tags = {
    environment = "dev3"
  }
}

resource "azurerm_virtual_network" "mtc-vn3" {
  name                = "mtc-network3"
  resource_group_name = azurerm_resource_group.mtc-rg3.name
  location            = azurerm_resource_group.mtc-rg3.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev3"
  }
}

resource "azurerm_subnet" "mtc-subnet3" {
  name                 = "mtc-subnet3"
  resource_group_name  = azurerm_resource_group.mtc-rg3.name
  virtual_network_name = azurerm_virtual_network.mtc-vn3.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "mtc-sg3" {
  name                = "mtcsg3"
  location            = azurerm_resource_group.mtc-rg3.location
  resource_group_name = azurerm_resource_group.mtc-rg3.name

  tags = {
    environment = "dev3"
  }
}

resource "azurerm_network_security_rule" "mtc-dev-rule3" {
  name                        = "mtc-dev-rule3"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc-rg3.name
  network_security_group_name = azurerm_network_security_group.mtc-sg3.name
}

resource "azurerm_subnet_network_security_group_association" "mtc-sga3" {
  subnet_id                 = azurerm_subnet.mtc-subnet3.id
  network_security_group_id = azurerm_network_security_group.mtc-sg3.id
}

resource "azurerm_public_ip" "mtc-ip3" {
  name                = "mtc-ip3"
  resource_group_name = azurerm_resource_group.mtc-rg3.name
  location            = azurerm_resource_group.mtc-rg3.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev3"
  }
}

resource "azurerm_network_interface" "mtc-nic" {
  name                = "mtc-nic"
  location            = azurerm_resource_group.mtc-rg3.location
  resource_group_name = azurerm_resource_group.mtc-rg3.name


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnet3.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mtc-ip3.id
  }
  tags = {
    environment = "dev3"
  }
}

resource "azurerm_linux_virtual_machine" "mtc-vm" {
  name                  = "mtc-vm"
  resource_group_name   = azurerm_resource_group.mtc-rg3.name
  location              = azurerm_resource_group.mtc-rg3.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.mtc-nic.id]

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

provisioner "local-exec" {
  command = templatefile("${var.host_os}-ssh-script.tpl", {
    hostname = self.public_ip_address,
    user = "adminuser",
    identityfile = "~/.ssh/mtcazurekey"
  })
  interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
}

  tags = {
    environment = "dev3"
  }
}

data "azurerm_public_ip" "mtc-ip-data" {
  name = azurerm_public_ip.mtc-ip3.name
  resource_group_name = azurerm_resource_group.mtc-rg3.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.mtc-vm.name}: ${data.azurerm_public_ip.mtc-ip-data.ip_address}"
}