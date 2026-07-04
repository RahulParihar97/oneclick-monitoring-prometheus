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
