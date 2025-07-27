pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_KEY')
        AWS_DEFAULT_REGION = 'eu-north-1'
        API_TOKEN = credentials('API_TOKEN')
        ZONE_ID = credentials('ZONE_ID')
        SONARQUBE_TOKEN = credentials('SONARQUBE_TOKEN')
        GITHUB_TOKEN = credentials('GITHUB_TOKEN')
        TELEGRAM_BOT_TOKEN = credentials('TELEGRAM_BOT_TOKEN')
        TELEGRAM_CHAT_ID = credentials('TELEGRAM_CHAT_ID')
        CERT_PATH = "${WORKSPACE}/certificates"
    }

    stages {

        stage('Clean Workspace') {
            steps {
                deleteDir()
            }
        }
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'git@github.com:oksesaneka22/kubiks.git'
            }
        }


        stage('Clone git') {
            parallel {
                stage('Build Backend') {
                    steps {
                        script {
                            sh 'git clone https://github.com/Kholod13/SoundScape.git --branch main Back'
                        }
                    }
                }
                stage('Build Frontend') {
                    steps {
                        script {
                            sh 'git clone https://github.com/Kholod13/SoundScape_frontend.git --branch main Front'
                        }
                    }
                }
            }
            post {
                success {
                    echo 'Clone succeed.'
                }
                failure {
                    error 'Failure!'
                }
            }
        }



        stage('Set up files') {
            steps {
                script {
                    sh 'mkdir -p $CERT_PATH'

                    // Load the certificate from Jenkins credentials
                    withCredentials([certificate(credentialsId: 'CERT', keystoreVariable: 'CERT_FILE')]) {
                        sh '''
                        # Extract private key
                        openssl pkcs12 -in "$CERT_FILE" -nocerts -nodes -passin pass: | \
                        awk '/-----BEGIN PRIVATE KEY-----/,/-----END PRIVATE KEY-----/' > "$CERT_PATH/private.pem"
                        
                        # Extract certificate and remove bag attributes
                        openssl pkcs12 -in "$CERT_FILE" -clcerts -nokeys -passin pass: | \
                        awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' > "$CERT_PATH/origin.pem"
                        '''
                    }
                    sh '''  
                        mv Dockerfile-back ./Back/Dockerfile
                        mv Dockerfile-front ./Front/Dockerfile
                        mv default.conf ./Front/default.conf
                        mv sonar-project.properties ./Front/sonar-project.properties
                        cp $CERT_PATH/origin.pem ./Front/origin.pem
                        cp $CERT_PATH/private.pem ./Front/private.pem
                        cp $CERT_PATH/origin.pem ./Back/origin.pem
                        cp $CERT_PATH/private.pem ./Back/private.pem
                    '''
                }
            }
        }

        stage('SonarQube Analysis Back') {
            steps {
                script {
                    def scannerHome = tool 'sonar-scanner'
                    withSonarQubeEnv() {
                      sh "cd Back && dotnet ${scannerHome}/SonarScanner.MSBuild.dll begin /k:\"Soundscape-back\""
                      sh "cd Back && dotnet build"
                      sh "cd Back && dotnet ${scannerHome}/SonarScanner.MSBuild.dll end"}
                      sh 'python3 Python/issues-back.py'
                }
            }
        }

        stage('SonarQube Analysis Front') {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner';
                    withSonarQubeEnv() {
                        sh "cd Front && ${scannerHome}/bin/sonar-scanner"
                        sh 'python3 Python/issues-front.py'
                    }
                }
            }
        }

        stage('Docker Build & Push') {
            parallel {
                stage('Build Backend') {
                    steps {
                        script {
                            sh 'docker build -t oksesaneka22/backend:latest ./Back'
                        }
                    }
                }
                stage('Build Frontend') {
                    steps {
                        script {
                            sh 'docker build -t oksesaneka22/frontend:latest ./Front'
                        }
                    }
                }
            }

            post {
                success {
                    echo 'Docker images built successfully.'
                }
                failure {
                    error 'Docker build failed!'
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                script {
                    sh 'docker push oksesaneka22/backend:latest'
                    sh 'docker push oksesaneka22/frontend:latest'
                }
            }
        }

        stage('Terraform Deployment') {
            steps {
                script {
                    sh '''
                        terraform init -upgrade
                        terraform plan -var="aws_access_key=${AWS_ACCESS_KEY}" -var="aws_secret_key=${AWS_SECRET_KEY}"
                        terraform apply -auto-approve -parallelism=10 -var="aws_access_key=${AWS_ACCESS_KEY}" -var="aws_secret_key=${AWS_SECRET_KEY}"
                        aws eks create-access-entry --cluster-name kubik --principal-arn arn:aws:iam::314146310055:root --region eu-north-1
                        aws eks associate-access-policy --cluster-name kubik --principal-arn arn:aws:iam::314146310055:root --access-scope type=cluster --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy
                        aws eks associate-access-policy --cluster-name kubik --principal-arn arn:aws:iam::314146310055:root --access-scope type=cluster --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy
                        aws eks associate-access-policy --cluster-name kubik --principal-arn arn:aws:iam::314146310055:root --access-scope type=cluster --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
                    '''
                }
            }
        }

        stage('Giving access') {
            steps {
                script {
                    sh '''
                        aws eks update-kubeconfig --region eu-north-1 --name kubik
                        sleep 30
                    '''
                    def roleName = sh(script: "aws eks describe-cluster --name kubik --query 'cluster.roleArn' --output text | awk -F'/' '{print \$2}'", returnStdout: true).trim()
                    echo "Detected IAM Role: ${roleName}"
                    sh "aws iam attach-role-policy --role-name ${roleName} --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess"
                    sh "aws iam attach-role-policy --role-name ${roleName} --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess"
                    sh 'sudo bash Scripts/s3role.sh'
                    sh '''
                        sudo aws eks update-kubeconfig --region eu-north-1 --name kubik --verbose
                        aws eks update-kubeconfig --region eu-north-1 --name kubik --verbose
                        sleep 10
                        sudo aws eks update-kubeconfig --region eu-north-1 --name kubik
                        sudo kubectl get nodes
                        sleep 10
                        aws eks update-kubeconfig --region eu-north-1 --name kubik
                        sleep 10
                    '''
                }
            }
        }

        stage('Deploy Services'){
            steps {
                script {
                    sh '''
                    sudo kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable?ref=master"
                    sudo kubectl create namespace todo-app
                    sudo kubectl create secret generic telegram-secret --from-literal=bot-token=$TELEGRAM_BOT_TOKEN --from-literal=chat-id=$TELEGRAM_CHAT_ID
                    sudo kubectl create secret generic aws-secret --namespace=todo-app --from-literal=access-key-id=$AWS_ACCESS_KEY_ID --from-literal=secret-access-key=$AWS_SECRET_ACCESS_KEY
                    sudo kubectl apply -f postgres.yaml
                    sudo kubectl apply -f Services/backend.yaml
                    sudo kubectl apply -f Services/frontend.yaml
                    '''
                }
            }
        }

        stage('Add DNS records to Cloudflare') {
            steps {
                script {
                    sh '''
                    sleep 10
                    sudo bash Scripts/rmsg.sh
                    sleep 300
                    sudo kubectl delete svc frontend backend -n todo-app
                    sudo kubectl apply -f Services/frontend.yaml
                    sudo kubectl apply -f Services/backend.yaml
                    sleep 240
                    sudo kubectl delete svc frontend backend -n todo-app
                    sudo kubectl apply -f Services/frontend.yaml
                    sudo kubectl apply -f Services/backend.yaml
                    sleep 180
                    bash Scripts/dns.sh
                    sudo kubectl apply -f Services/backup.yaml
                    sudo kubectl delete pods -l app=backend -n todo-app
                    '''
                }
            }
        }

        stage('Monitoring Setup') {
            steps {
                script {
                    sh '''
                    sudo helm repo add grafana https://grafana.github.io/helm-charts
                    sudo helm repo update
                    sudo helm upgrade --install --version ^2 --atomic --timeout 400s grafana-k8s-monitoring grafana/k8s-monitoring --namespace "default" --create-namespace -f values.yaml
                    '''
                }
            }
        }

        // stage('Local in cluster Monitoring Setup') {
        //     steps {
        //         script {
        //             sh 'sudo helm repo add prometheus-community https://prometheus-community.github.io/helm-charts'
        //             sh 'sudo helm repo update'
        //             sh 'sudo helm install kube-prometheus prometheus-community/kube-prometheus-stack -f values.yaml'
        //             sh 'export POD_NAME=$(sudo kubectl --namespace default get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=kube-prometheus" -oname)'
        //             sh 'echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
        //             sh 'echo PASSWORD:'
        //             sh 'sudo kubectl --namespace default get secrets kube-prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo'
        //             sh 'echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
        //             sh 'sudo kubectl --namespace default --address 0.0.0.0 port-forward $POD_NAME 3000:3000'
        //         }
        //     }
        // }
        stage('Docker rm') {
            steps {
                script {
                    sh 'docker rmi oksesaneka22/frontend:latest'
                    sh 'docker rmi oksesaneka22/backend:latest'
                }
            }
        }
    }

    post {
        success {
            script {
                sh 'python3 Python/jenkins_success.py'
            }
        }
        failure {
            script {
                sh 'python3 Python/jenkins_failure.py'
            }
        }
    }
}
