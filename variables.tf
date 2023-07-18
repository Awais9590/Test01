variable "resource_group_name" {
  type    = string
  default = "test"
}

variable "virtual_network_name" {
  type    = string
  default = "test_virtual_network"
}


variable "subnet_names" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["subnetLinux", "subnetWin", "subnetBastion"]
}