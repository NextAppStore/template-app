############################
# Plattform-injizierte Variablen (nicht im Wizard sichtbar)
############################

variable "users" {
  description = "Per-team roster — vom Worker injiziert. @platform:internal"
  type = map(list(object({
    email = string
  })))
  default = {}
}

variable "assignment_files" {
  description = "Hochgeladene Begleitmaterialien @openstack:file:all:pdf|docx"
  type = map(object({
    name         = string
    content_b64  = string
    size         = number
    content_type = string
  }))
  default = {}
}

############################
# Wizard-Variablen (vom Deployer im AppStore konfiguriert)
############################

variable "image_name" {
  description = "Glance-Image-Name — vom Worker zur Apply-Zeit gesetzt. @platform:internal"
  type        = string
  default     = "my-app-vX"
}

variable "network_uuid" {
  description = "UUID des internen Netzwerks @openstack:network:id"
  type        = string
  # DHBWV6: dual-stack (v4+v6 auf demselben Subnetz-Paar) — jede VM
  # bekommt automatisch beide Fixed-IPs von Neutron.
  default = "9b579624-d844-4df3-b38d-89978b31d37d"
}

variable "floating_ip_pool" {
  description = "Name des External Networks fuer Floating IPs @openstack:floating_ip_pool:name"
  type        = string
  default     = "DHBW"
}

variable "shared_secgroup_id" {
  description = "ID der gemeinsamen Security Group @openstack:security_group:id"
  type        = string
  default     = "4ffaf007-df66-4250-9118-1bd99378d34a"
}
