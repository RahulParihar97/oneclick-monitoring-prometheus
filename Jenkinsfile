pipeline {

    agent any

    options {
        ansiColor('xterm')
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {

        choice(
            name: 'ACTION',
            choices: ['APPLY', 'DESTROY'],
            description: 'Terraform Action'
        )

        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: true,
            description: 'Auto approve Terraform'
        )

        booleanParam(
            name: 'RUN_ANSIBLE',
            defaultValue: true,
            description: 'Run Ansible after Apply'
        )
    }

    environment {

        TF_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        SSH_CREDENTIAL = 'ec2-key-one-click'

    }

    stages {

    stage('Checkout Source') {

        steps {

            echo "=============================================="
            echo " Checking out source code"
            echo "=============================================="

            checkout scm

        }

    }

    stage('Show Build Parameters') {

        steps {

            sh """
            echo
            echo "=============================================="
            echo " BUILD PARAMETERS"
            echo "=============================================="

            echo "Action          : ${params.ACTION}"
            echo "Auto Approve    : ${params.AUTO_APPROVE}"
            echo "Run Ansible     : ${params.RUN_ANSIBLE}"

            echo
            """

        }

    }

    stage('Verify Workspace') {

        steps {

            sh """
            echo
            echo "=============================================="
            echo " WORKSPACE"
            echo "=============================================="

            pwd

            echo

            ls -lah

            echo

            tree -L 2 || true

            echo
            """

        }

    }

stage('Terraform Init') {

    steps {

        dir(env.TF_DIR) {

            sh '''
            echo "=============================================="
            echo " TERRAFORM INIT"
            echo "=============================================="

            terraform init
            '''

        }

    }

}

stage('Terraform Format Check') {

    steps {

        dir(env.TF_DIR) {

            sh '''
            echo "=============================================="
            echo " TERRAFORM FORMAT CHECK"
            echo "=============================================="

            terraform fmt -check -recursive
            '''

        }

    }

}

stage('Terraform Validate') {

    steps {

        dir(env.TF_DIR) {

            sh '''
            echo "=============================================="
            echo " TERRAFORM VALIDATE"
            echo "=============================================="

            terraform validate
            '''

        }

    }

}

stage('TFLint') {

    steps {

        dir(env.TF_DIR) {

            sh '''
            echo "=============================================="
            echo " RUNNING TFLINT"
            echo "=============================================="

            tflint --init
            tflint
            '''

        }

    }

}

stage('Terraform Plan') {

    when {

        expression {
            params.ACTION == 'APPLY'
        }

    }

    steps {

        dir(env.TF_DIR) {

            sh '''
            echo "=============================================="
            echo " TERRAFORM PLAN"
            echo "=============================================="

            terraform plan -out=tfplan
            '''

        }

    }

}

stage('Archive Plan') {

    when {

        expression {
            params.ACTION == 'APPLY'
        }

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

        input(
            message: 'Proceed with Terraform Apply?',
            ok: 'Apply'
        )

    }

}

stage('Terraform Apply') {

    when {

        expression {

            params.ACTION == 'APPLY'

        }

    }

    steps {

        dir(env.TF_DIR) {

            script {

                if (params.AUTO_APPROVE) {

                    sh '''
                    echo "=============================================="
                    echo " TERRAFORM APPLY"
                    echo "=============================================="

                    terraform apply -auto-approve tfplan
                    '''

                } else {

                    sh '''
                    terraform apply tfplan
                    '''

                }

            }

        }

    }

}

stage('Terraform Outputs') {

    when {

        expression {

            params.ACTION == 'APPLY'

        }

    }

    steps {

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
stage('Generate Ansible Variables') {

    when {
        expression {
            params.ACTION == 'APPLY'
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
                file: "${env.ANSIBLE_DIR}/vars/generated.yml",
                text: """
bastion_ip: ${env.BASTION_IP}

ansible_ssh_common_args: >-
  -o ProxyJump=ubuntu@${env.BASTION_IP}
"""
            )

            echo "Generated ansible/group_vars/generated/bastion.yml"

            sh """
            cat ${env.ANSIBLE_DIR}/group_vars/generated/bastion.yml
            """

        }

    }

}        

stage('Terraform Destroy') {

    when {

        expression {

            params.ACTION == 'DESTROY'

        }

    }

    steps {

        dir(env.TF_DIR) {

            script {

                if (params.AUTO_APPROVE) {

                    sh '''
                    echo "=============================================="
                    echo " TERRAFORM DESTROY"
                    echo "=============================================="

                    terraform destroy -auto-approve
                    '''

                } else {

                    sh '''
                    terraform destroy
                    '''

                }

            }

        }

    }

}
        stage('Wait for Bastion SSH') {

    when {
        expression {
            params.ACTION == 'APPLY'
        }
    }

    steps {

        dir(env.TF_DIR) {

            sh '''
            echo
            echo "=============================================="
            echo " WAITING FOR BASTION SSH"
            echo "=============================================="

            BASTION_IP=$(terraform output -raw bastion_public_ip)

            echo "Bastion IP : $BASTION_IP"

            for i in $(seq 1 30)
            do
                if nc -z $BASTION_IP 22
                then
                    echo
                    echo "SSH is ready."
                    exit 0
                fi

                echo "Attempt $i/30..."
                sleep 10
            done

            echo
            echo "ERROR : Bastion SSH not available."
            exit 1
            '''

        }

    }

}
stage('Wait for Cloud Init') {

    when {
        expression {
            params.ACTION == 'APPLY'
        }
    }

    steps {

        echo '''
==============================================
 WAITING FOR EC2 INITIALIZATION
==============================================
'''

        sleep(
            time: 120,
            unit: 'SECONDS'
        )

    }

}
stage('Ansible Inventory') {

    when {
        expression {
            params.ACTION == 'APPLY' && params.RUN_ANSIBLE
        }
    }

    steps {

        sshagent(credentials: [env.SSH_CREDENTIAL]) {

            dir(env.ANSIBLE_DIR) {

                sh '''
                echo
                echo "=============================================="
                echo " ANSIBLE INVENTORY"
                echo "=============================================="

                ansible-inventory --graph

                echo

                ansible-inventory --list > inventory.json

                echo
                echo "Inventory generated successfully."
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
                echo
                echo "=============================================="
                echo " TESTING SSH CONNECTIVITY"
                echo "=============================================="

                ansible all -m ping -vvvv
                '''

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

            dir(env.ANSIBLE_DIR) {

                sh '''
                echo
                echo "=============================================="
                echo " RUNNING ANSIBLE PLAYBOOK"
                echo "=============================================="

                ansible-playbook playbooks/site.yml
                '''

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

            dir(env.ANSIBLE_DIR) {

                sh '''
                echo
                echo "=============================================="
                echo " VERIFYING SERVICES"
                echo "=============================================="

                echo
                echo "Monitoring Server"
                echo "-----------------"

                ansible monitoring \
                -m shell \
                -a "systemctl is-active prometheus"

                ansible monitoring \
                -m shell \
                -a "systemctl is-active grafana-server"

                echo
                echo "Application Servers"
                echo "-------------------"

                ansible node_exporter \
                -m shell \
                -a "systemctl is-active node_exporter"

                echo
                echo "Bastion Server"
                echo "--------------"

                ansible bastion \
                -m shell \
                -a "systemctl is-active nginx"

                '''
            }

        }

    }

}
stage('Copy PEM to Bastion') {

    when {
        expression {
            params.ACTION == 'APPLY' && params.RUN_ANSIBLE
        }
    }

    steps {

        dir(env.TF_DIR) {

            script {

                def bastion = sh(
                    script: 'terraform output -raw bastion_public_ip',
                    returnStdout: true
                ).trim()

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: env.SSH_CREDENTIAL,
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {

                    sh """
                    echo
                    echo "============================================================"
                    echo " COPYING SSH PRIVATE KEY TO BASTION"
                    echo "============================================================"

                    ssh -o StrictHostKeyChecking=no \
                        -i \$SSH_KEY \
                        \$SSH_USER@${bastion} \
                        "rm -f ~/ansible-demo.pem"

                    scp -o StrictHostKeyChecking=no \
                        -i \$SSH_KEY \
                        \$SSH_KEY \
                        \$SSH_USER@${bastion}:/tmp/ansible-demo.pem

                    ssh -o StrictHostKeyChecking=no \
                        -i \$SSH_KEY \
                        \$SSH_USER@${bastion} \
                        "mv /tmp/ansible-demo.pem ~/ansible-demo.pem && chmod 400 ~/ansible-demo.pem"

                    echo
                    echo "SSH key copied successfully."
                    """
                }
            }
        }
    }
}
stage('Deployment Summary') {

    when {
        expression {
            params.ACTION == 'APPLY'
        }
    }

    steps {

        dir(env.TF_DIR) {

            script {

                def bastion = sh(script: 'terraform output -raw bastion_public_ip', returnStdout: true).trim()
                def monitoring = sh(script: 'terraform output -raw monitoring_private_ip', returnStdout: true).trim()
                def app1 = sh(script: 'terraform output -raw app_server_1_private_ip', returnStdout: true).trim()
                def app2 = sh(script: 'terraform output -raw app_server_2_private_ip', returnStdout: true).trim()

                sh """
cat <<EOF

================================================================================
                 🚀 ONE CLICK MONITORING DEPLOYMENT SUCCESS 🚀
================================================================================

Infrastructure
--------------

Bastion Server
Public IP           : ${bastion}

Monitoring Server
Private IP          : ${monitoring}

Application Server 1
Private IP          : ${app1}

Application Server 2
Private IP          : ${app2}

================================================================================
                           ACCESS YOUR DASHBOARDS
================================================================================

Grafana

http://${bastion}/grafana/

Prometheus

http://${bastion}/prometheus/

================================================================================
                             SSH CONNECTIONS
================================================================================

1. Connect to Bastion

ssh -i ~/oneclick-monitoring-prometheus/ansible/ansible-demo.pem ubuntu@${bastion}

2. Connect to Monitoring Server

ssh -i ~/ansible-demo.pem ubuntu@${monitoring}

3. Connect to Application Server 1

ssh -i ~/ansible-demo.pem ubuntu@${app1}

4. Connect to Application Server 2

ssh -i ~/ansible-demo.pem ubuntu@${app2}

================================================================================
                         MONITORING COMPONENTS
================================================================================

✓ Terraform

✓ Jenkins

✓ Ansible

✓ Prometheus

✓ Grafana

✓ Node Exporter

✓ Nginx Reverse Proxy

================================================================================
EOF
"""
            }
        }
    }
}        
        
        
    }

    post {

    success {

        echo '''
============================================================
             PIPELINE COMPLETED SUCCESSFULLY
============================================================
'''

    }

    failure {

        echo '''
============================================================
               PIPELINE FAILED
============================================================
'''

    }

    always {

        cleanWs(
            deleteDirs: true,
            disableDeferredWipeout: true
        )

    }

}
}
