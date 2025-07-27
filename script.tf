variable "aws_access_key" {
  description = "AWS access key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}


variable "cluster_name" {
  default = "kubik"
}
variable "region" {
  default = "eu-north-1"
}
variable "vpc_cidr" {
  default = "10.123.0.0/16"
}
variable "azs" {
  default = ["eu-north-1a", "eu-north-1b"]
}
variable "public_subnets" {
  default = ["10.123.1.0/24", "10.123.2.0/24"]
}
variable "private_subnets" {
  default = ["10.123.3.0/24", "10.123.4.0/24"]
}
variable "intra_subnets" {
  default = ["10.123.5.0/24", "10.123.6.0/24"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  intra_subnets   = var.intra_subnets

  enable_nat_gateway = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.1"

  cluster_name                   = var.cluster_name
  cluster_endpoint_public_access = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.medium"]
    attach_cluster_primary_security_group = true
  }

  eks_managed_node_groups = {
    ascode-cluster-wg = {
      min_size     = 2
      max_size     = 3
      desired_size = 2
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
    }
  }
}

data "aws_eks_cluster" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Create an EFS file system in the VPC
resource "aws_efs_file_system" "efs" {
  creation_token = "my-efs-file-system"
  performance_mode = "generalPurpose"
  encrypted        = true
  tags = {
    Name = "EFS-${var.cluster_name}"
  }
}

# Create mount targets for EFS in each private subnet
resource "aws_efs_mount_target" "efs_mount" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [module.eks.cluster_security_group_id]
}

# Create an access point for the EFS
resource "aws_efs_access_point" "efs_access_point" {
  file_system_id = aws_efs_file_system.efs.id
  root_directory {
    path = "/"
    creation_info {
      owner_uid = 1001
      owner_gid = 1001
      permissions = "750"
    }
  }
  tags = {
    Name = "EFS-AccessPoint-${var.cluster_name}"
  }
}

# Generate a YAML file for Kubernetes StorageClas

resource "local_file" "efs_storage_class" {
  content = <<-EOT
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: efs-sc
  provisioner: efs.csi.aws.com
  parameters:
    provisioningMode: efs-ap
    fsId: ${aws_efs_file_system.efs.id}
    accessPointId: ${aws_efs_access_point.efs_access_point.id}
  ---
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: efs-pv
  spec:
    capacity:
      storage: 5Gi
    volumeMode: Filesystem
    accessModes:
      - ReadWriteMany
    persistentVolumeReclaimPolicy: Retain
    storageClassName: efs-sc
    csi:
      driver: efs.csi.aws.com
      volumeHandle: ${aws_efs_file_system.efs.id}
    mountOptions:
      - nfsvers=4.1
  
  ---
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: postgres-pvc
    namespace: todo-app
  spec:
    accessModes:
      - ReadWriteMany
    storageClassName: efs-sc
    resources:
      requests:
        storage: 5Gi 
  
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: postgres
    namespace: todo-app
  spec:
    replicas: 1 
    selector:
      matchLabels:
        app: postgres
    template:
      metadata:
        labels:
          app: postgres
      spec:
        containers:
          - name: postgres
            image: postgres:13
            imagePullPolicy: Always
            env:
              - name: POSTGRES_DB
                value: "SoundScapeDb"
              - name: POSTGRES_USER
                value: "postgres"
              - name: POSTGRES_PASSWORD
                value: "123456"
            ports:
              - containerPort: 5432
            volumeMounts:
              - name: postgres-storage
                mountPath: /var/lib/postgresql/data
            livenessProbe:
              exec:
                command: ["pg_isready", "-U", "postgres"]
              initialDelaySeconds: 30
              periodSeconds: 10
            readinessProbe:
              exec:
                command: ["pg_isready", "-U", "postgres"]
              initialDelaySeconds: 10
              periodSeconds: 5
        volumes:
          - name: postgres-storage
            persistentVolumeClaim:
              claimName: postgres-pvc 
  
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: postgres
    namespace: todo-app
  spec:
    selector:
      app: postgres
    ports:
      - protocol: TCP
        port: 5432
        targetPort: 5432
  EOT
  filename = "postgres.yaml"
}

output "eks_cluster_endpoint" {
  value = data.aws_eks_cluster.eks.endpoint
}

output "efs_id" {
  value = aws_efs_file_system.efs.id
}

output "efs_access_point_id" {
  value = aws_efs_access_point.efs_access_point.id
}

output "efs_dns_name" {
  value = aws_efs_file_system.efs.dns_name
}

output "efs_storage_class_yaml" {
  value = local_file.efs_storage_class.filename
}
