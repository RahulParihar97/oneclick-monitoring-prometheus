pipeline {
    agent any

    options {
        ansiColor('xterm')
        timestamps()
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['APPLY', 'DESTROY'],
            description: 'Choose Terraform Action'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: true,
            description: 'Auto approve Terraform'
        )
        booleanParam(
            name: 'RUN_ANSIBLE',
            defaultValue: true,
            description: 'Run Ansible after Terraform Apply'
        )
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Show Parameters') {
            steps {
                sh """
                    echo "ACTION        : ${params.ACTION}"
                    echo "AUTO_APPROVE  : ${params.AUTO_APPROVE}"
                    echo "RUN_ANSIBLE   : ${params.RUN_ANSIBLE}"
                """
            }
        }

        stage('Verify Workspace') {
            steps {
                sh '''
                    pwd
                    tree -L 2 || true
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Format Check') {
            steps {
                dir('terraform') {
                    sh 'terraform fmt -check -recursive'
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh 'terraform validate'
                }
            }
        }

        stage('TFLint') {
            steps {
                dir('terraform') {
                    sh 'tflint --init && tflint'
                }
            }
        }

        stage('Terraform Plan') {
            when { expression { params.ACTION == 'APPLY' } }
            steps {
                dir('terraform') {
                    sh 'terraform plan -out=tfplan'
                }
            }
        }

        stage('Archive Plan') {
            when { expression { params.ACTION == 'APPLY' } }
            steps {
                archiveArtifacts artifacts: 'terraform/tfplan'
            }
        }

        stage('Approval') {
            when { expression { params.ACTION == 'APPLY' && !params.AUTO_APPROVE } }
            steps {
                input message: 'Proceed with Terraform Apply?'
            }
        }

        stage('Terraform Apply') {
            when { expression { params.ACTION == 'APPLY' } }
            steps {
                dir('terraform') {
                    script {
                        if (params.AUTO_APPROVE) {
                            sh 'terraform apply -auto-approve tfplan'
                        } else {
                            sh 'terraform apply tfplan'
                        }
                    }
                }
            }
        }

        stage('Terraform Outputs') {
            when { expression { params.ACTION == 'APPLY' } }
            steps {
                dir('terraform') {
                    sh 'terraform output'
                }
            }
        }

        stage('Wait for SSH') {
            when { expression { params.ACTION == 'APPLY' } }
            steps {
                dir('terraform') {
                    sh '''
                        BASTION_IP=$(terraform output -raw bastion_public_ip)
                        echo "Waiting for SSH..."
                        for i in {1..30}; do
                            if nc -z $BASTION_IP 22; then
                                echo "SSH Ready"
                                exit 0
                            fi
                            echo "Retry $i..."
                            sleep 10
                        done
                        exit 1
                    '''
                }
            }
        }
       
        stage('Terraform Destroy') {
            when { expression { params.ACTION == 'DESTROY' } }
            steps {
                dir('terraform') {
                    script {
                        if (params.AUTO_APPROVE) {
                            sh 'terraform destroy -auto-approve'
                        } else {
                            sh 'terraform destroy'
                        }
                    }
                }
            }
        }

        stage('Ansible Inventory') {
            when { expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE } }
            steps {
                sshagent(credentials: ['ec2-key-one-click']) {
                    dir('ansible') {
                        sh 'ansible-inventory --graph'
                    }
                }
            }
        }

        stage('Ansible Ping') {
            when { expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE } }
            steps {
                sshagent(credentials: ['ec2-key-one-click']) {
                    dir('ansible') {
                        sh 'ansible all -m ping'
                    }
                }
            }
        }

        stage('Run Playbook') {
            when { expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE } }
            steps {
                sshagent(credentials: ['ec2-key-one-click']) {
                    dir('ansible') {
                        sh 'ansible-playbook playbooks/site.yml'
                    }
                }
            }
        }

        stage('Verify Services') {
            when { expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE } }
            steps {
                sshagent(credentials: ['ec2-key-one-click']) {
                    dir('ansible') {
                        sh '''
                            ansible monitoring -m shell -a "systemctl is-active prometheus"
                            ansible monitoring -m shell -a "systemctl is-active grafana-server"
                            ansible node_exporter -m shell -a "systemctl is-active node_exporter"
                        '''
                    }
                }
            }
        }
 stage('Copy PEM to Bastion') {

    when {
        expression {
            params.ACTION == 'APPLY'
        }
    }

    steps {

        dir('terraform') {

            script {

                def bastion = sh(
                    script: 'terraform output -raw bastion_public_ip',
                    returnStdout: true
                ).trim()

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-key-one-click',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {

                    sh """
                    echo "===================================================="
                    echo "        COPYING SSH KEY TO BASTION SERVER"
                    echo "===================================================="

                    ssh -i \$SSH_KEY \
                        -o StrictHostKeyChecking=no \
                        \$SSH_USER@${bastion} \
                        "rm -f ~/ansible-demo.pem"

                    scp -i \$SSH_KEY \
                        -o StrictHostKeyChecking=no \
                        \$SSH_KEY \
                        \$SSH_USER@${bastion}:/tmp/ansible-demo.pem

                    ssh -i \$SSH_KEY \
                        -o StrictHostKeyChecking=no \
                        \$SSH_USER@${bastion} <<EOF

mv /tmp/ansible-demo.pem ~/ansible-demo.pem
chmod 400 ~/ansible-demo.pem

echo
echo "===================================================="
echo "        SSH KEY COPIED SUCCESSFULLY"
echo "===================================================="
ls -l ~/ansible-demo.pem

EOF
                    """
                }

            }

        }

    }

}
        stage('Deployment Summary') {
            when { expression { params.ACTION == 'APPLY' } }
            steps {
                dir('terraform') {
                    script {
                        def bastion = sh(script: 'terraform output -raw bastion_public_ip', returnStdout: true).trim()
                        def monitoring = sh(script: 'terraform output -raw monitoring_private_ip', returnStdout: true).trim()
                        def app1 = sh(script: 'terraform output -raw app_server_1_private_ip', returnStdout: true).trim()
                        def app2 = sh(script: 'terraform output -raw app_server_2_private_ip', returnStdout: true).trim()

                        sh """
cat <<EOF

################################################################################
#                                                                              #
#                 🚀 ONE-CLICK MONITORING DEPLOYMENT SUCCESS 🚀                #
#                                                                              #
################################################################################

===============================================================================
                           DEPLOYMENT STATUS
===============================================================================

✔ Terraform Infrastructure      : SUCCESS
✔ Ansible Configuration         : SUCCESS
✔ Prometheus                    : DEPLOYED
✔ Grafana                       : DEPLOYED
✔ Node Exporter                 : DEPLOYED

===============================================================================
                         AWS INFRASTRUCTURE DETAILS
===============================================================================

Bastion Server
---------------
Public IP        : ${bastion}

Monitoring Server
-----------------
Private IP       : ${monitoring}

Application Server 1
--------------------
Private IP       : ${app1}

Application Server 2
--------------------
Private IP       : ${app2}

===============================================================================
                           ACCESS YOUR DASHBOARDS
===============================================================================

Grafana
--------
http://${bastion}/

Prometheus
----------
http://${bastion}/prometheus

===============================================================================
                         DEPLOYMENT INFORMATION
===============================================================================

Repository        : oneclick-monitoring-prometheus
Cloud Provider    : AWS
Provisioning      : Terraform
Configuration     : Ansible
CI/CD             : Jenkins
Monitoring Stack  : Prometheus + Grafana + Node Exporter

===============================================================================
                       🎉 DEPLOYMENT COMPLETED SUCCESSFULLY 🎉
===============================================================================

EOF
"""
                    }
                }
            }
        }
    }
}
