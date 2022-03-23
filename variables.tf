variable "prefix" {
  type    = string
  default = "gitlab"
}

variable "resource_group_name" {
  type    = string
  default = "1-d5e44853-playground-sandbox" # mutable, see resource json
}

variable "location" {
  type    = string
  default = "southcentralus"                # mutable, see resource json
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "admin_password" {
  type    = string
  default = "Password1234!"
}