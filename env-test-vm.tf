variable "credential" {
  type = "map"
}

variable "name_group" {
  description = "name group asociated to  virtual machine"
}

variable "location" {
  description = "region where the resources should exist"
  default     = "eastus"
}

variable "vm_size" {
  description = "size of the vm to create"
}

variable "vnet_address_space" {
  description = "full address space allowed to the virtual network"
  default     = "10.0.0.0/16"
}

variable "subnet_address_space" {
  description = "the subset of the virtual network for this subnet"
  default     = "10.0.10.0/24"
}

variable "image_publisher" {
  description = "name of the publisher of the image (az vm image list)"
  default     = "MicrosoftWindowsServer"
}

variable "image_offer" {
  description = "the name of the offer (az vm image list)"
  default     = "WindowsServer"
}

variable "image_sku" {
  description = "image sku to apply (az vm image list)"
  default     = "2012-R2-Datacenter"
}

variable "image_version" {
  description = "version of the image to apply (az vm image list)"
  default     = "latest"
}

variable "ip_manager"{
  description ="ip allowed to rdp"
}

variable "bpm_vhd"{
  description ="storage uri of bpm vhd"
}


variable "sql_vhd"{
  description ="storage uri of sql vhd"
}

provider "azurerm" {
  subscription_id = "${var.credential["subscription_id"]}"
  client_id       = "${var.credential["client_id"]}"
  client_secret   = "${var.credential["client_secret"]}"
  tenant_id       = "${var.credential["tenant_id"]}"
}

resource "azurerm_resource_group" "test" {
  name     = "${var.name_group}"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.name_group}-vnet"
  location            = "${var.location}"
  address_space       = ["${var.vnet_address_space}"]
  resource_group_name = "${var.name_group}"
  depends_on          = ["azurerm_resource_group.test"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.name_group}-nsg"
  location            = "${var.location}"
  resource_group_name = "${var.name_group}"
  depends_on          = ["azurerm_resource_group.test"]
}

resource "azurerm_network_security_rule" "rdp" {
  name                        = "default-allow-rdp"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "TCP"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "${var.ip_manager}"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.test.name}"
  network_security_group_name = "${azurerm_network_security_group.nsg.name}"
}

resource "azurerm_subnet" "subnet" {
  name                      = "${var.name_group}subnet"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  resource_group_name       = "${var.name_group}"
  address_prefix            = "${var.subnet_address_space}"
  network_security_group_id = "${azurerm_network_security_group.nsg.id}"

  depends_on = ["azurerm_network_security_group.nsg"]
}

resource "azurerm_network_interface" "nicbpm" {
  name                      = "${var.name_group}bpmnic"
  location                  = "${var.location}"
  resource_group_name       = "${var.name_group}"
  network_security_group_id = "${azurerm_network_security_group.nsg.id}"

  ip_configuration {
    name                          = "${var.name_group}ipbpmconfig"
    subnet_id                     = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.pipbpm.id}"
  }

  depends_on = ["azurerm_network_security_group.nsg"]
}

resource "azurerm_public_ip" "pipbpm" {
  name                         = "${var.name_group}bpm-ip"
  location                     = "${var.location}"
  resource_group_name          = "${var.name_group}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${var.name_group}-bpm-1"
  depends_on                   = ["azurerm_resource_group.test"]
}

resource "azurerm_image" "image-bpm" {
  name                = "accimagebpm"
  location            = "eastus"
  resource_group_name = "${var.name_group}"

  os_disk {
    os_type  = "Windows"
    os_state = "Generalized"
    blob_uri = "${var.bpm_vhd}"
  }

  depends_on = ["azurerm_resource_group.test"]
}

resource "azurerm_managed_disk" "diskbpm" {
  name                 = "datadisk_existingbpm"
  location             = "${azurerm_resource_group.test.location}"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
  depends_on           = ["azurerm_resource_group.test"]
}

resource "azurerm_virtual_machine" "vm-bpm" {
  name                = "${var.name_group}-bpm-1"
  location            = "${var.location}"
  resource_group_name = "${var.name_group}"
  vm_size             = "${var.vm_size}"

  delete_os_disk_on_termination    = false
  delete_data_disks_on_termination = false
  network_interface_ids            = ["${azurerm_network_interface.nicbpm.id}"]

  storage_image_reference {
    id = "${azurerm_image.image-bpm.id}"
  }

  storage_os_disk {
    name              = "${var.name_group}bpmosdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  
  os_profile {
    computer_name  = "${var.name_group}-bpm-1"
    admin_username = "${var.name_group}"
    admin_password = "${var.name_group}bpm1Psw"
  }

  os_profile_windows_config = {}
  depends_on                = ["azurerm_managed_disk.diskbpm"]
}

resource "azurerm_network_interface" "nicsql" {
  name                      = "${var.name_group}sqlnic"
  location                  = "${var.location}"
  resource_group_name       = "${var.name_group}"
  network_security_group_id = "${azurerm_network_security_group.nsg.id}"

  ip_configuration {
    name                          = "${var.name_group}ipsqlconfig"
    subnet_id                     = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.pipsql.id}"
  }

  depends_on = ["azurerm_network_security_group.nsg"]
}

resource "azurerm_public_ip" "pipsql" {
  name                         = "${var.name_group}sql-ip"
  location                     = "${var.location}"
  resource_group_name          = "${var.name_group}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${var.name_group}-sql-1"
  depends_on                   = ["azurerm_resource_group.test"]
}

resource "azurerm_image" "image-sql" {
  name                = "accimagesql"
  location            = "eastus"
  resource_group_name = "${var.name_group}"

  os_disk {
    os_type  = "Windows"
    os_state = "Generalized"
    blob_uri = "${var.sql_vhd}"
  }

  depends_on = ["azurerm_resource_group.test"]
}

resource "azurerm_managed_disk" "disksql" {
  name                 = "datadisk_existingsql"
  location             = "${azurerm_resource_group.test.location}"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
  depends_on           = ["azurerm_resource_group.test"]
}

resource "azurerm_virtual_machine" "vm-sql" {
  name                = "${var.name_group}-sql-1"
  location            = "${var.location}"
  resource_group_name = "${var.name_group}"
  vm_size             = "${var.vm_size}"

  network_interface_ids = ["${azurerm_network_interface.nicsql.id}"]

  storage_image_reference {
    id = "${azurerm_image.image-sql.id}"
  }

  storage_os_disk {
    name              = "${var.name_group}sqlosdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.name_group}-sql-1"
    admin_username = "${var.name_group}"
    admin_password = "${var.name_group}sql1Psw"
  }
  os_profile_windows_config = {}
  depends_on                = ["azurerm_managed_disk.disksql"]
}
