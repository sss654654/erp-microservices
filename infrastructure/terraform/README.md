# Terraform 실행 가이드

ERP 프로젝트의 AWS 인프라를 Terraform으로 배포하는 가이드입니다.

---

## 목차

1. [사전 준비](#사전-준비)
2. [디렉토리 구조](#디렉토리-구조)
3. [실행 순서](#실행-순서)
4. [각 모듈 상세 설명](#각-모듈-상세-설명)
5. [트러블슈팅](#트러블슈팅)
6. [리소스 삭제](#리소스-삭제)

---

## 사전 준비

### 1. AWS CLI 설정

```bash
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region name: ap-northeast-2
# Default output format: json
```

**확인:**
```bash
aws sts get-caller-identity
```

### 2. Terraform 설치

```bash
# Linux/WSL
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# 확인
terraform version
```

### 3. 환경 변수 설정

```bash
export TF_VAR_mysql_password="your-secure-password"
export AWS_REGION="ap-northeast-2"
```

---

## 디렉토리 구조

```
infrastructure/terraform/
├── backend-setup/      # S3 + DynamoDB (최초 1회 실행)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── dev/
│   ├── vpc/           # VPC, Subnet, NAT Gateway
│   ├── security/      # Security Groups, IAM Roles
│   ├── eks/           # EKS Cluster, Node Group
│   ├── databases/     # RDS MySQL, ElastiCache Redis
│   └── alb/           # ALB, Target Groups
├── stage/             # 향후 확장
└── prod/              # 향후 확장
```

---

## 실행 순서

### Step 1: Backend 설정 (최초 1회)

S3 버킷과 DynamoDB 테이블을 생성하여 Terraform 상태를 저장합니다.

```bash
cd backend-setup
terraform init
terraform plan
terraform apply

# 출력 확인
terraform output
```

**생성 리소스:**
- S3 버킷: `erp-terraform-state-subin-bucket`
- DynamoDB 테이블: `erp-terraform-locks`

**소요 시간:** 약 1분

---

### Step 2: VPC 생성

네트워크 인프라를 구축합니다.

```bash
cd ../dev/vpc
terraform init
terraform plan
terraform apply

# 출력 확인
terraform output
```

**생성 리소스:**
- VPC (10.0.0.0/16)
- Public Subnet 2개 (AZ-a, AZ-c)
- Private Subnet 2개 (AZ-a, AZ-c)
- Data Subnet 2개 (AZ-a, AZ-c)
- Internet Gateway
- NAT Gateway
- Route Tables

**소요 시간:** 약 5분

**확인:**
```bash
# VPC ID 확인
terraform output vpc_id

# AWS Console에서 확인
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=erp-dev-vpc"
```

---

### Step 3: Security 생성

보안 그룹과 IAM 역할을 생성합니다.

```bash
cd ../security
terraform init
terraform plan
terraform apply

# 출력 확인
terraform output
```

**생성 리소스:**
- Security Groups: ALB, EKS, RDS, ElastiCache
- IAM Roles: EKS Cluster Role, EKS Node Role

**소요 시간:** 약 2분

**확인:**
```bash
# Security Group IDs 확인
terraform output alb_sg_id
terraform output eks_sg_id

# IAM Role ARNs 확인
terraform output eks_cluster_role_arn
```

---

### Step 4: Databases 생성

RDS MySQL과 ElastiCache Redis를 생성합니다.

```bash
cd ../databases

# 비밀번호 설정 (3가지 방법 중 선택)

# 방법 1: 환경 변수 사용 (권장)
export TF_VAR_mysql_password="YourSecurePassword123!"
terraform init
terraform plan
terraform apply

# 방법 2: 명령줄 인자
terraform apply -var="mysql_password=YourSecurePassword123!"

# 방법 3: terraform.tfvars 파일 생성 (Git에 커밋 금지!)
echo 'mysql_password = "YourSecurePassword123!"' > terraform.tfvars
terraform apply

# 출력 확인
terraform output
```

**생성 리소스:**
- RDS MySQL (db.t3.micro, 20GB, Single-AZ)
- ElastiCache Redis (cache.t3.micro, Single-Node)
- DB Subnet Groups

**소요 시간:** 약 10-15분

**확인:**
```bash
# RDS Endpoint 확인
terraform output rds_endpoint

# ElastiCache Endpoint 확인
terraform output elasticache_endpoint

# AWS Console에서 확인
aws rds describe-db-instances --db-instance-identifier erp-dev-mysql
aws elasticache describe-cache-clusters --cache-cluster-id erp-dev-redis
```

**주의사항:**
- RDS 생성 중 "creating" 상태가 약 10분 지속됩니다.
- 비밀번호는 최소 8자, 대소문자/숫자/특수문자 포함 필요

---

### Step 5: EKS 생성

Kubernetes 클러스터와 Worker Nodes를 생성합니다.

```bash
cd ../eks
terraform init
terraform plan
terraform apply

# 출력 확인
terraform output
```

**생성 리소스:**
- EKS Cluster (Kubernetes 1.28)
- Node Group (t3.medium × 2, 최소 2, 최대 4)

**소요 시간:** 약 15-20분

**확인:**
```bash
# Cluster 이름 확인
terraform output cluster_name

# kubectl 설정
aws eks update-kubeconfig --region ap-northeast-2 --name erp-dev

# Nodes 확인
kubectl get nodes
```

**주의사항:**
- EKS Cluster 생성이 가장 오래 걸립니다 (약 10분).
- Node Group 생성도 추가로 5-10분 소요됩니다.

---

### Step 6: ALB 생성

Application Load Balancer와 Target Groups를 생성합니다.

```bash
cd ../alb
terraform init
terraform plan
terraform apply

# 출력 확인
terraform output
```

**생성 리소스:**
- Application Load Balancer (Internet-facing)
- Target Groups 4개 (Employee, Approval Request, Approval Processing, Notification)
- Listener Rules (경로 기반 라우팅)

**소요 시간:** 약 5분

**확인:**
```bash
# ALB DNS 확인
terraform output alb_dns_name

# Target Groups 확인
terraform output employee_tg_arn

# AWS Console에서 확인
aws elbv2 describe-load-balancers --names erp-dev-alb
```

---

## 전체 실행 스크립트

모든 모듈을 한 번에 실행하려면:

```bash
#!/bin/bash
set -e

# 환경 변수 설정
export TF_VAR_mysql_password="YourSecurePassword123!"
export AWS_REGION="ap-northeast-2"

# Backend 설정
cd backend-setup
terraform init && terraform apply -auto-approve

# VPC
cd ../dev/vpc
terraform init && terraform apply -auto-approve

# Security
cd ../security
terraform init && terraform apply -auto-approve

# Databases
cd ../databases
terraform init && terraform apply -auto-approve

# EKS
cd ../eks
terraform init && terraform apply -auto-approve

# ALB
cd ../alb
terraform init && terraform apply -auto-approve

echo "✅ 모든 인프라 배포 완료!"
echo "총 소요 시간: 약 40-50분"
```

**실행:**
```bash
chmod +x deploy-all.sh
./deploy-all.sh
```

---

## 각 모듈 상세 설명

### VPC 모듈

**파일 구조:**
```
vpc/
├── main.tf         # VPC, Subnet, IGW, NAT, Route Tables
├── variables.tf    # CIDR, AZ, 프로젝트 이름
├── outputs.tf      # VPC ID, Subnet IDs
├── backend.tf      # S3 Backend 설정
└── provider.tf     # AWS Provider
```

**주요 변수:**
- `vpc_cidr`: VPC CIDR 블록 (기본값: 10.0.0.0/16)
- `availability_zones`: AZ 목록 (기본값: [ap-northeast-2a, ap-northeast-2c])

**Outputs:**
- `vpc_id`: VPC ID
- `public_subnet_ids`: Public Subnet IDs (ALB 배치)
- `private_subnet_ids`: Private Subnet IDs (EKS Nodes 배치)
- `data_subnet_ids`: Data Subnet IDs (RDS, ElastiCache 배치)

---

### Security 모듈

**파일 구조:**
```
security/
├── main.tf         # Security Groups, IAM Roles
├── variables.tf    # 프로젝트 이름, 환경
├── outputs.tf      # SG IDs, IAM Role ARNs
├── backend.tf      # S3 Backend 설정
└── provider.tf     # AWS Provider
```

**Security Groups:**
1. **ALB SG**: 80, 443 포트 허용 (인터넷 → ALB)
2. **EKS SG**: 8081-8084 포트 허용 (ALB → EKS), 클러스터 내부 통신
3. **RDS SG**: 3306 포트 허용 (EKS → RDS)
4. **ElastiCache SG**: 6379 포트 허용 (EKS → Redis)

**IAM Roles:**
1. **EKS Cluster Role**: EKS가 AWS API 호출
2. **EKS Node Role**: Worker Nodes가 ECR Pull, CloudWatch Logs 전송

**Data Source:**
- VPC 모듈의 `vpc_id` 참조

---

### EKS 모듈

**파일 구조:**
```
eks/
├── main.tf         # EKS Cluster, Node Group
├── variables.tf    # Kubernetes 버전, 인스턴스 타입, Node 수
├── outputs.tf      # Cluster 이름, Endpoint, 인증 정보
├── backend.tf      # S3 Backend 설정
└── provider.tf     # AWS Provider
```

**주요 변수:**
- `kubernetes_version`: Kubernetes 버전 (기본값: 1.28)
- `node_instance_types`: 인스턴스 타입 (기본값: [t3.medium])
- `node_desired_size`: 원하는 Node 수 (기본값: 2)
- `node_min_size`: 최소 Node 수 (기본값: 2)
- `node_max_size`: 최대 Node 수 (기본값: 4)

**Data Source:**
- VPC 모듈: `private_subnet_ids`
- Security 모듈: `eks_sg_id`, `eks_cluster_role_arn`, `eks_node_role_arn`

**kubectl 설정:**
```bash
aws eks update-kubeconfig --region ap-northeast-2 --name erp-dev
kubectl get nodes
```

---

### Databases 모듈

**파일 구조:**
```
databases/
├── main.tf         # RDS, ElastiCache, Subnet Groups
├── variables.tf    # 인스턴스 타입, 스토리지, 비밀번호
├── outputs.tf      # Endpoint, Port
├── backend.tf      # S3 Backend 설정
└── provider.tf     # AWS Provider
```

**주요 변수:**
- `mysql_version`: MySQL 버전 (기본값: 8.0)
- `rds_instance_class`: RDS 인스턴스 타입 (기본값: db.t3.micro)
- `rds_allocated_storage`: 스토리지 크기 (기본값: 20GB)
- `mysql_password`: MySQL 비밀번호 (필수, sensitive)
- `redis_version`: Redis 버전 (기본값: 7.0)
- `redis_node_type`: ElastiCache 노드 타입 (기본값: cache.t3.micro)

**Data Source:**
- VPC 모듈: `data_subnet_ids`
- Security 모듈: `rds_sg_id`, `elasticache_sg_id`

**연결 테스트:**
```bash
# RDS MySQL
mysql -h $(terraform output -raw rds_address) -u admin -p

# ElastiCache Redis
redis-cli -h $(terraform output -raw elasticache_endpoint)
```

---

### ALB 모듈

**파일 구조:**
```
alb/
├── main.tf         # ALB, Target Groups, Listener Rules
├── variables.tf    # 프로젝트 이름, 환경
├── outputs.tf      # ALB DNS, Target Group ARNs
├── backend.tf      # S3 Backend 설정
└── provider.tf     # AWS Provider
```

**Target Groups:**
1. Employee Service (8081) → `/api/employees/*`
2. Approval Request Service (8082) → `/api/approvals/*`
3. Approval Processing Service (8083) → `/api/processing/*`
4. Notification Service (8084) → `/api/notifications/*`

**Health Check:**
- Path: `/actuator/health`
- Interval: 30초
- Healthy Threshold: 2
- Unhealthy Threshold: 3

**Data Source:**
- VPC 모듈: `vpc_id`, `public_subnet_ids`
- Security 모듈: `alb_sg_id`

**ALB 테스트:**
```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
curl http://$ALB_DNS/api/employees/health
```

---

## 트러블슈팅

### 1. "Error: Backend initialization required"

**원인:** Backend 설정이 초기화되지 않음

**해결:**
```bash
terraform init -reconfigure
```

---

### 2. "Error: VPC not found"

**원인:** VPC 모듈이 실행되지 않았거나 State 파일을 찾을 수 없음

**해결:**
```bash
# VPC 모듈 먼저 실행
cd ../vpc
terraform apply

# State 파일 확인
aws s3 ls s3://erp-terraform-state-subin-bucket/dev/vpc/
```

---

### 3. "Error: InvalidParameterException: The following supplied instance types do not exist"

**원인:** 선택한 인스턴스 타입이 해당 리전에서 지원되지 않음

**해결:**
```bash
# variables.tf에서 인스턴스 타입 변경
# t3.medium → t3.small 또는 t2.medium
```

---

### 4. "Error: DBInstanceAlreadyExists"

**원인:** 동일한 이름의 RDS 인스턴스가 이미 존재

**해결:**
```bash
# 기존 인스턴스 삭제
aws rds delete-db-instance --db-instance-identifier erp-dev-mysql --skip-final-snapshot

# 또는 main.tf에서 identifier 변경
identifier = "erp-dev-mysql-v2"
```

---

### 5. "Error: ResourceInUseException: Cannot delete entity, must detach all policies first"

**원인:** IAM Role에 Policy가 연결되어 있어 삭제 불가

**해결:**
```bash
# Terraform으로 삭제 (자동으로 Policy detach)
terraform destroy

# 수동 삭제 시
aws iam detach-role-policy --role-name erp-dev-eks-cluster-role --policy-arn <policy-arn>
aws iam delete-role --role-name erp-dev-eks-cluster-role
```

---

### 6. "Error: timeout while waiting for state to become 'ACTIVE'"

**원인:** EKS Cluster 생성 시간 초과 (네트워크 문제 또는 AWS 장애)

**해결:**
```bash
# 재시도
terraform apply

# 또는 timeout 증가 (main.tf에 추가)
timeouts {
  create = "30m"
  update = "30m"
  delete = "30m"
}
```

---

### 7. State Lock 해제

**원인:** 이전 실행이 비정상 종료되어 Lock이 남아있음

**해결:**
```bash
# Lock ID 확인 (에러 메시지에 표시됨)
terraform force-unlock <LOCK_ID>

# 예시
terraform force-unlock 12345678-1234-1234-1234-123456789012
```

---

### 8. "Error: error creating ElastiCache Cluster: InvalidParameterValue"

**원인:** Redis 버전과 Parameter Group 불일치

**해결:**
```bash
# variables.tf에서 Redis 버전 확인
redis_version = "7.0"

# main.tf에서 Parameter Group 확인
parameter_group_name = "default.redis7"
```

---

## 리소스 삭제

### 개별 모듈 삭제

**역순으로 삭제해야 합니다** (의존성 때문):

```bash
# 1. ALB 삭제
cd dev/alb
terraform destroy

# 2. EKS 삭제
cd ../eks
terraform destroy

# 3. Databases 삭제
cd ../databases
terraform destroy

# 4. Security 삭제
cd ../security
terraform destroy

# 5. VPC 삭제
cd ../vpc
terraform destroy

# 6. Backend 삭제 (선택)
cd ../../backend-setup
terraform destroy
```

---

### 전체 삭제 스크립트

```bash
#!/bin/bash
set -e

# ALB
cd dev/alb
terraform destroy -auto-approve

# EKS
cd ../eks
terraform destroy -auto-approve

# Databases
cd ../databases
terraform destroy -auto-approve

# Security
cd ../security
terraform destroy -auto-approve

# VPC
cd ../vpc
terraform destroy -auto-approve

# Backend (선택)
# cd ../../backend-setup
# terraform destroy -auto-approve

echo "✅ 모든 인프라 삭제 완료!"
```

---

### 삭제 시 주의사항

1. **EKS 삭제 전 Pod 확인**
   ```bash
   kubectl get pods --all-namespaces
   kubectl delete deployment --all
   ```

2. **RDS 스냅샷 생성 (선택)**
   ```bash
   aws rds create-db-snapshot \
     --db-instance-identifier erp-dev-mysql \
     --db-snapshot-identifier erp-dev-mysql-final-snapshot
   ```

3. **S3 버킷 비우기 (Backend 삭제 시)**
   ```bash
   aws s3 rm s3://erp-terraform-state-subin-bucket --recursive
   ```

4. **비용 확인**
   ```bash
   # 삭제 전 plan으로 확인
   terraform plan -destroy
   ```

---

## 유용한 명령어

### State 관리

```bash
# State 파일 확인
terraform show

# 리소스 목록
terraform state list

# 특정 리소스 상태 확인
terraform state show aws_vpc.main

# State 파일 Pull
terraform state pull > state.json

# State 파일 동기화
terraform refresh
```

---

### Outputs 확인

```bash
# 모든 outputs 출력
terraform output

# 특정 output 출력
terraform output vpc_id

# JSON 형식으로 출력
terraform output -json

# Raw 값 출력 (스크립트에서 사용)
terraform output -raw alb_dns_name
```

---

### Plan 저장 및 적용

```bash
# Plan 저장
terraform plan -out=tfplan

# 저장된 Plan 확인
terraform show tfplan

# 저장된 Plan 적용
terraform apply tfplan
```

---

### 변수 전달 방법

```bash
# 1. 명령줄 인자
terraform apply -var="mysql_password=password123"

# 2. 환경 변수
export TF_VAR_mysql_password="password123"
terraform apply

# 3. terraform.tfvars 파일
echo 'mysql_password = "password123"' > terraform.tfvars
terraform apply

# 4. .tfvars 파일 지정
terraform apply -var-file="production.tfvars"
```

---

## 참고 자료

- [Terraform AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS 모범 사례](https://aws.github.io/aws-eks-best-practices/)
- [Terraform Backend 설정](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Terraform State 관리](https://developer.hashicorp.com/terraform/language/state)

---

## 문의

문제가 발생하면 다음을 확인하세요:

1. AWS CLI 자격 증명 확인: `aws sts get-caller-identity`
2. Terraform 버전 확인: `terraform version`
3. State 파일 확인: `aws s3 ls s3://erp-terraform-state-subin-bucket/`
4. CloudWatch Logs 확인 (EKS 관련 문제)
5. AWS Console에서 리소스 상태 확인
