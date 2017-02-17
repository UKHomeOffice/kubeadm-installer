## kubeadm installer for CoreOS, Ubuntu, Debian, CentOS and Fedora

### Manual testing (any hosts / VM's with SINGLE adapter):

```

#CNI_PLUGIN_DEPLOY=http://docs.projectcalico.org/v1.6/getting-started/kubernetes/installation/hosted/kubeadm/calico.yaml
#CNI_PLUGIN_DEPLOY=https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
#curl https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
#CNI_PLUGIN_DEPLOY=https://raw.githubusercontent.com/projectcalico/canal/master/k8s-install/kubeadm/canal.yaml
#CNI_PLUGIN_DEPLOY=https://git.io/weave-kube

#https://github.com/coreos/flannel/blob/master/Documentation/kube-flannel-rbac.yml
CNI_PLUGIN_DEPLOY=https://raw.githubusercontent.com/luxaslabs/weave/d18e9cf56f69bf01c61178df47806488e96793c8/prog/weave-kube/weave-daemonset-k8s-HEAD.yaml
K8S_VERSION=v1.6.0-alpha.2

mkdir -p /opt/bin
git clone https://github.com/UKHomeOffice/kubeadm-installer
cd kubeadm-installer
docker build -t kubeadm-installer .

docker run -it \
  --net=host \
  -e K8S_VERSION=${K8S_VERSION} \
  -e KUBELET_IMAGE_TAG=v1.5.2_coreos.2 \
  -v /etc/cni:/rootfs/etc/cni \
  -v /etc/systemd:/rootfs/etc/systemd \
  -v /opt:/rootfs/opt \
  -v /usr/bin:/rootfs/usr/bin \
  kubeadm-installer coreos

systemctl daemon-reload
systemctl enable docker kubelet
systemctl restart docker kubelet

# --skip-preflight-checks
# --pod-network-cidr 10.244.0.0/16
# --api-advertise-addresses=172.17.8.101
kubeadm init --use-kubernetes-version ${K8S_VERSION} --self-hosted
kubectl apply -f ${CNI_PLUGIN_DEPLOY}
```

### How to run install kubeadm

Given docker already is installed (otherwise, run `curl get.docker.com | bash`), you can install kubeadm easily!

```bash
$ docker run -it \
	-v /etc/cni:/rootfs/etc/cni \
	-v /etc/systemd:/rootfs/etc/systemd \
	-v /opt:/rootfs/opt \
	-v /usr/bin:/rootfs/usr/bin \
	luxas/kubeadm-installer ${your_os_here}
```

`${your_os_here}` can be `coreos`, `ubuntu`, `debian`, `fedora` or `centos`

### How to uninstall/revert

```bash
$ docker run -it 	\
	-v /etc/cni:/rootfs/etc/cni \
	-v /etc/systemd:/rootfs/etc/systemd \
	-v /opt:/rootfs/opt \
	-v /usr/bin:/rootfs/usr/bin \
	luxas/kubeadm-installer ${your_os_here} uninstall
```

### What's inside?

 - kubeadm `v1.5.0-alpha.2.421+a6bea3d79b8bba`, see releases here: http://kubernetes.io/docs/admin/kubeadm/
 - kubernetes `v1.4.4`
 - cni `07a8a28637e97b22eb8dfe710eeae1344f69d16e`

### License

MIT
