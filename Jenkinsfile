pipeline {
    agent any
    
    triggers {
        // GitLab webhook trigger with secret token
        // The webhook URL will be: <JENKINS_URL>/project/<JOB_NAME>
        gitlab(
            triggerOnPush: true,
            triggerOnMergeRequest: true,
            branchFilterType: 'All',
            secretToken: "${env.WEBHOOK_SECRET}"
        )
    }
    
    environment {
        // Load webhook configuration from environment
        WEBHOOK_TARGET = "${env.WEBHOOK_TARGET}"
        WEBHOOK_SECRET = "${env.WEBHOOK_SECRET}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "Triggered by GitLab webhook"
                echo "Webhook Target: ${WEBHOOK_TARGET}"
                
                // Checkout code from GitLab
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                echo 'Building application...'
                // Add your build steps here
                sh '''
                    echo "Build stage executed"
                    # Example: ./gradlew build or npm install
                '''
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running tests...'
                // Add your test steps here
                sh '''
                    echo "Test stage executed"
                    # Example: ./gradlew test or npm test
                '''
            }
        }
        
        stage('Deploy') {
            steps {
                echo 'Deploying application...'
                // Add your deployment steps here
                sh '''
                    echo "Deploy stage executed"
                    # Example: kubectl apply -f deployment.yaml
                '''
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
            // Optional: Send notification to GitLab
            updateGitlabCommitStatus name: 'build', state: 'success'
        }
        failure {
            echo 'Pipeline failed!'
            // Optional: Send notification to GitLab
            updateGitlabCommitStatus name: 'build', state: 'failed'
        }
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
}
