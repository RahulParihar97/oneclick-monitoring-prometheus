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
        VENV = "/var/lib/jenkins/venvs/ansible"
        ANSIBLE = "${VENV}/bin/ansible-playbook"
        INVENTORY = "${VENV}/bin/ansible-inventory"
    }

    stages {
        stage('Checkout Source') {
            steps { checkout scm }
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
            steps { sh "pwd && ls -lah && tree -L 2 || true" }
        }

        stage('Terraform Init') {
            steps { dir(env.TF_DIR) { sh "terraform init" } }
        }

        stage('Terraform Format Check') {
            steps { dir(env.TF_DIR) { sh "terraform fmt -check -recursive" } }
        }

        stage('Terraform Validate') {
            steps { dir(env.TF_DIR) { sh "terraform validate" } }
        }

        stage('TFLint') {
            steps { dir(env.TF_DIR) { sh "tflint --init && tflint" } }
        }

        stage('Terraform Plan') {
            when { expression { params.ACTION == 'APPLY' } }
            steps { dir(env.TF_DIR) { sh "terraform plan -out=tfplan" } }
        }

        stage('Archive Plan') {
            when { expression { params.ACTION == 'APPLY' } }
            steps { archiveArtifacts artifacts: 'terraform/tfplan' }
        }

        stage('Approval') {
            when {
                allOf {
                    expression { params.ACTION == 'APPLY' }
                    expression { !params.AUTO_APPROVE }
                }
            }
            steps { input message: 'Proceed with Terraform Apply?', ok: 'Apply' }
        }

        stage('Terraform Apply') {
            when { expression { params.ACTION == 'APPLY' } }
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

        stage('Terraform Outputs') {
            when { expression { params.ACTION == 'APPLY' } }
            steps {
                script {
                    dir(env.TF_DIR) {
                        env.BASTION_IP = sh(
                            script: 'terraform output -raw bastion_public_ip',
                            returnStdout: true
                        ).trim()
                    }
                    echo "Bastion IP: ${env.BASTION_IP}"
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

        stage('Generate Ansible Variables') {
            when { expression { params.ACTION == 'APPLY' } }
            steps {
                script {
                    dir(env.TF_DIR) {
                        env.BASTION_IP = sh(
                            script: 'terraform output -raw bastion_public_ip',
                            returnStdout: true
                        ).trim()
                    }
                    writeFile(
                        file: "${env.ANSIBLE_DIR}/group_vars/all.yml",
                        text: """
ansible_user: ubuntu
prometheus_version: "2.54.0"
grafana_version: "11.1.0"
node_exporter_version: "1.8.1"
prometheus_port: 9090
grafana_port: 3000
node_exporter_port: 9100
ansible_ssh_common_args: >-
  -o ProxyJump=ubuntu@${env.BASTION_IP}
"""
                    )
                    sh "cat ${env.ANSIBLE_DIR}/group_vars/all.yml"
                }
            }
        }

        stage('Terraform Destroy') {
            when { expression { params.ACTION == 'DESTROY' } }
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
            when { expression { params.ACTION == 'APPLY' } }
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

        stage('Wait for Cloud Init') {
            when { expression { params.ACTION == 'APPLY' } }
            steps { sleep time: 120, unit: 'SECONDS' }
        }

        stage('Ansible Inventory') {
            when { expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE } }
            steps {
                sshagent(credentials: [env.SSH_CREDENTIAL]) {
                    dir(env.ANSIBLE_DIR) {
                        sh """
                            . ${env.VENV}/bin/activate
                            ${env.INVENTORY} --graph
                            ${env.INVENTORY} --list > inventory.json
                        """
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

            script {

                dir(env.TF_DIR) {
                    env.BASTION_IP = sh(
                        script: "terraform output -raw bastion_public_ip",
                        returnStdout: true
                    ).trim()
                }

                echo "Using Bastion IP: ${env.BASTION_IP}"

                dir(env.ANSIBLE_DIR) {

                    sh """
                    ansible all \
                      -e "ansible_ssh_common_args=-o ProxyJump=ubuntu@${env.BASTION_IP}" \
                      -m ping \
                      -vvvv
                    """

                }

            }

        }

    }

}

        stage('Configure Infrastructure') {

    when {
        expression {
            params.ACTION == 'APPLY' && params.RUN_ANSIBLE
        }
    }

    steps {

        sshagent(credentials: [env.SSH_CREDENTIAL]) {

            script {

                dir(env.TF_DIR) {
                    env.BASTION_IP = sh(
                        script: "terraform output -raw bastion_public_ip",
                        returnStdout: true
                    ).trim()
                }

                dir(env.ANSIBLE_DIR) {

                    sh """
                    ansible-playbook playbooks/site.yml \
                      -e "ansible_ssh_common_args=-o ProxyJump=ubuntu@${env.BASTION_IP}"
                    """

                }

            }

        }

    }

}
stage('Verify Services') {

    when {
        expression {
            params.ACTION == 'APPLY' && params.RUN_ANSIBLE
        }
    }

    steps {

        sshagent(credentials: [env.SSH_CREDENTIAL]) {

            script {

                dir(env.TF_DIR) {
                    env.BASTION_IP = sh(
                        script: "terraform output -raw bastion_public_ip",
                        returnStdout: true
                    ).trim()
                }

                dir(env.ANSIBLE_DIR) {

                    sh """
                    echo "==============================="
                    echo "VERIFYING SERVICES"
                    echo "==============================="

                    ansible monitoring \
                      -e "ansible_ssh_common_args=-o ProxyJump=ubuntu@${env.BASTION_IP}" \
                      -m shell \
                      -a "systemctl is-active prometheus"

                    ansible monitoring \
                      -e "ansible_ssh_common_args=-o ProxyJump=ubuntu@${env.BASTION_IP}" \
                      -m shell \
                      -a "systemctl is-active grafana-server"

                    ansible node_exporter \
                      -e "ansible_ssh_common_args=-o ProxyJump=ubuntu@${env.BASTION_IP}" \
                      -m shell \
                      -a "systemctl is-active node_exporter"

                    ansible bastion \
                      -m shell \
                      -a "systemctl is-active nginx"
                    """

                }

            }

        }

    }

}
        
        stage('Copy PEM to Bastion') {
            when { expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE } }
            steps {
                dir(env.TF_DIR) {
                    script {
                        def bastion = sh(
                            script: 'terraform output -raw bastion_public_ip',
                            returnStdout: true
                        ).trim()
                        withCredentials([sshUserPrivateKey(
                            credentialsId: env.SSH_CREDENTIAL,
                            keyFileVariable: 'SSH_KEY',
                            usernameVariable: 'SSH_USER'
                        )]) {
                            sh """
                                ssh -o StrictHostKeyChecking=no -i \$SSH_KEY \$SSH_USER@${bastion} "rm -f ~/ansible-demo.pem"
                                scp -o StrictHostKeyChecking=no -i \$SSH_KEY \$SSH_KEY \$SSH_USER@${bastion}:/tmp/ansible-demo.pem
                                ssh -o StrictHostKeyChecking=no -i \$SSH_KEY \$SSH_USER@${bastion} "mv /tmp/ansible-demo.pem ~/ansible-demo.pem && chmod 400 ~/ansible-demo.pem"
                            """
                        }
                    }
                }
            }
        }

        stage('Deployment Summary') {
            when { expression { params.ACTION == 'APPLY' } }
            steps {
                dir(env.TF_DIR) {
                    script {
                        def bastion = sh(script: 'terraform output -raw bastion_public_ip', returnStdout: true).trim()
                        def monitoring = sh(script: 'terraform output -raw monitoring_private_ip', returnStdout: true).trim()
                        def app1 = sh(script: 'terraform output -raw app_server_1_private_ip', returnStdout: true).trim()
                        def app2 = sh(script: 'terraform output -raw app_server_2
