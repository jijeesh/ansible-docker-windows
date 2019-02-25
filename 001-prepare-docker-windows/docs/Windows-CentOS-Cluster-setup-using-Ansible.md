# kubernetes-for-windows-centos-cluster



## Prerequisites
Ansible only:
1. Linux system for Ansible master. (if you are using windows you can go with bellow)
2. Ubuntu for Windows (WSL) installed. ( if you have linux system you can skip this line )
3. Ansible 2.5.0+ installed on Ubuntu for Windows (pip installation recommended).
4. Additional python packages installed for WinRM (follow [Ansible Windows Setup Guide](http://docs.ansible.com/ansible/2.5/user_guide/windows_setup.html)).
5. Windows Server 1709 (Jan 2018) installed on Windows Kubernetes nodes.
6. WinRM properly configured on Windows Kubernetes nodes.
7. Centos   installed on Linux master and nodes.

##  Ansible usage
### Step 1 - Install prerequisites
First, install all prerequisites from the previous paragraph. Ensure that a basic Ansible playbook is working properly when using Ubuntu for Windows (WSL) for both Windows and Linux nodes. If you have linux system you can directly install Ansible Playbook.

#### Prepare Ansible Host system
- Setup for ansible host  on Centos system ( It can be use your Laptop , do not use Servers)
- Ansible required python 2.5.9+ version

```
sudo ./install_python.sh
logout 
login

#uninstall any previous package installed
sudo pip uninstall pywinrm pywinrm[ntlm] requests-ntlm
# install ansible and winrm
sudo pip install ansible pywinrm pywinrm[ntlm] requests-ntlm
```
#### Prepare Master and Linux Nodes 

- Disable SELinux in all the centos nodes and master
- Create a user with password in the Master,Nodes linux systems to communicate with ansible-linux
- If you required to use with key to login to the linux Master and Nodes use bellow steps
- Generate key without password
In the case of centos , some privilage issue come. So we need to copy public key to root authorized_keys and use ssh user as root instead of ubuntu.. you can skip user creation section from bellow steps

You can use bellow script to do all node 
scripts/sudo.sh

```
#!/bin/bash
useradd  -d /home/ubuntu -s /bin/bash -p 'ubuntu' ubuntu
echo 'ubuntu ALL=NOPASSWD:ALL' > /etc/sudoers.d/ubuntu
echo 'Defaults:ubuntu !requiretty' >> /etc/sudoers.d/ubuntu
sudo sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config
```

```
# Add user
adduser ubuntu
```
Generate key without passwor in ansible host system and copy to the master or nodes authorized_keys files

```


# Create Key
ssh-keygen
# Copy the Public key to authorized_keys of the remote server
cp ~/.ssh/id_rsa.pub to master or node server ~/.ssh/authorized_keys
# Change mode
```
change the permission in the master and node servers

```
chmod -R 600 ~/.ssh/*
chmod  700 ~/.ssh
# Change ownership
chown -R ubuntu: ~/.ssh
# Exit to root user and change mode to user only access to the home folder
chmod 700 /home/ubuntu/

#Enable sudo user for the Ubuntu user shown like bellow
ubuntu  ALL=(ALL) NOPASSWD: ALL
Defaults:ubuntu !requiretty
```


#### Prepare Windows Node to access Ansible Remotely
  
 - To use this script to enable https port 5986, run the following in PowerShell:
 
```


$url = "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
$file = "$env:temp\ConfigureRemotingForAnsible.ps1"

(New-Object -TypeName System.Net.WebClient).DownloadFile($url, $file)

powershell.exe -ExecutionPolicy ByPass -File $file
winrm enumerate winrm/config/Listener
```
- Install chocolatey package manager to avoid error while running ansible-playbook

```
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

```

### Step 2 - Prepare inventory file
A sample inventory file has been provided in [Ansible playbook directory](ansible/inventory). Assuming that you would like to create cluster having the following hosts:


 
 - Master node: centos01
 - Windows nodes: windows01
 
 **Note: Do not give hostname in CAPITAL LETTERS . Use small letter. Otherwise windows connection will make trouble**

your inventory should be defined as:

```
[master-centos]
10.0.0.5 kubernetes_node_hostname=master01

[node-centos]
# ubuntu02 kubernetes_node_hostname=ubuntu02_some_hostname
# ubuntu03 kubernetes_node_hostname=ubuntu03_some_hostname

[node-windows]
10.0.0.16 kubernetes_node_hostname=windows01
# windows02 kubernetes_node_hostname=windows02_some_hostname

[node:children]
node-windows
# node-centos

[all-centos:children]
master-centos
# node-centos

```
### Step 2 - Prepare authentication To the Master ans Nodes

 All the sample files has been provided in [Ansible playbook group_var directory](ansible/group_vars).
you need to edit with example bellow

- ansible/group_vars/master-ubuntu.ym.

```
# This is the user we created for ansible communication in the master server
ansible_user: ubuntu
# Here you can give ssh password if your server has enabled username password authentication ( You can uncomment it )
#ansible_ssh_pass: ubuntu
# This is the place to give sudo password 
ansible_become_pass: ubuntu
# This is the private key file location to communicate with the server. ( you can comment it if you are using ssh username password enabled server)
ansible_ssh_private_key_file: ~/key/ubuntu01.pem
```


- Edit windows username and password inside the file group_vars/node-windows.yml

```
# Use windows username
ansible_user: jka
# Use windows password
ansible_password: XXXXXXX
# Use communication port opened for WinRM to communicate with ansible
ansible_port: 5986
ansible_connection: winrm
ansible_winrm_transport: ntlm
ansible_winrm_operation_timeout_sec: 120
ansible_winrm_read_timeout_sec: 140
# The following is necessary for Python 2.7.9+ (or any older Python that has backported SSLContext, eg, Python 2.7.5 on RHEL7) when using default WinRM self-signed certificates:
ansible_winrm_server_cert_validation: ignore
```

### Step 3 - Install Kubernetes packages using install-kubernetes.yml playbook
In order to install basic Kubernetes packages on Windows and Linux nodes, run ``install-kubernetes.yml`` playbook:

```
sh installk8s-node.sh
or
ansible-playbook -i inventory install-kubernetes.yml
```
The playbook consists of the following stages:

1. Installation of common modules on Windows and Linux. This includes various packages required by Kubernetes and recommended configuration, setting up proxy variables, updating OS, changing hostname.
2. Docker installation. On Windows, at this stage, appropriate Docker images are being pulled and tagged for compatibility reasons, as mentioned in official Microsoft [guide](https://docs.microsoft.com/en-us/virtualization/windowscontainers/kubernetes/getting-started-kubernetes-windows#creating-the-pause-image).
3. CNI plugins installation. On Windows, custom plugins are downloaded based on this [repository](https://github.com/ptylenda/plugins/tree/windowsCni) which is a fork of https://github.com/containernetworking/plugins/pull/85 by [rakelkar](https://github.com/rakelkar).
4. Kubernetes packages installation (currently 1.10). On Windows, there are also NSSM services created for kubelet and kube-proxy (in 1.10 it should be possible to create the services natively, however it has not been tested here)
5. On Windows, custom Flannel is installed based on this [repository](https://github.com/ptylenda/flannel/tree/windowsHostGw180115) which is a fork of https://github.com/coreos/flannel/pull/921 by [rakelkar](https://github.com/rakelkar)

At this point, the nodes are ready to be initialized by kubeadm as hybrid Kubernetes cluster. 


### Step 4 - Create Kubernetes cluster with kubeadm using create-kubeadm-cluster.yml
In order to initialize the cluster, run ``create-kubeadm-cluster.yml`` playbook:

```
sh create-kubeadm-cluster.sh
Or
ansible-playbook -i inventory create-kubeadm-cluster.yml --tags=init
```
Filtering by ``init`` tag omits installation of Kubernetes packages which have been already installed in Step 3.
Installation consists of the following stages:
##### Master initialization
1. Master node is initialized using kubeadm.
2. Cluster join token is generated using kubeadm for other nodes.
3. Old Flannel routes/networks are deleted, if present.
4. Kube config is copied to current user's HOME.
5. [RBAC role and role binding](ansible/roles/ubuntu/kubernetes-master/files/kube-proxy-node-rbac.yml) for standalone kube-proxy service is applied. It is required for Windows, which does not host kube-proxy as Kubernetes pod, i.e. it is hosted as a traditional system service.
6. An additional node selector for kube-proxy is applied. Node selector ensures that kube-proxy daemonset is only deployed to Linux nodes. On Windows it is not supported yet, hence the standalone system service.
7. Flannel network with host-gw backend is installed. Node selector ``beta.kubernetes.io/os: linux`` has been added in order to prevent from deploying on Windows nodes, where Flannel is being handled independently.
##### Ubuntu nodes initialization
1. Node joins cluster using kubeadm and token generated on master.
2. Old Flannel routes/networks are deleted, if present.
3. Kubelet service is started.
##### Windows nodes initialization
1. Node joins cluster using kubeadm and token generated on master. Works exactly the same as for Linux nodes.
2. Old Flannel routes/networks are deleted, if present. HNS endpoints/policies are deleted, all the operations are performed by [kube-cleanup.ps1](ansible/roles/windows/kubernetes-node/files/kube-cleanup.ps1) script.
3. Flannel, kubelet and kube-proxy are started (and restarted) in a specific sequence. Flannel is not fully operational during the first execution and it requires restarting (probably a bug).

Right now the cluster is fully functional, you can proceed with deploying an example Windows service.

The playbook is idempotent, so you can add more nodes to an existing cluster just by extending inventory and rerunning the playbook.


### Step 5 - Deploying an example Windows service
[win-webserver.yml](ansible/roles/ubuntu/demo-deployment/files/win-webserver.yml) contains an example Deployment and Service based on Microsoft [guide](https://docs.microsoft.com/en-us/virtualization/windowscontainers/kubernetes/getting-started-kubernetes-windows#running-a-sample-service). In order to deploy the web service execute:

```
kubectl apply -f win-webserver.yaml
```
This will also deploy a Kubernetes NodePort Service which can be accessed on every Kubernetes node, both Windows and Linux, for example:

![NodePort service call result](ansible/docs/win-webserver-nodeport.jpg "NodePort service call result")
### Step 6 - Resetting Kubernetes cluster
If you wish to tear down the cluster, without destroying the master node, execute the following playbook:

```
ansible-playbook -i inventory reset-kubeadm-cluster.yml
```
And in case you would like to tear down the cluster completely, including the master:

```
ansible-playbook -i inventory reset-kubeadm-cluster.yml --extra-vars="kubernetes_reset_master=True"
```
This playbook performs draining and deleting of the nodes on master node and eventually it resets the node using kubeadm, so that it is available for joining via kubeadm again.

===============================================================================================================================


