#配置主机名

#升级内核

#节点之间配置免密登陆


yum update -y


#配置静态IP

#主机名IP地址解析

#配置 开机启动同步系统时间
echo "ntpdate time1.aliyun.com" > /etc/rc.d/rc.local ;chmod +x /etc/rc.d/rc.local

#设置防火墙为 Iptables
systemctl stop firewalld && systemctl disable firewalld

#关闭 SELINUX 禁用swap 分区
swapoff -a && sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

setenforce 0 && sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

#时间同步


#安装依赖包

yum install -y conntrack ntpdate ntp ipvsadm ipset jq iptables curl sysstat libseccomp wget vim net-tools git lrzsz gperf gcc*

yum -y install iptables-services && systemctl start iptables && systemctl enable iptables && iptables -F && service iptables save

ntpdate time1.aliyun.com



#调整内核参数配置内核转发，对于 K8S#

cat > kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.ipv4.tcp_tw_recycle=0
vm.swappiness=0 # 禁止使用 swap 空间，只有当系统 OOM 时才允许使用它
vm.overcommit_memory=1 # 不检查物理内存是否够用
vm.panic_on_oom=0 # 开启 OOM
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
fs.file-max=52706963
fs.nr_open=52706963
net.ipv6.conf.all.disable_ipv6=1
net.netfilter.nf_conntrack_max=2310720
EOF

#加载 net—netfilter模块
echo "modprobe br_netfilter" > /etc/sysconfig/modules/br_netfilter.modules;chmod 755 /etc/sysconfig/modules/br_netfilter.modules

modprobe br_netfilter

cp kubernetes.conf /etc/sysctl.d/kubernetes.conf

sysctl -p /etc/sysctl.d/kubernetes.conf

#安装 ipvs

yum install ipset ipvsadmin -y

cat > /etc/sysconfig/modules/ipvs.modules <<-EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
EOF

#授权、检查是否加载模块
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack

#关闭系统不需要服务#

systemctl stop postfix && systemctl disable postfix

#设置 rsyslogd 和 systemd journald

mkdir /var/log/journal
# 持久化保存日志的目录

mkdir /etc/systemd/journald.conf.d

cat > /etc/systemd/journald.conf.d/99-prophet.conf <<EOF
[Journal]
# 持久化保存到磁盘
Storage=persistent
# 压缩历史日志
Compress=yes
SyncIntervalSec=5m
RateLimitInterval=30s
RateLimitBurst=1000
# 最大占用空间 10G
SystemMaxUse=10G
# 单日志文件最大 200M
SystemMaxFileSize=200M
# 日志保存时间 2 周
MaxRetentionSec=2week
# 不将日志转发到 syslog
ForwardToSyslog=no
EOF

systemctl restart systemd-journald


#cri-containerd 安装、github 下载 cri-containerd安装包，并解压到/目录下

wget https://github.com/containerd/containerd/releases/download/v1.7.5/cri-containerd-1.7.5-linux-amd64.tar.gz

tar xzvf cri-containerd-1.7.5-linux-amd64.tar.gz -C /


#containerd 创建文件夹、生成配置文件并修改 pasue半本为 3.9
mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

sed -i 's/pause:3.8/pause:3.9/g' /etc/containerd/config.toml


#打开containerd 并设置为开机自起；并验证containerd 安装 是否成功
systemctl enable --now containerd

containerd --version


#替换安装 runc，编译安装 依赖 libseccomp、 libseccomp 需要依赖  gpref、yum 安装  gperf

yum install gperf gcc* -y

wget https://github.com/opencontainers/runc/releases/download/v1.1.9/libseccomp-2.5.4.tar.gz

tar xzvf libseccomp-2.5.4.tar.gz

cd libseccomp-2.5.4/

./configure

make && make intall

#退回目录
cd

wget  https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64

#删除系统自带的runc  给下载的runc 添加权限并替换
rm -rf /usr/local/sbin/runc;chmod +x runc.amd64; mv runc.amd64 /usr/local/sbin/runc

#查看runc 版本验证安装成功
runc --version


#配置 k8s yum源 阿里源
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
       http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

#更新yum元数据
yum makecache fast

#查看 有哪些版本安装 包
yum list kubeadm.x86_64 --showduplicates | sort -r
yum list kubectl.x86_64 --showduplicates | sort -r
yum list kubelet.x86_64 --showduplicates | sort -r

#安装指定版本 工具  后需要带 -0
#yum install -y kubeadm-1.28.1-0 kubelet-1.28.1-0 kubectl-1.28.1-0
#安装最新版的工具
yum install -y kubeadm kubelet kubectl

#配置 kubelet

echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"' > /etc/sysconfig/kubelet

systemctl enable kubelet

kubeadm config images pull

#主节点初始化集群
kubeadm init --kubernetes-version=v1.28.2 --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.168.200

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#部署网络 插件

#github 上的yaml 文件可能无法下载必须另存再执行

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
#查看名称空间
[root@master ~]# kubectl get ns
NAME                STATUS   AGE
default             Active   14m
kube-node-lease     Active   14m
kube-public         Active   14m
kube-system         Active   14m
tigera-operator     Active   6s

[root@master ~]# kubectl get pods -n tigera-operator
NAME                               READY   STATUS    RESTARTS   AGE
tigera-operator-86df9f985c-qnd8g   1/1     Running   0          29s

wget https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

#修改custom-resources 网段

sed -i 's/192.168/10.244/g' custom-resources.yaml

kubectl create -f custom-resources.yaml


[root@master ~]# kubectl get ns
NAME              STATUS   AGE
calico-system     Active   34s
default           Active   3m40s
kube-node-lease   Active   3m40s
kube-public       Active   3m40s
kube-system       Active   3m40s
tigera-operator   Active   2m30s

#查看calico 容器是否全部运行起来
kubectl get pod -n calico-system -w

[root@master ~]# kubectl get nodes
NAME     STATUS   ROLES           AGE   VERSION
master   Ready    control-plane   15m   v1.28.1
node1    Ready    <none>          14m   v1.28.1
node2    Ready    <none>          14m   v1.28.1


[root@master ~]# kubectl get svc -n kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   8m53s


[root@master ~]# dig -t a www.baidu.com@10.96.0.10

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.14 <<>> -t a www.baidu.com@10.96.0.10
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 24425
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1220
;; QUESTION SECTION:
;www.baidu.com\@10.96.0.10.	IN	A

;; AUTHORITY SECTION:
.			329	IN	SOA	a.root-servers.net. nstld.verisign-grs.com. 2023091202 1800 900 604800 86400

;; Query time: 59 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)
;; WHEN: 三 9月 13 11:44:39 CST 2023
;; MSG SIZE  rcvd: 128




#重置K8S集群
kubeadm reset

#yum install -y ipvsadm
rm -rf /root/.kube
rm -rf /etc/cni/net.d
rm -rf /etc/kubernetes/*
ipvsadm -C
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X