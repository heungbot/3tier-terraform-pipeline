pipeline { 
    agent any
    environment {

        AWS_REGION = "ap-northeast-2"
        AWS_ACCOUNT_ID = credentials("AWS_ACCOUNT_ID")
        AWS_CONFIG = credentials("AWS_CREDENTIALS")
        ECR_REPO_NAME = "heungbot_pipeline"
        BACKEND_IMAGE_NAME = "backend"
        GIT_REPOSITORY_URL = "https://github.com/heungbot/jenkins-terraform-pipeline.git"
        TARGET_BRANCH = "main"
    }
    
    stages {
        stage('CLONE PROJECT FROM GITHUB') {
            steps {
                git url: "${GIT_REPOSITORY_URL}",
                    branch: "${TARGET_BRANCH}"
                sh "ls -al && pwd"
            }
        }
        
        stage("INITIALIZING DAEMON & TERRAFORM") {
            steps {
                dir("${env.WORKSPACE}/terraform_module") {
                    sh """
                    aws --version &&
                    docker --version && 
                    cd ../frontend/; npm install &&
                    terraform --version &&
                    echo "${env.WORKSPACE}" &&
                    cd ../terraform_module && terraform init
                    """
                }
            }
        }

        ///////////////////////// BASE ARCHITECTURE(VPC S3 CLOUDFRONT) /////////////////////////
        stage ('TERRAFORM PLAN BASE & FRONTEND MODULE') {
            steps {
                dir("${env.WORKSPACE}/terraform_module") {
                    sh """
                    terraform plan --target=module.heungbot-base --target=module.heungbot-ecr --target=module.heungbot-iam\
                    -var "BUILD_NUMBER=${env.BUILD_NUMBER}" \
                    -var "BACKEND_IMAGE=NO" \
                    -var JENKINS_WORKSPACE_PATH=${env.WORKSPACE}
                    """
                }
            } // heugnbot-base module이 가장 먼저 실행되며, frontend <-> backend 사이의 연동할 ALB URL을 frontend/.env 파일에 넘겨줌
            post {
                success {
                    echo 'BASE MODULE PLAN SUCCESS'
                    slackSend (
                        channel: '#heungbot_pipeline', 
                        color: '#FF0000', 
                        message: """
                        BASE PLAN SUCCESS
                        BUILD FAIL: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )
                }
                failure {
                    echo "FAILED TERRAFORM PLAN"
                    slackSend (
                        channel: '#heungbot_pipeline', 
                        color: '#FF0000', 
                        message: """
                        BASE PLAN FAILED
                        BUILD FAIL: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )

                }
            }
        }

        stage ('TERRAFORM APPLY BASE & FRONTEND MODULE') {
            steps {
                dir("${env.WORKSPACE}/terraform_module") {
                    sh """
                    terraform apply -auto-approve --target=module.heungbot-base --target=module.heungbot-ecr --target=module.heungbot-iam --target=module.heungbot-frontend\
                    -var "BUILD_NUMBER=${env.BUILD_NUMBER}" \
                    -var "BACKEND_IMAGE=NO" \
                    -var "JENKINS_WORKSPACE_PATH=${env.WORKSPACE}"
                    """
                }
            }
            post {
                success {
                    echo "TERRAFORM APPLY ABOUT BASE AND FRONTEND IS SUCCESS"
                    slackSend(
                        channel: '#heungbot_pipeline',
                        color: '#00FF00',
                        message: """ 
                        BASE AND FRONTEND APPLY SUCCESS
                        Job: ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )
                }
                failure {
                    echo "TERRAFORM APPLY ABOUT BASE AND FRONTEND IS FAILED"
                    slackSend (
                        channel: '#heungbot_pipeline', 
                        color: '#FF0000', 
                        message: """
                        BASE AND FRONTEND APPLY FAILED
                        CHECK YOUR TERRAFORM BASE CONFIG
                        BUILD FAIL: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )
                }
            }
        }  

        

        stage("SET VARIABLE AND ECR LOGIN") {
            steps {
                sh """                    
                    ECR_REPOSITORY_URL=\$(terraform output -raw ECR_REPOSITORY_URL);
                    MAIN_BUCKET_NAME=\$(terraform output -raw MAIN_BUCKET_NAME);
                    aws ecr get-login-password --region \${AWS_REGION} | docker login --username AWS --password-stdin \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com
                """
            }
        }

        stage('FRONTEND CODE TEST') {
            steps {
                dir("${env.WORKSPACE}/frontend") {
                    sh "npm run test"
                }
            }
            post {
                success {
                    echo "NPM RUN TEST SUCCESS"
                }
                failure {
                    error "NPM RUN TEST FAILED"
                }
            }
        }

        stage('FRONTEND CODE BUILD AND PUSH') {
            steps {
                dir("${env.WORKSPACE}/frontend") {
                    sh """
                    npm run build;
                    echo "PUSH CODE TO ORIGIN BUCKET";
                    aws s3 sync ./build s3://${env.MAIN_BUCKET_NAME}
                    """
                }
            }
            post {
                success {
                    echo "BUILD AND PUSHED"
                }
                failure {
                    error "SOMETHING WORING IN BUILD STAGE"
                }
            }
        }

        stage('TERRAFORM APPLY ABOUT OAC AND AURORA MODULE') { // aurora endpoint backend image build 전에 넘겨줌
            steps {
                dir("${env.WORKSPACE}/terraform_module") {
                    sh """
                    terraform apply -auto-approve --target=module.heungbot-oac --target=module.heungbot-aurora \
                    -var "BUILD_NUMBER=${env.BUILD_NUMBER}" \
                    -var "BACKEND_IMAGE=NO" \
                    -var "JENKINS_WORKSPACE_PATH=${env.WORKSPACE}"
                    """
                }
            }
            post {
                success {
                    echo "OAC AND AURORA MODULE APPLIED"
                }
                failure {
                    error "SOMETHINE WRONG IN heungbot-oac or heungbot-auroraMODULE"
                }
            }
        }

        ///////////////////////// BACKEND /////////////////////////
        stage('BACKEND IMAGE BUILD') {
            steps {
                dir("${env.WORKSPACE}/backend") {
                    echo 'Building the backend'
                    sh "docker build -t ${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} ."
                }
            }
            post {
                success {
                    echo "Backend build succeeded"
                    slackSend(
                        channel: '#heungbot_pipeline',
                        color: '#00FF00',
                        message: """ 
                        BACKEND IMAGE BUILD SUCCESS
                        Job: ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )
                }
                failure {
                    echo "Backend build failed"
                    slackSend(
                        channel: '#heungbot_pipeline',
                        color: '#FF0000',
                        message: """
                        BACKEND IMAGE BUILD FAILED
                        BUILD FAIL: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )
                }
            }
        }

        stage('PUSH BACKEND IMAGE') {
            steps {
                echo 'Tag and push the backend image to ECR'
                dir("${env.WORKSPACE}/backend") {
                    sh"""
                    docker tag ${BACKEND_IMAGE_NAME}:${env.BUILD_NUMBER} ${env.ECR_REPOSITORY_URL}:${BACKEND_IMAGE_NAME}_${env.BUILD_NUMBER} &&
                    docker push ${env.ECR_REPOSITORY_URL}:${BACKEND_IMAGE_NAME}_${env.BUILD_NUMBER} &&
                    docker rmi ${env.ECR_REPOSITORY_URL}:${BACKEND_IMAGE_NAME}_${env.BUILD_NUMBER}
                    """
                }
            }
            post {
                success {
                    echo "BACKEND IMAGE PUSHED SUCCESSFULLY"
                    slackSend(
                        channel: '#heungbot_pipeline',
                        color: '#00FF00',
                        message: """ 
                        BACKEND IMAGE PUSH SUCCESS
                        Job: ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )
                }
                failure {
                    echo "FAILED BACKEND IMAGE PUSHING"
                    slackSend(
                        channel: '#heungbot_pipeline',
                        color: '#FF0000',
                        message: """
                        BACKEND IMAGE PUSH FAILED
                        BUILD FAIL: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )
                }
            }
        }

        
        stage ('TERRAFORM PLAN ABOUT BACKEND') { 
            steps {
                dir("${env.WORKSPACE}/terraform_module") {
                    sh """
                    terraform plan --target=module.heungbot-base --target=module.heungbot-ecr --target=module.heungbot-iam --target=module.heungbot-backend-ecs \
                    -var "BUILD_NUMBER=${env.BUILD_NUMBER}" \
                    -var "BACKEND_IMAGE=${env.ECR_REPOSITORY_URL}:${BACKEND_IMAGE_NAME}_${env.BUILD_NUMBER}" \
                    -var "JENKINS_WORKSPACE_PATH=${env.WORKSPACE}"
                    """
                }
            }
            post {
                success {
                    echo 'TERRAFORM PLAN ABOUT BACKEND MODULE IS SUCCESS'
                    slackSend (
                        channel: '#heungbot_pipeline', 
                        color: '#FF0000', 
                        message: """
                        BACKEND PLAN SUCCESS
                        BUILD FAIL: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )
                }
                failure {
                    echo "FAILED TERRAFORM PLAN"
                    slackSend (
                        channel: '#heungbot_pipeline', 
                        color: '#FF0000', 
                        message: """
                        BACKEND PLAN FAILED
                        BUILD FAIL: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )

                }
            }
        }
        
        // ECS Cluster Launch && Update
        stage ('TERRAFORM APPLY ABOUT BACKEND MODULE') {
            steps {
                dir("${env.WORKSPACE}/terraform_module") {
                    sh """
                    terraform apply -auto-approve --target=module.backend-ecs \
                    -var "BUILD_NUMBER=${env.BUILD_NUMBER}" \
                    -var "BACKEND_IMAGE=${env.ECR_REPOSITORY_URL}:${BACKEND_IMAGE_NAME}_${env.BUILD_NUMBER}" \
                    -var "JENKINS_WORKSPACE_PATH=${env.WORKSPACE}"
                    """
                }
            }
            post {
                success {
                    echo "TERRAFORM APPLY ABOUT BACKEND IS SUCCESS"
                    slackSend(
                        channel: '#heungbot_pipeline',
                        color: '#00FF00',
                        message: """ 
                        3-TIER ARCH TERRAFORM APPLY DONE
                        Job: ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )
                }
                failure {
                    echo "TERRAFORM APPLY ABOUT BACKEND IS FAILED"
                    slackSend (
                        channel: '#heungbot_pipeline', 
                        color: '#FF0000', 
                        message: """
                        CHECK YOUR TERRAFORM BACKEND CONFIG
                        BUILD FAIL: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                        """
                    )
                }
            }
        }
        stage ('CLEAN UP') {
            steps {
                cleanWs()
            }
        }
    }
}




        // stage('SSH transfer') {
        //     steps {
        //         script {
        //         sshPublisher(
        //         continueOnError: false, failOnError: true,
        //         publishers: [
        //             sshPublisherDesc(
        //             configName: "${env.ANSIBLE_CONFIG_NAME}",
        //             verbose: true,
        //             transfers: [
        //             sshTransfer(
        //             sourceFiles: "$PATH_TO_FILE/$FILE_NAME",
        //             removePrefix: "$PATH_TO_FILE",
        //             remoteDirectory: "$REMOTE_DIR_PATH",

        //             // execCommand: "echo 'hello' > ansible.txt "ansible.txt = ansible server의 ansadmin's home dir 복사됨. 
        //             // BUT webapp.war file = REMOTE_DIR_PATH에 잘 복사됨.
        //             // Jenkins Server에서 Ansible server로 artifact 파일을 복사했기 때문에, ansible-server에서도 $BUILD_NUMBER 라는 parameter를 사용할 수 있음.

        //             // 또한 hub.docker.com push 하는 것 보다, ECR로 push하자. ansible-server의 적절한 권한 주는 것도 잊지 말자.
        //             execCommand: '''ansible-playbook /opt/docker/playbook/image_manage_playbook.yml; \
        //                             sleep 3; \
        //                             ansible-playbook /opt/docker/playbook/image_deploy_playbook.yml; \
        //                             sleep 3; '''
        //                     )
        //                 ])
        //             ])
        //         }
        //     }
            
        //     post {
        //         success {
        //             echo "SUCCESS SSH transfer stage"
        //             slackSend(
        //                 channel: "#heungbot_pipeline",
        //                 color: "#00FF00",
        //                 message: """ 
        //                 SUCCESS: Job: ${env.JOB_NAME} [${env.BUILD_NUMBER}]
        //                 [TEST URL: http://${WEBAPP_PUBLIC_IP}:8100]
        //                 """
        //             )
        //         }
        //         failure {
        //             echo "FAIL WRITE CONFIG AGAIN"
        //             slackSend (
        //                 channel: "#heungbot_pipeline", 
        //                 color: "#FF0000", 
        //                 message: "FAIL: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}]"
        //             )
        //         }
        //     }
        // }


// <Error>
// Plan requires configuration to be present. 
// Planning without a configuration would mark everything for destruction, which is normally not what isdesired. 
// If you would like to destroy everything, run plan with the-destroy option. 
// Otherwise, create a Terraform configuration file (.tffile) and try again.