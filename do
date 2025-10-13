#!/bin/bash
set -euo pipefail

# see https://github.com/siderolabs/talos/releases
# renovate: datasource=github-releases depName=siderolabs/talos
talos_version="1.11.2"

# see https://github.com/siderolabs/extensions/pkgs/container/qemu-guest-agent
# see https://github.com/siderolabs/extensions/tree/main/guest-agents/qemu-guest-agent
talos_qemu_guest_agent_extension_tag="10.0.2@sha256:9720300de00544eca155bc19369dfd7789d39a0e23d72837a7188f199e13dc6c"

# see https://github.com/siderolabs/extensions/pkgs/container/drbd
# see https://github.com/siderolabs/extensions/tree/main/storage/drbd
# see https://github.com/LINBIT/drbd
#talos_drbd_extension_tag="9.2.14-v1.11.0@sha256:3b9ca09718e77934e57b591bae2b29dbb44b2350e86694938713361f562b5b04"

# see https://github.com/siderolabs/extensions/pkgs/container/spin
# see https://github.com/siderolabs/extensions/tree/main/container-runtime/spin
#talos_spin_extension_tag="v0.21.0@sha256:ebc4906e1ef003a0ed6f6ad2a64c575feeaf48d8b15e3e08f9e60df3c27c2bc9"

export CHECKPOINT_DISABLE='1'
export TF_LOG='WARN' # TRACE, DEBUG, INFO, WARN or ERROR.
export TF_LOG_PATH='terraform.log'

export TALOSCONFIG=$PWD/talosconfig.yml
export KUBECONFIG=$PWD/kubeconfig.yml

function step {
  echo "### $* ###"
}

function update-talos-extension {
  # see https://github.com/siderolabs/extensions?tab=readme-ov-file#installing-extensions
  local variable_name="$1"
  local image_name="$2"
  local images="$3"
  local image="$(grep -F "$image_name:" <<<"$images")"
  local tag="${image#*:}"
  echo "updating the talos extension to $image..."
  variable_name="$variable_name" tag="$tag" perl -i -pe '
    BEGIN {
      $var = $ENV{variable_name};
      $val = $ENV{tag};
    }
    s/^(\Q$var\E=).*/$1"$val"/;
  ' do
}

function update-talos-extensions {
  step "updating the talos extensions"
  local images="$(crane export "ghcr.io/siderolabs/extensions:v$talos_version" | tar x -O image-digests)"
  update-talos-extension talos_qemu_guest_agent_extension_tag ghcr.io/siderolabs/qemu-guest-agent "$images"
}

function build_talos_image {
  # see https://www.talos.dev/v1.10/talos-guides/install/boot-assets/
  # see https://www.talos.dev/v1.10/advanced/metal-network-configuration/
  # see Profile type at https://github.com/siderolabs/talos/blob/v1.10.6/pkg/imager/profile/profile.go#L23-L46
  local talos_version_tag="v$talos_version"
  rm -rf tmp/talos
  mkdir -p tmp/talos
  cat >"tmp/talos/talos-$talos_version.yml" <<EOF
arch: amd64
platform: nocloud
secureboot: false
version: $talos_version_tag
customization:
  extraKernelArgs:
    - net.ifnames=0
input:
  kernel:
    path: /usr/install/amd64/vmlinuz
  initramfs:
    path: /usr/install/amd64/initramfs.xz
  baseInstaller:
    imageRef: ghcr.io/siderolabs/installer:$talos_version_tag
  systemExtensions:
    - imageRef: ghcr.io/siderolabs/qemu-guest-agent:$talos_qemu_guest_agent_extension_tag
output:
  kind: image
  imageOptions:
    diskSize: $((2*1024*1024*1024))
    diskFormat: raw
  outFormat: raw
EOF
  docker run --rm -i \
    -v $PWD/tmp/talos:/secureboot:ro \
    -v $PWD/tmp/talos:/out \
    -v /dev:/dev \
    --privileged \
    "ghcr.io/siderolabs/imager:$talos_version_tag" \
    - < "tmp/talos/talos-$talos_version.yml"
  local img_path="tmp/talos/talos-$talos_version.qcow2"
  qemu-img convert -O qcow2 tmp/talos/nocloud-amd64.raw $img_path
  qemu-img info $img_path
  cat >terraform.tfvars <<EOF
talos_version = "$talos_version"
EOF
}

function init {
  step 'build talos image'
  build_talos_image
  step 'terraform init'
  terraform init -lockfile=readonly
}

function plan {
  step 'terraform plan'
  terraform plan -out=tfplan
}

function apply {
  step 'terraform apply'
  terraform apply tfplan
  terraform output -raw talosconfig >talosconfig.yml
  terraform output -raw kubeconfig >kubeconfig.yml
  terraform output -raw csi_token_id >secret_csi_token_id
  terraform output -raw csi_token_secret >secret_csi_token_secret
  terraform output -raw start_lb_address >secret_start_lb_address
  terraform output -raw stop_lb_address >secret_stop_lb_address
  health
  info
  sleep 3
  KUBECONFIG=kubeconfig.yml helmfile apply -f helmfile.d/
}

function health {
  step 'talosctl health'
  local controllers="$(terraform output -raw controllers)"
  local workers="$(terraform output -raw workers)"
  local c0="$(echo $controllers | cut -d , -f 1)"
  talosctl -e $c0 -n $c0 \
    health \
    --control-plane-nodes $controllers \
    --worker-nodes $workers
}


function info {
  local controllers="$(terraform output -raw controllers)"
  local workers="$(terraform output -raw workers)"
  local nodes=($(echo "$controllers,$workers" | tr ',' ' '))
  step 'talos node installer image'
  for n in "${nodes[@]}"; do
    # NB there can be multiple machineconfigs in a machine. we only want to see
    #    the ones with an id that looks like a version tag.
    talosctl -n $n get machineconfigs -o json \
      | jq -r 'select(.metadata.id | test("v\\d+")) | .spec' \
      | yq -r '.machine.install.image' \
      | sed -E "s,(.+),$n: \1,g"
  done
  step 'talos node os-release'
  for n in "${nodes[@]}"; do
    talosctl -n $n read /etc/os-release \
      | sed -E "s,(.+),$n: \1,g"
  done
  step 'kubernetes nodes'
  kubectl get nodes -o wide
}

function destroy {
  terraform destroy -auto-approve
}

case $1 in
  update-talos-extensions)
    update-talos-extensions
    ;;
  init)
    init
    ;;
  plan)
    plan
    ;;
  apply)
    apply
    ;;
  plan-apply)
    plan
    apply
    ;;
  health)
    health
    ;;
  info)
    info
    ;;
  destroy)
    destroy
    ;;
  *)
    echo $"Usage: $0 {init|plan|apply|plan-apply|health|info}"
    exit 1
    ;;
esac
