
## Prerequisites
Ansible only:
1. Linux system for Ansible master. (if you are using windows you can go with bellow)
2. Ubuntu for Windows (WSL) installed. ( if you have linux system you can skip this line )
3. Ansible 2.5.0+ installed on Ubuntu for Windows (pip installation recommended).
4. Additional python packages installed for WinRM (follow [Ansible Windows Setup Guide](http://docs.ansible.com/ansible/2.5/user_guide/windows_setup.html)).
5. Windows Server 1709 , 1803 or 1809  installed on Windows  nodes.
6. WinRM properly configured on Windows  nodes.
7. Ubuntu 16.04 LTS (Xenial) installed on Linux   nodes.

##  Ansible usage
### Step 1 - Install prerequisites
First, install all prerequisites from the previous paragraph. Ensure that a basic Ansible playbook is working properly when using Ubuntu for Windows (WSL) for both Windows and Linux nodes. If you have linux system you can directly install Ansible Playbook.

#### Prepare Ansible Host system
- Setup for ansible host  on Ubuntu system ( It can be use your Laptop , do not use Servers)

```
apt-get update
apt-get -y install software-properties-common
apt-add-repository -y ppa:ansible/ansible
apt-get update
apt-get install -y ansible python-pip
pip install pywinrm
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


your inventory should be defined as:

```
[master-ubuntu]
ubuntu01 kubernetes_node_hostname=ubuntu01




- Edit windows username and password inside the file inventory/group_vars/node-windows.yml

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

### Step 3 - Install docker packages using install-docker.yml playbook
In order to install docker on Windows  nodes, run ``install-docker.yml`` playbook:

```
sh installk8s-node.sh
or
ansible-playbook -i inventory install-docker.yml
```
