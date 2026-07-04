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
        stage('Access Information') {

    when {
        expression {
            params.ACTION == 'APPLY'
        }
    }

    steps {

        dir('terraform') {

            script {

                def bastion = sh(
                    script: "terraform output -raw bastion_public_ip",
                    returnStdout: true
                ).trim()

                def monitoring = sh(
                    script: "terraform output -raw monitoring_private_ip",
                    returnStdout: true
                ).trim()

                echo """
========================================================

Infrastructure deployed successfully.

Run this command from your LOCAL machine:

ssh -i ~/oneclick-monitoring-prometheus/ansible/ansible-demo.pem \
    -J ubuntu@${bastion} \
    -L 9090:localhost:9090 \
    -L 3000:localhost:3000 \
    ubuntu@${monitoring}

Then open:

Prometheus:
http://localhost:9090

Grafana:
http://localhost:3000

========================================================
"""

            }

        }

    }

}
    }
}
