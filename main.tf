terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "mtc-rg" {
  name     = var.resource_group_name
  location = "East US"
  tags = {
    enviroment = "dev"
  }
}

resource "azurerm_virtual_network" "mtc-vn" {
  name                = var.test_virtual_network
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  address_space       = ["10.123.0.0/16"]
  tags = {
    enviroment = "dev"
  }
}

resource "azurerm_subnet" "test" {
  count = length(var.subnet_names)
  name  = var.user_names[count.index]
}

# resource "azurerm_subnet" "mtc-subnetLinux" {
#   name                 = var.subnet_name
#   resource_group_name  = azurerm_resource_group.mtc-rg.name
#   virtual_network_name = azurerm_virtual_network.mtc-vn.name
#   address_prefixes     = ["10.123.1.0/24"]
# }

# resource "azurerm_subnet" "mtc-subnetWin" {
#   name                 = "mtc-subnetWin"
#   resource_group_name  = azurerm_resource_group.mtc-rg.name
#   virtual_network_name = azurerm_virtual_network.mtc-vn.name
#   address_prefixes     = ["10.123.2.0/24"]
# }

# resource "azurerm_subnet" "mtc-subnetBastion" {
#   name                 = "AzureBastionSubnet"
#   resource_group_name  = azurerm_resource_group.mtc-rg.name
#   virtual_network_name = azurerm_virtual_network.mtc-vn.name
#   address_prefixes     = ["10.123.3.0/24"]
# }

resource "azurerm_network_security_group" "mtc-sg" {
  name                = "mtc-sg"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name
  tags = {
    enviroment = "dev"
  }
}

resource "azurerm_network_security_rule" "mtc-dev-rule" {
  name                        = "test123"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc-rg.name
  network_security_group_name = azurerm_network_security_group.mtc-sg.name
}

resource "azurerm_subnet_network_security_group_association" "mtc-sga" {
  subnet_id                 = azurerm_subnet.mtc-subnetLinux.id
  network_security_group_id = azurerm_network_security_group.mtc-sg.id
}

resource "azurerm_subnet_network_security_group_association" "mtc-sgb" {
  subnet_id                 = azurerm_subnet.mtc-subnetWin.id
  network_security_group_id = azurerm_network_security_group.mtc-sg.id
}

resource "azurerm_public_ip" "mtc-ip" {
  name                = "mtc-ip"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  allocation_method   = "Static"
  sku                 = "Standard"


  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "mtc-nic" {
  name                = "mtc-nic"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnetLinux.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "mtc-nic2" {
  name                = "mtc-nic2"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnetWin.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "mtc-nic3" {
  name                = "mtc-nic3"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnetWin.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.mtc-ip.id
  }
  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "mtc-vm" {
  name                = "mtc-vm"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.mtc-nic.id,
  ]

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
    version   = "latest"
  }
}



resource "azurerm_windows_virtual_machine" "mtc-vm2" {
  name                = "mtc-vm2"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser2"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.mtc-nic2.id,
  ]


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer     = "sql2019-ws2019"
    publisher = "MicrosoftSQLServer"
    sku       = "standard"
    version   = "15.0.230110"
  }
}

resource "azurerm_bastion_host" "mtc-bastion" {
  name                = "mtc-bastion"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.mtc-subnetBastion.id
    public_ip_address_id = azurerm_public_ip.mtc-ip.id
  }
}