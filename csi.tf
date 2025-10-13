# Create CSI role with required privileges
resource "proxmox_virtual_environment_role" "csi" {
  role_id = "${var.cluster_name}CSItf"

  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CPU",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Options",
    "VM.Migrate",
    "VM.Monitor",
    "VM.PowerMgmt",
  ]

  lifecycle {
    # Prevent recreation if role already exists
    ignore_changes = [role_id]
  }
}

# Create kubernetes-csi user
resource "proxmox_virtual_environment_user" "kubernetes_csi" {
  user_id = "${var.cluster_name}csi@pve"
  enabled = true
  comment = "Kubernetes CSI driver user"

  lifecycle {
    # Prevent recreation if user already exists
    ignore_changes = [user_id]
  }
}

# Create ACL to assign CSI role to kubernetes-csi user on root path
resource "proxmox_virtual_environment_acl" "kubernetes_csi" {
  path      = "/"
  user_id   = proxmox_virtual_environment_user.kubernetes_csi.user_id
  role_id   = proxmox_virtual_environment_role.csi.role_id
  propagate = true
}

# Create API token for kubernetes-csi user
resource "proxmox_virtual_environment_user_token" "kubernetes_csi" {
  user_id               = proxmox_virtual_environment_user.kubernetes_csi.user_id
  token_name            = "CSItf"
  privileges_separation = false
  comment               = "CSI driver API token"
}
