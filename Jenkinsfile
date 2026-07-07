pipeline {
    agent any

    options {
        ansiColor('xterm')
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        choice(name: 'ACTION', choices: ['APPLY', 'DESTROY'], description: 'Terraform Action')
        booleanParam(name: 'AUTO_APPROVE', defaultValue: true, description: 'Auto approve Terraform')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: true, description: 'Run Ansible after Apply')
    }

    environment {
        TF_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        SSH_CREDENTIAL = 'ec2-key-one-click'
    }

    stages {
        stage('Checkout Source') {
            steps {
                checkout scm
            }
        }

        stage('Show Build Parameters') {
            steps {
                sh """
                    echo "Action          : ${params.ACTION}"
                    echo "Auto Approve    : ${params.AUTO_APPROVE}"
                    echo "Run Ansible     : ${params.RUN_ANSIBLE}"
                """
            }
        }

        stage('Verify Workspace') {
            steps {
                sh "pwd && ls -lah && tree -L 2 || true"
            }
        }

        stage('Terraform Init') {
            steps {
                dir(env.TF_DIR) {
                    sh "terraform init"
                }
            }
        }

        stage('Terraform Format Check') {
            steps {
                dir(env.TF_DIR) {
                    sh "terraform fmt -check -recursive"
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir(env.TF_DIR) {
                    sh "terraform validate"
                }
            }
        }

        stage('TFLint') {
            steps {
                dir(env.TF_DIR) {
                    sh "tflint --init && tflint"
                }
            }
        }

        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'APPLY' }
            }
            steps {
                dir(env.TF_DIR) {
                    sh "terraform plan -out=tfplan"
                }
            }
        }

        stage('Archive Plan') {
            when {
                expression { params.ACTION == 'APPLY' }
            }
            steps {
                archiveArtifacts artifacts: 'terraform/tfplan'
            }
        }

        stage('Approval') {
            when {
                allOf {
                    expression { params.ACTION == 'APPLY' }
                    expression { !params.AUTO_APPROVE }
                }
            }
            steps {
                input message: 'Proceed with Terraform Apply?', ok: 'Apply'
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'APPLY' }
            }
            steps {
                dir(env.TF_DIR) {
                    script {
                        if (params.AUTO_APPROVE) {
                            sh "terraform apply -auto-approve tfplan"
                        } else {
                            sh "terraform apply tfplan"
                        }
                    }
                }
            }
        }

        stage('Wait for EC2 Health') {
            when {
                expression { params.ACTION == 'APPLY' }
            }
            steps {
                dir(env.TF_DIR) {
                    sh '''
                        echo "Waiting for AWS EC2 Status Checks..."

                        INSTANCE_IDS=$(terraform output -json instance_ids | jq -r '.[]')

                        aws ec2 wait instance-status-ok \
                            --instance-ids $INSTANCE_IDS

                        echo "All EC2 instances passed AWS health checks."
                    '''
                }
            }
        }

        stage('Terraform Outputs') {
            when {
                expression { params.ACTION == 'APPLY' }
            }
            steps {
                script {
                    dir(env.TF_DIR) {
                        env.BASTION_IP = sh(
                            script: 'terraform output -raw bastion_public_ip',
                            returnStdout: true
                        ).trim()

                        env.MONITORING_IP = sh(
                            script: 'terraform output -raw monitoring_private_ip',
                            returnStdout: true
                        ).trim()

                        echo "Bastion IP   : ${env.BASTION_IP}"
                        echo "Monitoring IP: ${env.MONITORING_IP}"
                    }

                    dir(env.TF_DIR) {
                        sh '''
                            echo "=============================================="
                            echo " TERRAFORM OUTPUTS"
                            echo "=============================================="
                            terraform output
                        '''
                    }
                }
            }
        }

        stage('Generate SSH Config') {
            when {
                expression {
                    params.ACTION == 'APPLY' && params.RUN_ANSIBLE
                }
            }
            steps {
                script {
                    dir(env.TF_DIR) {
                        env.BASTION_IP = sh(
                            script: 'terraform output -raw bastion_public_ip',
                            returnStdout: true
                        ).trim()
                    }

                    writeFile(
                        file: "${env.ANSIBLE_DIR}/ssh_config",
                        text: """
Host bastion
    HostName ${env.BASTION_IP}
    User ubuntu

Host 10.0.*.*
    User ubuntu
    ProxyJump bastion

Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
"""
                    )

                    sh """
                        echo "=============================================="
                        echo "Generated SSH Config"
                        echo "=============================================="
                        cat ${env.ANSIBLE_DIR}/ssh_config
                    """
                }
            }
        }

        stage('Refresh Inventory') {
            when {
                expression {
                    params.ACTION == 'APPLY' && params.RUN_ANSIBLE
                }
            }
            steps {
                dir(env.ANSIBLE_DIR) {
                    sh '''
                        ansible-inventory \
                            -i inventories/aws_ec2.yml \
                            --graph
                    '''
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'DESTROY' }
            }
            steps {
                dir(env.TF_DIR) {
                    script {
                        if (params.AUTO_APPROVE) {
                            sh "terraform destroy -auto-approve"
                        } else {
                            sh "terraform destroy"
                        }
                    }
                }
            }
        }

        stage('Wait for Bastion SSH') {
            when {
                expression { params.ACTION == 'APPLY' }
            }
            steps {
                dir(env.TF_DIR) {
                    sh '''
                        BASTION_IP=$(terraform output -raw bastion_public_ip)
                        for i in $(seq 1 30); do
                            if nc -z $BASTION_IP 22; then
                                echo "SSH is ready."
                                exit 0
                            fi
                            echo "Attempt $i/30..."
                            sleep 10
                        done
                        echo "ERROR : Bastion SSH not available."
                        exit 1
                    '''
                }
            }
        }

        stage('Ansible Inventory') {
            when {
                expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE }
            }
            steps {
                sshagent(credentials: [env.SSH_CREDENTIAL]) {
                    dir(env.ANSIBLE_DIR) {
                        sh '''
                            ansible --version

                            echo "=============================================="
                            echo " INVENTORY"
                            echo "=============================================="

                            ansible-inventory --graph
                            ansible-inventory --list > inventory.json
                        '''
                    }
                }
            }
        }

        stage('Ansible Connectivity Test') {
            when {
                expression {
                    params.ACTION == 'APPLY' && params.RUN_ANSIBLE
                }
            }
            steps {
                sshagent(credentials: [env.SSH_CREDENTIAL]) {
                    dir(env.ANSIBLE_DIR) {
                        sh '''
                            echo "=============================================="
                            echo " WAITING FOR SSH"
                            echo "=============================================="

                            ansible all \
                                -m wait_for_connection \
                                -a "timeout=300 sleep=5 delay=10"

                            echo "=============================================="
                            echo " TESTING SSH"
                            echo "=============================================="

                            ansible all -m ping -vvvv
                        '''
                    }
                }
            }
        }

        stage('Configure Infrastructure') {
            when {
                expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE }
            }
            steps {
                sshagent(credentials: [env.SSH_CREDENTIAL]) {
                    dir(env.ANSIBLE_DIR) {
                        sh '''
                            echo "=============================================="
                            echo " RUNNING PLAYBOOK"
                            echo "=============================================="

                            ansible-playbook playbooks/site.yml
                        '''
                    }
                }
            }
        }

        stage('Verify Services') {
            when {
                expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE }
            }
            steps {
                sshagent(credentials: [env.SSH_CREDENTIAL]) {
                    dir(env.ANSIBLE_DIR) {
                        sh '''
                            echo "=============================================="
                            echo " VERIFYING SERVICES"
                            echo "=============================================="

                            ansible monitoring -m shell -a "systemctl is-active prometheus"
                            ansible monitoring -m shell -a "systemctl is-active grafana-server"
                            ansible node_exporter -m shell -a "systemctl is-active node_exporter"
                            ansible bastion -m shell -a "systemctl is-active nginx"
                        '''
                    }
                }
            }
        }

        stage('Copy PEM to Bastion & Monitoring') {
            when {
                expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE }
            }
            steps {
                dir(env.TF_DIR) {
                    script {
                        def bastion = sh(
                            script: 'terraform output -raw bastion_public_ip',
                            returnStdout: true
                        ).trim()

                        def monitoring = sh(
                            script: 'terraform output -raw monitoring_private_ip',
                            returnStdout: true
                        ).trim()

                        withCredentials([sshUserPrivateKey(
                            credentialsId: env.SSH_CREDENTIAL,
                            keyFileVariable: 'SSH_KEY',
                            usernameVariable: 'SSH_USER'
                        )]) {
                            sh """
                                echo "=============================================="
                                echo " COPYING PEM TO BASTION"
                                echo "=============================================="

                                ssh -o StrictHostKeyChecking=no -i \$SSH_KEY \$SSH_USER@${bastion} \
                                    "rm -f ~/ansible-demo.pem"

                                scp -o StrictHostKeyChecking=no -i \$SSH_KEY \
                                    \$SSH_KEY \
                                    \$SSH_USER@${bastion}:/tmp/ansible-demo.pem

                                ssh -o StrictHostKeyChecking=no -i \$SSH_KEY \$SSH_USER@${bastion} \
                                    "mv /tmp/ansible-demo.pem ~/ansible-demo.pem && chmod 400 ~/ansible-demo.pem"

                                echo "=============================================="
                                echo " COPYING PEM TO MONITORING SERVER"
                                echo "=============================================="

                                ssh -o StrictHostKeyChecking=no -i \$SSH_KEY \$SSH_USER@${bastion} "
                                    scp -o StrictHostKeyChecking=no \
                                        -i ~/ansible-demo.pem \
                                        ~/ansible-demo.pem \
                                        ubuntu@${monitoring}:/tmp/ansible-demo.pem &&

                                    ssh -o StrictHostKeyChecking=no \
                                        -i ~/ansible-demo.pem \
                                        ubuntu@${monitoring} '
                                            mv /tmp/ansible-demo.pem ~/ansible-demo.pem &&
                                            chmod 400 ~/ansible-demo.pem
                                        '
                                "
                            """
                        }
                    }
                }
            }
        }

        stage('Load Deployment Outputs') {
            when {
                expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE }
            }
            steps {
                dir(env.TF_DIR) {
                    script {
                        sh "terraform output"

                        env.BASTION_IP = sh(
                            script: "terraform output -raw bastion_public_ip",
                            returnStdout: true
                        ).trim()

                        env.MONITORING_IP = sh(
                            script: "terraform output -raw monitoring_private_ip",
                            returnStdout: true
                        ).trim()

                        echo "Bastion   = ${env.BASTION_IP}"
                        echo "Monitoring = ${env.MONITORING_IP}"
                    }
                }
            }
        }

        stage('Start SSH Tunnel') {
            when {
                expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE }
            }
            steps {
                script {
                    sh """
                        pkill -f "ssh.*-L 9090:${env.MONITORING_IP}:9090" || true

                        nohup ssh \
                          -i ansible/ansible-demo.pem \
                          -o StrictHostKeyChecking=no \
                          -o ExitOnForwardFailure=yes \
                          -N \
                          -L 9090:${env.MONITORING_IP}:9090 \
                          -L 3000:${env.MONITORING_IP}:3000 \
                          -L 9093:${env.MONITORING_IP}:9093 \
                          ubuntu@${env.BASTION_IP} \
                          >/tmp/ssh-tunnel.log 2>&1 &
                    """

                    sleep 5
                }
            }
        }

        stage('Deployment Summary') {
            when {
                expression { params.ACTION == 'APPLY' }
            }
            steps {
                dir(env.TF_DIR) {
                    script {
                        env.BASTION_IP = sh(
                            script: 'terraform output -raw bastion_public_ip',
                            returnStdout: true
                        ).trim()

                        env.MONITORING_IP = sh(
                            script: 'terraform output -raw monitoring_private_ip',
                            returnStdout: true
                        ).trim()

                        env.APP1_IP = sh(
                            script: 'terraform output -raw app_server_1_private_ip',
                            returnStdout: true
                        ).trim()

                        env.APP2_IP = sh(
                            script: 'terraform output -raw app_server_2_private_ip',
                            returnStdout: true
                        ).trim()

                        echo """
========================================================================================
                    🚀 ONE CLICK MONITORING DEPLOYMENT SUCCESSFUL 🚀
========================================================================================

Infrastructure Status
---------------------
✓ Terraform Infrastructure      : SUCCESS
✓ Dynamic Inventory             : SUCCESS
✓ Ansible Configuration         : SUCCESS
✓ Prometheus                    : DEPLOYED
✓ Grafana                       : DEPLOYED
✓ Alertmanager                  : DEPLOYED
✓ Node Exporter                 : DEPLOYED
✓ Nginx Reverse Proxy           : CONFIGURED

========================================================================================
Infrastructure IP Addresses
========================================================================================

Bastion Server          : ${env.BASTION_IP}
Monitoring Server       : ${env.MONITORING_IP}
Application Server 1    : ${env.APP1_IP}
Application Server 2    : ${env.APP2_IP}

========================================================================================
SSH Tunnel (Run on your LOCAL machine)
========================================================================================

ssh -i ansible/ansible-demo.pem \\
    -o StrictHostKeyChecking=no \\
    -L 9090:${env.MONITORING_IP}:9090 \\
    -L 3000:${env.MONITORING_IP}:3000 \\
    -L 9093:${env.MONITORING_IP}:9093 \\
    ubuntu@${env.BASTION_IP}

Keep this SSH session OPEN.

========================================================================================
Monitoring URLs
========================================================================================

Prometheus      : http://localhost:9090
Grafana         : http://localhost:3000
Alertmanager    : http://localhost:9093

========================================================================================
Grafana Login
========================================================================================

Username : admin
Password : admin

========================================================================================
Verification URLs
========================================================================================

Targets
http://localhost:9090/targets

Alerts
http://localhost:9090/alerts

Alertmanager
http://localhost:9093

========================================================================================
Demo Commands
========================================================================================

SSH to Monitoring Server

ssh -i ansible/ansible-demo.pem \\
    -J ubuntu@${env.BASTION_IP} \\
    ubuntu@${env.MONITORING_IP}

SSH from Monitoring Server to App Server

ssh -i ~/ansible-demo.pem ubuntu@${env.APP1_IP}

or

ssh -i ~/ansible-demo.pem ubuntu@${env.APP2_IP}

Trigger Alert

sudo systemctl stop node_exporter

Recover

sudo systemctl start node_exporter

========================================================================================
Project Stack
========================================================================================

• AWS EC2
• Terraform
• Jenkins
• Ansible
• Dynamic AWS Inventory
• Prometheus
• Grafana
• Alertmanager
• Node Exporter
• EC2 Service Discovery
• Nginx Reverse Proxy

========================================================================================
"""
                    }
                }
            }
        }
    }
}
