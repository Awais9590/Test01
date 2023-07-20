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
  features {
     subscription_id = "e2281e72-9c41-4ddd-9d57-fd5adc915686"
     client_id       = "f548d2b4-7d58-47a5-91b2-97c0d3d1db15"
     client_secret   = ""
     tenant_id       = "f548d2b4-7d58-47a5-91b2-97c0d3d1db15"
}
resource "azurerm_resource_group" "sqlvm" {
  name     = "sqlvm"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnetsql" {
  name                = "vnetforsql"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.sqlvm.location
  resource_group_name = azurerm_resource_group.sqlvm.name
}

resource "azurerm_subnet" "subnetsql" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.sqlvm.name
  virtual_network_name = azurerm_virtual_network.vnetsql.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "ip1" {
  name                = "PublicIP1"
  location            = azurerm_resource_group.sqlvm.location
  resource_group_name = azurerm_resource_group.sqlvm.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "sqlvm"
  }
}

resource "azurerm_network_security_group" "sqlnsg" {
  name                = "NSG-SQL"
  location            = azurerm_resource_group.sqlvm.location
  resource_group_name = azurerm_resource_group.sqlvm.name

  security_rule {
    name                       = "TCPIN"
    priority                   = "100"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsgnic" {
  subnet_id                 = azurerm_subnet.subnetsql.id
  network_security_group_id = azurerm_network_security_group.sqlnsg.id
}

//-------------------------------------------------------------------------------

resource "azurerm_network_interface" "sqlnic" {
  name                = "SQL-NIC"
  location            = azurerm_resource_group.sqlvm.location
  resource_group_name = azurerm_resource_group.sqlvm.name

  ip_configuration {
    name                          = "config1"
    subnet_id                     = azurerm_subnet.subnetsql.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip1.id
  }
}

resource "azurerm_virtual_machine" "vm1" {
  name                  = "VM-SQL"
  location              = azurerm_resource_group.sqlvm.location
  resource_group_name   = azurerm_resource_group.sqlvm.name
  network_interface_ids = ["${azurerm_network_interface.sqlnic.id}"]
  vm_size               = "Standard_D4s_v3"

  storage_image_reference {
    offer     = "SQL2016SP1-WS2016"
    publisher = "MicrosoftSQLServer"
    sku       = "SQLDEV"
    version   = "latest"
  }

  #   boot_diagnostics {
  #     enabled     = true
  #     storage_uri = "https://www.google.com"
  #   }

  storage_os_disk {
    name              = "sqlnewOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  #   storage_data_disk {
  #     name              = "sqlvm_disk_1"
  #     managed_disk_type = "Standard_LRS"
  #     create_option     = "Empty"
  #     lun               = 0
  #     disk_size_gb      = "128"
  #   }

  os_profile {
    computer_name  = "sqlxvm"
    admin_username = "adminuser"
    admin_password = "Pass1234@"
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }
}

resource "azurerm_managed_disk" "sqlvmdisk1" {
  name                 = "sqlvm-disk1"
  location             = azurerm_resource_group.sqlvm.location
  resource_group_name  = azurerm_resource_group.sqlvm.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
}

resource "azurerm_virtual_machine_data_disk_attachment" "diskattach" {
  managed_disk_id    = azurerm_managed_disk.sqlvmdisk1.id
  virtual_machine_id = azurerm_virtual_machine.vm1.id
  lun                = 1
  caching            = "ReadWrite"
}

resource "azurerm_managed_disk" "sqlvmdisk2" {
  name                 = "sqlvm-disk2"
  location             = azurerm_resource_group.sqlvm.location
  resource_group_name  = azurerm_resource_group.sqlvm.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
}

resource "azurerm_virtual_machine_data_disk_attachment" "diskattach2" {
  managed_disk_id    = azurerm_managed_disk.sqlvmdisk2.id
  virtual_machine_id = azurerm_virtual_machine.vm1.id
  lun                = 0
  caching            = "ReadWrite"
}

//// sql machine configuration below 

resource "azurerm_mssql_virtual_machine" "sqlextension" {
  virtual_machine_id               = azurerm_virtual_machine.vm1.id
  sql_license_type                 = "PAYG"
  r_services_enabled               = true
  sql_connectivity_port            = 1433
  sql_connectivity_type            = "PRIVATE"
  sql_connectivity_update_password = "Password1234!"
  sql_connectivity_update_username = "sqllogin"

  auto_patching {
    day_of_week                            = "Sunday"
    maintenance_window_duration_in_minutes = 60
    maintenance_window_starting_hour       = 2
  }

  storage_configuration {
    disk_type             = "NEW"
    storage_workload_type = "GENERAL"

    data_settings {
      default_file_path = "F:\\data"
      luns              = [0]
    }

    log_settings {
      default_file_path = "G:\\log"
      luns              = [1]
    }

    temp_db_settings {
      default_file_path = "G:\\temp"
      luns              = [1]
    }
  }
}



