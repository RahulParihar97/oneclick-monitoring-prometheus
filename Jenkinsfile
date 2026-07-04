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
            steps {
                checkout scm
            }
        }
        stage('Terraform Init') {
            steps {
                dir('terraform') {
                                sh '''
                            terraform init
            '''
        }
    }
}
        stage('Terraform Format Check') {
    steps {
        dir('terraform') {
            sh '''
                terraform fmt -check -recursive
            '''
        }
    }
}
stage('Terraform Validate') {
    steps {
        dir('terraform') {
            sh '''
                terraform validate
            '''
        }
    }
}
        stage('Terraform Plan') {
    when {
        expression { params.ACTION == 'APPLY' }
    }

    steps {
        dir('terraform') {
            sh '''
                terraform plan -out=tfplan
            '''
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
        expression {
            params.ACTION == 'APPLY' && !params.AUTO_APPROVE
        }
    }

    steps {
        input message: 'Proceed with Terraform Apply?'
    }
}
stage('Terraform Apply') {

    when {
        expression {
            params.ACTION == 'APPLY'
        }
    }

    steps {

        dir('terraform') {

            script {

                if (params.AUTO_APPROVE) {

                    sh '''
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
    }
}
