cd tools
HELM_VERSION=v3.19.0
wget https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz
tar zxvf  helm-${HELM_VERSION}-linux-amd64.tar.gz
rm helm-${HELM_VERSION}-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/
rm -rf linux-amd64
echo helm plugin
helm plugin install https://github.com/databus23/helm-diff || true
echo helmfile
wget https://github.com/helmfile/helmfile/releases/download/v1.1.7/helmfile_1.1.7_linux_amd64.tar.gz
tar zxvf helmfile_1.1.7_linux_amd64.tar.gz
mv helmfile /usr/local/bin/q
rm *

