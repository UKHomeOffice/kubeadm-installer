#!/bin/bash

ROOTFS=${ROOTFS:-/rootfs}
K8S_VERSION=${K8S_VERSION:-v1.6.0-alpha.1}
KUBELET_IMAGE_TAG=${KUBELET_IMAGE_TAG:-${K8S_VERSION}_coreos.0}
CNI_RELEASE=${CNI_RELEASE:-07a8a28637e97b22eb8dfe710eeae1344f69d16e}
ARCH=${ARCH:-amd64}
CNI_BIN_DIR=${CNI_BIN_DIR:-/opt/cni}
IP=$(hostname -i)

if [[ $1 == "coreos" ]]; then
	BIN_DIR=${BIN_DIR:-/opt/bin}
	KUBELET_EXEC=${KUBELET_EXEC:-${BIN_DIR}/kubelet}
	INSTALL_KUBELET=1
	#KUBELET_EXEC=${KUBELET_EXEC:-/usr/lib/coreos/kubelet-wrapper}
	EXTRA_ENVIRONMENT=${EXTRA_ENVIRONMENT:-"RKT_RUN_ARGS=--volume opt-cni,kind=host,source=/opt/cni --mount volume=opt-cni,target=/opt/cni --volume etc-cni,kind=host,source=/etc/cni --mount volume=etc-cni,target=/etc/cni"}
elif [[ $1 == "ubuntu" || $1 == "debian" || $1 == "fedora" || $1 == "centos" ]]; then
	BIN_DIR=${BIN_DIR:-/usr/bin}
	KUBELET_EXEC=${KUBELET_EXEC:-${BIN_DIR}/kubelet}
	EXTRA_ENVIRONMENT=${EXTRA_ENVIRONMENT:-"NOOP=true"}
	INSTALL_KUBELET=1
else
	cat <<-EOF
	Hi, you should run this container like this:
	docker run -it -v /etc/cni:/etc/cni -v /etc/systemd:/etc/systemd -v /opt:/opt -v /usr/bin:/usr/bin luxas/kubeadm-installer your_os_here

	your_os_here can be coreos, ubuntu, debian, fedora or centos

	You can also revert this action with running:
	docker run -it -v /etc/:/rootfs/etc -v /usr:/rootfs/usr -v /opt:/rootfs/opt luxas/kubeadm-installer uninstall
	EOF
	exit 1
fi

if [[ $2 == "uninstall" ]]; then
	rm -rf ${ROOTFS}/etc/cni ${ROOTFS}/${BIN_DIR}/kubectl ${ROOTFS}/${BIN_DIR}/kubelet ${ROOTFS}/${BIN_DIR}/kubeadm ${ROOTFS}/${CNI_BIN_DIR} ${ROOTFS}/etc/systemd/system/kubelet.service
	echo "Removed /etc/cni, ${BIN_DIR}/kubectl, ${BIN_DIR}/kubelet, ${BIN_DIR}/kubeadm, /opt/cni and /etc/systemd/system/kubelet.service"
	exit 1
fi

mkdir -p ${ROOTFS}/etc/cni ${ROOTFS}/${BIN_DIR}

if [[ ! -f ${ROOTFS}/${BIN_DIR}/kubectl ]]; then
	curl -sSL https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${ARCH}/kubectl > ${ROOTFS}/${BIN_DIR}/kubectl
	chmod +x ${ROOTFS}/${BIN_DIR}/kubectl
	echo "Installed kubectl in ${BIN_DIR}/kubectl"
else
	echo "Ignoring ${BIN_DIR}/kubectl, since it seems to exist already"
fi

if [[ ! -f ${ROOTFS}/${BIN_DIR}/kubelet && ${INSTALL_KUBELET} == 1 ]]; then
	curl -sSL https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${ARCH}/kubelet > ${ROOTFS}/${BIN_DIR}/kubelet
	chmod +x ${ROOTFS}/${BIN_DIR}/kubelet
	echo "Installed kubelet in ${BIN_DIR}/kubelet"
else
	echo "Ignoring ${BIN_DIR}/kubelet, since it seems to exist already"
fi

if [[ ! -f ${ROOTFS}/${BIN_DIR}/kubeadm ]]; then
	curl -sSL https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${ARCH}/kubeadm > ${ROOTFS}/${BIN_DIR}/kubeadm
	chmod +x ${ROOTFS}/${BIN_DIR}/kubeadm
	echo "Installed kubeadm in ${BIN_DIR}/kubeadm"
else
	echo "Ignoring ${BIN_DIR}/kubeadm, since it seems to exist already"
fi

if [[ ! -d ${ROOTFS}/${CNI_BIN_DIR} ]]; then
	mkdir -p ${ROOTFS}/${CNI_BIN_DIR}
	curl -sSL https://storage.googleapis.com/kubernetes-release/network-plugins/cni-${ARCH}-${CNI_RELEASE}.tar.gz | tar -xz -C ${ROOTFS}/${CNI_BIN_DIR}
	echo "Installed CNI binaries in /opt/cni"
else
	echo "Ignoring /opt/cni, since it seems to exist already"
fi

if [[ ! -f ${ROOTFS}/etc/systemd/system/kubelet.service ]]; then
	cat > ${ROOTFS}/etc/systemd/system/kubelet.service <<-EOF
	[Unit]
	Description=kubelet: The Kubernetes Node Agent
	Documentation=http://kubernetes.io/docs/

	[Service]
	Environment="KUBELET_IMAGE_TAG=${KUBELET_IMAGE_TAG}"
	Environment="${EXTRA_ENVIRONMENT}"
	ExecStart=${KUBELET_EXEC} --kubeconfig=/etc/kubernetes/kubelet.conf \
	          --require-kubeconfig=true \
	          --pod-manifest-path=/etc/kubernetes/manifests \
	          --allow-privileged=true \
	          --network-plugin=cni \
	          --cni-conf-dir=/etc/cni/net.d \
	          --cni-bin-dir=/opt/cni/bin \
	          --cluster-dns=10.96.0.10 \
	          --cluster-domain=cluster.local \
	          --node-ip=${IP} \
	          --hostname-override=${HOSTNAME}
	Restart=always
	StartLimitInterval=0
	RestartSec=10

	[Install]
	WantedBy=multi-user.target
	EOF
	echo "Installed the kubelet.service in /etc/systemd/system/kubelet.service"
else
	echo "Ignoring /etc/systemd/system/kubelet.service, since it seems to exist already"
fi

cat <<EOF
Done! Now run this in your terminal to enable docker and kubelet:

systemctl daemon-reload
systemctl enable docker kubelet
systemctl restart docker kubelet
EOF
