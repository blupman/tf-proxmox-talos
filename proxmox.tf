# see https://registry.terraform.io/providers/bpg/proxmox/0.81.0/docs/resources/virtual_environment_file
resource "proxmox_virtual_environment_file" "talos" {
  datastore_id = "local"
  node_name    = var.proxmox_pve_node_name
  content_type = "iso"
  source_file {
    #path      = "tmp/nocloud-amd64.iso"
    path      = "tmp/talos/talos-${var.talos_version}.qcow2"
    file_name = "talos-${var.talos_version}.img"
  }
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.81.0/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "controller" {
  count           = var.controller_count
  name            = "${local.controller_nodes[count.index].name}"
  #name            = "${var.prefix}-${local.controller_nodes[count.index].name}"
  node_name       = var.proxmox_pve_node_name
  tags            = sort(["talos", "controller" ])
  stop_on_destroy = true
  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"
  operating_system {
    type = "l26"
  }
  cpu {
    type  = "host"
    cores = 4
  }
  memory {
    dedicated = 4 * 1024
  }
  vga {
    type = "qxl"
  }
  network_device {
    bridge  = var.node_proxmox_bridge
  }
  tpm_state {
    version = "v2.0"
    datastore_id = var.node_datastore
  }
  efi_disk {
    datastore_id = var.node_datastore
    file_format  = "raw"
    type         = "4m"
  }
  disk {
    datastore_id = var.node_datastore
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = 40
    file_format  = "raw"
    file_id      = proxmox_virtual_environment_file.talos.id
  }
  agent {
    enabled = true
    trim    = true
  }
  initialization {
    datastore_id = var.node_datastore
    ip_config {
      ipv4 {
        address = "${local.controller_nodes[count.index].address}/24"
        gateway = var.cluster_node_network_gateway
      }
    }
  }
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.81.0/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "worker" {
  count           = var.worker_count
  name            = "${local.worker_nodes[count.index].name}"
  #name            = "${var.prefix}-${local.worker_nodes[count.index].name}"
  node_name       = var.proxmox_pve_node_name
  tags            = sort(["talos", "worker"])
  stop_on_destroy = true
  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"
  operating_system {
    type = "l26"
  }
  cpu {
    type  = "host"
    cores = 4
  }
  memory {
    dedicated = 8 * 1024
  }
  vga {
    type = "qxl"
  }
  network_device {
    bridge  = var.node_proxmox_bridge
  }
  tpm_state {
    version = "v2.0"
    datastore_id = var.node_datastore
  }
  efi_disk {
    datastore_id = var.node_datastore
    file_format  = "raw"
    type         = "4m"
  }
  disk {
    datastore_id = var.node_datastore
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = 20
    file_format  = "raw"
    file_id      = proxmox_virtual_environment_file.talos.id
  }
  agent {
    enabled = true
    trim    = true
  }
  initialization {
    datastore_id = var.node_datastore
    ip_config {
      ipv4 {
        address = "${local.worker_nodes[count.index].address}/24"
        gateway = var.cluster_node_network_gateway
      }
    }
  }
}
