# ERP 인프라 (Terraform)

**IaC 도구**: Terraform 1.6+  
**클라우드**: AWS  
**리전**: ap-northeast-2 (서울)  
**최종 업데이트**: 2025-12-10

---

## 📋 인프라 구성

### AWS 리소스

| 리소스 | 서비스 | 용도 |
|--------|--------|------|
| **VPC** | AWS VPC | 네트워크 격리 |
| **Subnet** | Public × 2, Private × 2 | Multi-AZ 배포 |
| **NAT Gateway** | 1개 | Private Subnet 인터넷 접근 |
| **Security Group** | 4개 | 서비스별 방화벽 |
| **EKS** | Kubernetes 1.31 | 컨테이너 오케스트레이션 |
| **RDS** | MySQL 8.0 | 직원 정보 DB |
| **ElastiCache** | Redis 7.0 | 캐시 및 알림 |
| **MongoDB** | Atlas M0 | 결재 요청 DB |
| **NLB** | Network Load Balancer | Layer 4 로드밸런싱 |
| **API Gateway** | HTTP API | 단일 진입점 |
| **S3** | Static Website | 프론트엔드 호스팅 |
| **CloudFront** | CDN | 전 세계 배포 |
| **ECR** | Container Registry | Docker 이미지 저장 |
| **CodePipeline** | CI/CD | 자동 배포 |

---

## 🏗️ Terraform 모듈 구조

```
infrastructure/terraform/dev/
├── erp-dev-VPC/                    # VPC, Subnet, Route Table
│   ├── vpc/
│   ├── subnet/
│   └── route-table/
├── erp-dev-SecurityGroups/         # Security Groups
│   ├── eks-sg/
│   ├── rds-sg/
│   ├── elasticache-sg/
│   └── alb-sg/
├── erp-dev-IAM/                    # IAM Roles
│   ├── eks-cluster-role/
│   ├── eks-node-role/
│   ├── codebuild-role/
│   └── codepipeline-role/
├── erp-dev-Databases/              # RDS, ElastiCache
│   ├── rds/
│   └── elasticache/
├── erp-dev-Secrets/                # Secrets Manager
├── erp-dev-EKS/                    # EKS Cluster
├── erp-dev-LoadBalancerController/ # AWS Load Balancer Controller
├── erp-dev-APIGateway/             # API Gateway, NLB
│   ├── nlb/
│   ├── target-groups/
│   ├── vpc-link/
│   └── api-gateway/
└── erp-dev-Frontend/               # S3, CloudFront
    ├── s3/
    └── cloudfront/
```

---

## 🚀 배포 순서

### 1. VPC 구성

```bash
cd infrastructure/terraform/dev/erp-dev-VPC

# VPC
cd vpc
terraform init
terraform apply -auto-approve

# Subnet
cd ../subnet
terraform init
terraform apply -auto-approve

# Route Table
cd ../route-table
terraform init
terraform apply -auto-approve
```

### 2. Security Groups

```bash
cd ../../erp-dev-SecurityGroups

cd eks-sg && terraform init && terraform apply -auto-approve
cd ../rds-sg && terraform init && terraform apply -auto-approve
cd ../elasticache-sg && terraform init && terraform apply -auto-approve
cd ../alb-sg && terraform init && terraform apply -auto-approve
```

### 3. IAM Roles

```bash
cd ../../erp-dev-IAM
terraform init
terraform apply -auto-approve
```

### 4. Databases

```bash
cd ../erp-dev-Databases

cd rds && terraform init && terraform apply -auto-approve
cd ../elasticache && terraform init && terraform apply -auto-approve
```

### 5. Secrets

```bash
cd ../../erp-dev-Secrets
terraform init
terraform apply -auto-approve
```

### 6. EKS Cluster

```bash
cd ../erp-dev-EKS
terraform init
terraform apply -auto-approve

# kubeconfig 설정
aws eks update-kubeconfig --name erp-dev --region ap-northeast-2
```

### 7. Load Balancer Controller

```bash
cd ../erp-dev-LoadBalancerController
terraform init
terraform apply -auto-approve
```

### 8. API Gateway

```bash
cd ../erp-dev-APIGateway
terraform init
terraform apply -auto-approve
```

### 9. Frontend

```bash
cd ../erp-dev-Frontend
terraform init
terraform apply -auto-approve
```

---

## 🔧 주요 설정

### VPC CIDR

```
VPC: 10.0.0.0/16
Public Subnet 1: 10.0.1.0/24 (ap-northeast-2a)
Public Subnet 2: 10.0.2.0/24 (ap-northeast-2c)
Private Subnet 1: 10.0.10.0/24 (ap-northeast-2a)
Private Subnet 2: 10.0.11.0/24 (ap-northeast-2c)
```

### EKS 설정

```hcl
cluster_name    = "erp-dev"
cluster_version = "1.31"
node_group_name = "erp-dev-nodes"
instance_types  = ["t3.small"]
desired_size    = 2
min_size        = 1
max_size        = 3
```

### RDS 설정

```hcl
engine               = "mysql"
engine_version       = "8.0"
instance_class       = "db.t3.micro"
allocated_storage    = 20
database_name        = "erp"
username             = "admin"
multi_az             = false
publicly_accessible  = false
```

---

## 💰 비용 분석

| 리소스 | 월 비용 |
|--------|---------|
| EKS Control Plane | $73.00 |
| Worker Nodes (t3.small × 2) | $30.00 |
| RDS (db.t3.micro) | $15.00 |
| ElastiCache (cache.t3.micro) | $12.00 |
| NAT Gateway | $32.00 |
| NLB | $16.00 |
| API Gateway | $3.50 |
| CloudFront | $1.00 |
| S3 | $0.50 |
| ECR | $1.00 |
| CodePipeline | $4.00 |
| CodeBuild | $2.00 |
| 기타 | $1.00 |
| **합계** | **$191.00** |

---

## 🐛 트러블슈팅

### Terraform State Lock

**문제**: `Error acquiring the state lock`

**해결**:
```bash
# DynamoDB Lock 테이블 확인
aws dynamodb scan --table-name terraform-lock --region ap-northeast-2

# 강제 unlock (주의!)
terraform force-unlock <lock-id>
```

### EKS 노드 생성 실패

**문제**: `Nodes not joining cluster`

**해결**:
```bash
# IAM Role 확인
aws iam get-role --role-name erp-dev-eks-node-role

# Security Group 확인
aws ec2 describe-security-groups --group-ids <sg-id>
```

### RDS 연결 실패

**문제**: `Could not connect to RDS`

**해결**:
```bash
# RDS 엔드포인트 확인
terraform output -state=erp-dev-Databases/rds/terraform.tfstate

# Security Group Ingress 규칙 확인
aws ec2 describe-security-groups --group-ids <rds-sg-id>
```

---

## 📚 참고 자료

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

---

## 📄 라이선스

MIT License
