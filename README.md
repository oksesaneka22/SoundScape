# **Soundscape Infrastructure** 🚀  
⭐ Star me on GitHub!
![Docker backend Pulls](https://img.shields.io/docker/pulls/oksesaneka22/backend)
[![Soundscape](https://raw.githubusercontent.com/oksesaneka22/script/refs/heads/main/banner.svg)](https://soundscape.co.ua)

## **Overview**  
This project deploys a **full-stack web application** with **backend, frontend, database, and CI/CD automation** using **Kubernetes, Terraform, Jenkins, Docker, AWS, and SonarQube**.  

- **CI/CD**: Jenkins automates the build, test, and deployment pipelines.  
- **Containerization**: Docker is used for packaging backend and frontend services.  
- **Orchestration**: Kubernetes manages the deployment using blue-green deployment strategies.  
- **Infrastructure as Code (IaC)**: Terraform provisions AWS infrastructure (EKS, EFS, networking).  
- **Monitoring**: Prometheus & Grafana monitor system health.  
- **Security & Automation**: Secrets stored securely, automated DNS updates via Cloudflare, AWS IAM roles configured.  

---

## **Directory Structure** 🗂  
```
./kubiks
│── Python/
│   ├── error_alert.py        # Sends error alerts via Telegram
│   ├── issues-back.py        # Fetches SonarQube issues for backend
│   ├── issues-front.py       # Fetches SonarQube issues for frontend
│   ├── jenkins_failure.py    # Notifies on Jenkins pipeline failure
│   ├── jenkins_success.py    # Notifies on Jenkins pipeline success
│   ├── telegram.py           # Sends deployment status messages
│
│── Scripts/
│   ├── dns.sh                # Automates DNS updates with Cloudflare
│   ├── restore.sh            # Restores PostgreSQL database from S3
│   ├── rmsg.sh               # AWS Security Group Fix for EKS
│   ├── s3role.sh             # AWS IAM role setup for S3 access
│
│── Services/
│   ├── backend-blue.yaml     # Backend Blue deployment
│   ├── backend-green.yaml    # Backend Green deployment
│   ├── backend.yaml          # Backend service configuration
│   ├── backup.yaml           # Kubernetes CronJob for database backup
│   ├── frontend-blue.yaml    # Frontend Blue deployment
│   ├── frontend-green.yaml   # Frontend Green deployment
│   ├── frontend.yaml         # Frontend service configuration
│
│── default.conf              # Nginx configuration
│── docker-compose.yaml       # Local Docker environment setup
│── Dockerfile-back           # Backend Docker image build
│── Dockerfile-front          # Frontend Docker image build
│── Jenkinsfile               # Main CI/CD pipeline
│── Jenkinsfile-back          # Backend CI/CD pipeline
│── Jenkinsfile-front         # Frontend CI/CD pipeline
│── README.md                 # Project documentation
│── script.tf                 # Terraform AWS infrastructure setup
│── sonar-project.properties  # SonarQube project config
│── values.yaml               # Helm configuration for Prometheus & Grafana
```

---

## **CI/CD Pipelines** 🔄  
### **Backend Pipeline (Jenkinsfile-back)**  
This pipeline automates the build, testing, and deployment of the **backend service** using **blue-green deployment**.  

### **Frontend Pipeline (Jenkinsfile-front)**  
This pipeline builds, tests, and deploys the **frontend service** using **blue-green deployment**.  

### **Pipeline Workflow Visualization**  

<p align="center">
  <img src="https://github.com/user-attachments/assets/75ec31c4-d6b1-4ebb-9576-c3605f67ccc6" alt="Image description">
</p>

---

### **Pipeline Breakdown**  
1️⃣ **Clone Code**: Jenkins fetches code from GitHub.  
2️⃣ **Static Code Analysis**: SonarQube scans for issues.  
3️⃣ **Build & Push Docker Image**: Backend & frontend images pushed to **DockerHub**.  
4️⃣ **Blue-Green Deployment**:   
   4.1️⃣- Detects which version (blue/green) is currently running.  
   4.2️⃣- Deploys the **new version** (opposite of active one).  
   4.3️⃣- Deletes the old version after successful deployment.   
5️⃣ **Kubernetes Deployment**: Updates Kubernetes services.  
6️⃣ **DNS Automation**: Cloudflare updates to route traffic.  
7️⃣ **Monitoring Setup**: Prometheus & Grafana configured.  
8️⃣ **Alerts & Notifications**: Sends success/failure messages via Slack/Telegram.  

---

## **How Blue-Green Deployment Works?** 🔁  
1. Two versions of the app exist: **Blue** & **Green**.  
2. At any given time, only one version is active.  
3. New deployments go to the **inactive** version.  
4. If everything is fine, traffic switches to the new version.  
5. Old version is deleted after a successful switch.  

---

## **Monitoring & Logs** 📊  
- **Grafana**: Web-based dashboard for monitoring system health.  
- **Prometheus**: Collects and visualizes metrics.  
- **Slack/Telegram Alerts**: Instant notifications on failures.  

---

## **Infrastructure Deployment**  
The Terraform script provisions:  
✅ **AWS EKS Cluster** (for Kubernetes)  
✅ **AWS EFS Storage** (for persistent database storage)  
✅ **AWS IAM Roles** (for security policies)  
✅ **Networking (VPC, subnets, security groups)**  

To deploy, run:  
<details><summary><b><span style="color:red;">❗SHOW INSTRUCTION❗</span></b></summary>

1. Install Docker:

    ```sh
    wget https://oksesaneka22.github.io/script/docker.sh && bash docker.sh 
    ```

2. Install AWS-cli, Terraform, kubectl, python3:
3. Follow commands from Jenkinsfile:

    ```sh
    wget https://oksesaneka22.github.io/script/docker.sh && bash docker.sh
    git clone https://github.com/Kholod13/SoundScape.git --branch main Back
    git clone https://github.com/Kholod13/SoundScape_frontend.git --branch main Front
    ```

4.Copy your certificates to folder:

    ```sh
    mv Dockerfile-back ./Back/Dockerfile
    mv Dockerfile-front ./Front/Dockerfile
    mv default.conf ./Front/default.conf
    mv sonar-project.properties ./Front/sonar-project.properties
    cp $CERT_PATH/origin.pem ./Front/origin.pem
    cp $CERT_PATH/private.pem ./Front/private.pem
    cp $CERT_PATH/origin.pem ./Back/origin.pem
    cp $CERT_PATH/private.pem ./Back/private.pem
    ```

5.Build and push docker images(change your docker-user):

    ```sh
    docker build -t <docker-user>/backend:latest ./Back
    docker build -t <docker-user>/frontend:latest ./Front
    docker push <docker-user>/backend:latest
    docker push <docker-user>/frontend:latest
    ```

6.Deploy AWS cluster(change variables for your keys)(change aws-accout-id and cluster-name):

    ```sh
    terraform init -upgrade
    terraform plan -var="aws_access_key=${AWS_ACCESS_KEY}" -var="aws_secret_key=${AWS_SECRET_KEY}"
    terraform apply -auto-approve -parallelism=10 -var="aws_access_key=${AWS_ACCESS_KEY}" -var="aws_secret_key=${AWS_SECRET_KEY}"
    aws eks create-access-entry --cluster-name <cluster-name> --principal-arn arn:aws:iam::<aws-account-id>:root --region eu-north-1
    aws eks associate-access-policy --cluster-name <cluster-name> --principal-arn arn:aws:iam::<aws-account-id>:root --access-scope type=cluster --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy
    aws eks associate-access-policy --cluster-name <cluster-name> --principal-arn arn:aws:iam::<aws-account-id>:root --access-scope type=cluster --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy
    aws eks associate-access-policy --cluster-name <cluster-name> --principal-arn arn:aws:iam::<aws-account-id>:root --access-scope type=cluster --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
    ```

7.Kubernetes deployment(change with your role-name that will be outputed, also change in scripts your creds)!Change serivce files for your configuration:

    ```sh
    aws eks update-kubeconfig --region eu-north-1 --name <cluster-name>
    aws eks describe-cluster --name kubik --query 'cluster.roleArn' --output text
    aws iam attach-role-policy --role-name ${roleName} --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
    aws iam attach-role-policy --role-name ${roleName} --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
    sudo bash Scripts/s3role.sh
    sudo aws eks update-kubeconfig --region eu-north-1 --name kubik --verbose
    sudo kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable?ref=master"
    sudo kubectl create namespace todo-app
    sudo kubectl create secret generic telegram-secret --from-literal=bot-token=$TELEGRAM_BOT_TOKEN --from-literal=chat-id=$TELEGRAM_CHAT_ID
    sudo kubectl create secret generic aws-secret --namespace=todo-app --from-literal=access-key-id=$AWS_ACCESS_KEY_ID --from-literal=secret-access-key=$AWS_SECRET_ACCESS_KEY
    sudo kubectl apply -f postgres.yaml
    sudo kubectl apply -f Services/backend.yaml
    sudo kubectl apply -f Services/frontend.yaml
    !Wait few seconds!
    sudo bash Scripts/rmsg.sh
    sudo kubectl delete svc frontend backend -n todo-app
    sudo kubectl apply -f Services/frontend.yaml
    sudo kubectl apply -f Services/backend.yaml
    !Wait 5 minutes or check kubectl get svc -n todo-app for active dns!
    sudo bash Scripts/dns.sh
    sudo kubectl apply -f Services/backup.yaml
    sudo kubectl delete pods -l app=backend -n todo-app
    ```

8.Monitoring setup(login to grafanacloud online and add kubernetes cluster and from there change values.yaml):

    ```sh
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    helm upgrade --install --version ^2 --atomic --timeout 400s grafana-k8s-monitoring grafana/k8s-monitoring --namespace "default" --create-namespace -f values.yaml
    ```

</details>

## **If successfull Star me on github⭐**

---

## **Local Development**  
For local testing, use Docker(add your certs and change ports for backend):  
```sh
docker-compose up --build
```

---
**Special Thanks to  Bugay Volodimir For fast fixes**
