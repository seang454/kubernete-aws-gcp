variable "enabled" {
  description = "Whether the GCP disk resizer is enabled."
  type        = bool
  default     = true
}

variable "project_id" {
  description = "GCP Project ID. If left empty, the active gcloud configured project is used."
  type        = string
  default     = ""
}

variable "disks" {
  description = "Map of GCP disks to check and resize online."
  type = map(object({
    disk_name      = string
    zone           = string
    target_size_gb = number
  }))
  default = {}
}

variable "auto_expand_filesystem" {
  description = "Whether to automatically run the Ansible disk expansion playbook after GCP disks are resized."
  type        = bool
  default     = false
}

variable "ansible_inventory_path" {
  description = "Path to the Ansible inventory file (used when auto_expand_filesystem is true)."
  type        = string
  default     = ""
}

variable "ansible_playbook_path" {
  description = "Path to the Ansible expand-disk.yml playbook (used when auto_expand_filesystem is true)."
  type        = string
  default     = ""
}
