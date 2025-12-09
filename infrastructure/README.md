# ERP 프로젝트 Terraform 인프라

## 디렉토리 구조

```
terraform/dev/
├── erp-dev-VPC/              # VPC, Subnet, Route Table (세분화)
├── erp-dev-SecurityGroups/   # Security Groups (세분화)
├── erp-dev-IAM/              # IAM Roles (통합)
├── erp-dev-Databases/        # RDS, ElastiCache (세분화)
├── erp-dev-EKS/              # EKS Cluster (통합)
├── erp-dev-ALB/              # Application Load Balancer (통합)
└── erp-dev-Secrets/          # Secrets Manager (통합)
```

## 실행 순서

### 1. 환경변수 설정

```bash
export TF_VAR_mysql_password="your-password"
```

### 2. VPC

```bash
cd terraform/dev/erp-dev-VPC
cd vpc && terraform init && terraform apply
cd ../subnet && terraform init && terraform apply
cd ../route-table && terraform init && terraform apply
```

### 3. SecurityGroups

```bash
cd ../../erp-dev-SecurityGroups
cd alb-sg && terraform init && terraform apply
cd ../eks-sg && terraform init && terraform apply
cd ../rds-sg && terraform init && terraform apply
cd ../elasticache-sg && terraform init && terraform apply
```

### 4. IAM

```bash
cd ../../erp-dev-IAM
terraform init && terraform apply
```

### 5. Databases

```bash
cd ../erp-dev-Databases
cd rds && terraform init && terraform apply
cd ../elasticache && terraform init && terraform apply
```

### 6. EKS

```bash
cd ../../erp-dev-EKS
terraform init && terraform apply
```

### 7. ALB

```bash
cd ../erp-dev-ALB
terraform init && terraform apply
```

### 8. Secrets

```bash
cd ../erp-dev-Secrets
terraform init && terraform apply
```

## 배포된 리소스

| 리소스 | 개수 | 설명 |
|--------|------|------|
| VPC | 19 | VPC, Subnet, Route Table, NAT Gateway |
| SecurityGroups | 11 | ALB, EKS, RDS, ElastiCache SG |
| IAM | 13 | EKS Cluster Role, Node Role, CodeBuild Role |
| Databases | 8 | RDS MySQL, ElastiCache Redis |
| EKS | 6 | EKS Cluster, Node Group |
| ALB | 13 | ALB, Target Groups, Listener Rules |
| Secrets | 4 | Secrets Manager (MySQL 자격증명) |
| **총합** | **74개** | |

## 인프라 삭제 (역순)

```bash
cd terraform/dev

# Secrets
cd erp-dev-Secrets && terraform destroy -auto-approve

# ALB
cd ../erp-dev-ALB && terraform destroy -auto-approve

# EKS
cd ../erp-dev-EKS && terraform destroy -auto-approve

# Databases
cd ../erp-dev-Databases/elasticache && terraform destroy -auto-approve
cd ../rds && terraform destroy -auto-approve

# IAM
cd ../../erp-dev-IAM && terraform destroy -auto-approve

# SecurityGroups
cd ../erp-dev-SecurityGroups/elasticache-sg && terraform destroy -auto-approve
cd ../rds-sg && terraform destroy -auto-approve
cd ../eks-sg && terraform destroy -auto-approve
cd ../alb-sg && terraform destroy -auto-approve

# VPC
cd ../../erp-dev-VPC/route-table && terraform destroy -auto-approve
cd ../subnet && terraform destroy -auto-approve
cd ../vpc && terraform destroy -auto-approve
```

## tfstate 관리

**S3 Backend:**
- Bucket: `erp-terraform-state-subin-bucket`
- DynamoDB: `erp-terraform-locks`

**tfstate 경로:**
```
dev/vpc/vpc/terraform.tfstate
dev/vpc/subnet/terraform.tfstate
dev/vpc/route-table/terraform.tfstate
dev/security-groups/alb-sg/terraform.tfstate
dev/security-groups/eks-sg/terraform.tfstate
dev/security-groups/rds-sg/terraform.tfstate
dev/security-groups/elasticache-sg/terraform.tfstate
dev/iam/terraform.tfstate
dev/databases/rds/terraform.tfstate
dev/databases/elasticache/terraform.tfstate
dev/eks/terraform.tfstate
dev/alb/terraform.tfstate
dev/secrets/terraform.tfstate
```

## 주의사항

1. **환경변수 필수:** `TF_VAR_mysql_password` 설정 필요
2. **실행 순서 준수:** 의존성 때문에 순서대로 실행
3. **RDS 생성 시간:** 약 5-10분 소요
4. **EKS 생성 시간:** 약 10-15분 소요
5. **삭제는 역순:** 의존성 때문에 역순으로 삭제
