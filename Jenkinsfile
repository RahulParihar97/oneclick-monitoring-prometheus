pipeline {

    agent any

    options {
        ansiColor('xterm')
        timestamps()
    }

    stages {

        stage('Checkout') {

            steps {

                checkout scm

            }

        }

        stage('Verify Workspace') {

            steps {

                sh '''
                echo "Current Directory:"
                pwd

                echo ""

                echo "Repository Structure:"
                tree -L 2 || true

                echo ""

                git branch

                git status
                '''

            }

        }

    }

}
