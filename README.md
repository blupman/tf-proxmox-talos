# talos via terraform on proxmox

Installs Talos on a Proxmox host, and bootstraps the kubernetes cluster with CSI driver and argo-cd

## origin

forked and severly reworked from https://github.com/rgl/terraform-proxmox-talos

## set these variables to configure the secrets
```shell
unset HTTPS_PROXY
export TF_VAR_proxmox_pve_node_address='10.0.6.14'
export PROXMOX_VE_INSECURE='1'
export PROXMOX_VE_ENDPOINT="endpoint"
export PROXMOX_VE_USERNAME='root@pam'
export PROXMOX_VE_PASSWORD='password'
export ARGO_GITREPO_URL='https://gitlab.com/nielsj/k9.git'
export ARGO_GITREPO_USERNAME=username
export ARGO_GITREPO_PASSWORD=glpat-password
export CERT_MANAGER_API_TOKEN=api-token
```
