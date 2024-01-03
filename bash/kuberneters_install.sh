#!/bin/bash

# 函数：安装 Docker
install_docker() {
    echo "安装 Docker..."
    # 添加 Docker 的 yum 源
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    # 安装 Docker
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    # 启动 Docker
    sudo systemctl start docker
    # 设置 Docker 开机自启
    sudo systemctl enable docker
}

# 函数：安装 Kubernetes
install_kubernetes() {
    echo "安装 Kubernetes..."
    # 添加 Kubernetes 的 yum 源
    sudo tee /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
    # 安装 Kubernetes
    sudo yum install -y kubelet kubeadm kubectl
    # 启动 Kubernetes
    sudo systemctl start kubelet
    # 设置 Kubernetes 开机自启
    sudo systemctl enable kubelet
}

# 函数：初始化 Kubernetes Master
init_kubernetes_master() {
    echo "初始化 Kubernetes Master..."
    # 使用 kubeadm 初始化 Kubernetes Master
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16
    # 设置 kubeconfig
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

# 函数：安装网络插件
install_network_plugin() {
    echo "安装网络插件..."
    # 安装 Flannel 网络插件
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
}

# 主程序
echo "欢迎使用 Kubernetes 安装脚本！"

install_docker
install_kubernetes
init_kubernetes_master
install_network_plugin

echo "Kubernetes 安装完成！"
