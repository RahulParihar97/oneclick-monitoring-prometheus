Host bastion-server
    HostName ${bastion_ip}
    User ubuntu
    IdentityFile ${pem_path}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host app-server-1
    HostName ${app1_private_ip}
    User ubuntu
    IdentityFile ${pem_path}
    ProxyJump bastion-server

Host app-server-2
    HostName ${app2_private_ip}
    User ubuntu
    IdentityFile ${pem_path}
    ProxyJump bastion-server

Host monitoring-server
    HostName ${monitoring_private_ip}
    User ubuntu
    IdentityFile ${pem_path}
    ProxyJump bastion-server
