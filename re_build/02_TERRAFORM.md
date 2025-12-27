# 02. Terraform 인프라 배포

**소요 시간**: 2시간  
**목표**: AWS 인프라 전체 구축 (VPC, EKS, RDS, NLB, API Gateway 등)

---

##  배포 순서 (의존성 기반)

### 순서가 중요한 이유

Terraform 모듈 간 의존성:
```
VPC → SecurityGroups → IAM → Databases → EKS → ECR → LoadBalancerController → Lambda → APIGateway → Frontend → Cognito
```

**실제 Terraform 구조:**
- VPC: 세분화 (vpc, subnet, route-table)
- SecurityGroups: 세분화 (alb-sg, eks-sg, rds-sg, elasticache-sg)
- IAM: 세분화 (eks-cluster-role, eks-node-role, codebuild-role, codepipeline-role)
- Databases: 세분화 (rds, elasticache)
- EKS: 세분화 (eks-cluster, eks-node-group, eks-cluster-sg-rules)
- ECR: 단일 (4개 Repository 통합)
- LoadBalancerController: 단일
- Lambda: 단일
- APIGateway: 세분화 (nlb, api-gateway)
- Frontend: 세분화 (s3, cloudfront)
- Cognito: 세분화 (user-pool, identity-pool)

**잘못된 순서로 실행 시:**
- EKS를 VPC보다 먼저 실행 → 에러 (Subnet이 없음)
- Secrets를 IAM보다 먼저 실행 → 에러 (EKS Node Role이 없음)
- API Gateway를 NLB보다 먼저 실행 → 에러 (Target Group이 없음)

---

##  Step 1: VPC 배포 (세분화, 15분)

### 1-1. VPC 생성

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/infrastructure/terraform/dev/erp-dev-VPC/vpc

# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply -auto-approve
```

**생성 리소스:**
- VPC (10.0.0.0/16)
- Internet Gateway

**확인:**
```bash
terraform output
# vpc_id = "vpc-xxxxx"
```

### 1-2. Subnet 생성

```bash
cd ../subnet

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- Public Subnet 2개 (AZ-A, AZ-C)
- Private Subnet 2개 (AZ-A, AZ-C)

**확인:**
```bash
terraform output
# public_subnet_ids = ["subnet-xxx", "subnet-yyy"]
# private_subnet_ids = ["subnet-aaa", "subnet-bbb"]
```

### 1-3. Route Table 생성

```bash
cd ../route-table

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- NAT Gateway 1개 (Public Subnet 1)
- Public Route Table
- Private Route Table

**확인:**
```bash
terraform output
# nat_gateway_id = "nat-xxxxx"
```

---

## 🔒 Step 2: Security Groups 배포 (세분화, 10분)

️ **중요:** EKS Security Group은 2단계로 나뉩니다.
- Step 2-1: EKS SG 생성 (EKS 클러스터 전)
- Step 5.5: EKS SG 추가 규칙 (EKS 클러스터 후)

### 2-1. ALB Security Group (먼저!)

```bash
cd ../../erp-dev-SecurityGroups/alb-sg

terraform init
terraform apply -auto-approve
```

### 2-2. EKS Security Group (기본 생성만)

```bash
cd ../eks-sg

terraform init

# ️ 주의: data "aws_eks_cluster" 부분은 에러 발생
# 일단 기본 Security Group만 생성됨
terraform apply -auto-approve || echo "Expected error - will fix after EKS creation"
```

**예상 동작:**
-  `aws_security_group.eks` 생성 성공
-  `aws_security_group_rule.eks_cluster_vpc_ingress` 실패 (EKS 없음)
- → 정상입니다! Step 5.5에서 다시 실행

### 2-3. RDS Security Group

```bash
cd ../rds-sg

terraform init
terraform apply -auto-approve
```

### 2-4. ElastiCache Security Group

```bash
cd ../elasticache-sg

terraform init
terraform apply -auto-approve
```

**확인:**
```bash
# 각 폴더에서
terraform output
# sg_id = "sg-xxxxx"
```

---

##  Step 3: IAM Roles 배포 (통합, 5분)

```bash
cd ../../erp-dev-IAM

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- EKS Cluster Role
- EKS Node Role
- CodeBuild Role (️ 권한 추가 필요)
- CodePipeline Role

**확인:**
```bash
terraform output
# eks_cluster_role_arn = "arn:aws:iam::xxx:role/erp-dev-eks-cluster-role"
# eks_node_role_arn = "arn:aws:iam::xxx:role/erp-dev-eks-node-role"
# codebuild_role_arn = "arn:aws:iam::xxx:role/erp-dev-codebuild-role"
```

### 3-1. CodeBuild Role 권한 추가 ( 완료!)

**Terraform 코드에 이미 반영되어 배포 완료:**
-  Secrets Manager 읽기 (buildspec.yml에서 필요)
-  Parameter Store 읽기 (buildspec.yml에서 필요)
-  ECR 이미지 스캔 (buildspec.yml에서 필요)

**확인:**
```bash
aws iam list-role-policies --role-name erp-dev-codebuild-role --region ap-northeast-2
# PolicyNames:
# - codebuild-secrets-policy 
# - codebuild-ssm-policy 
# - codebuild-ecr-scan-policy 
# - codebuild-ecr-policy
# - codebuild-eks-policy
# - codebuild-logs-policy
# - codebuild-s3-policy
# - codebuild-codeconnections-policy
```

**권한 내용:**
- `codebuild-secrets-policy`: secretsmanager:GetSecretValue, DescribeSecret
- `codebuild-ssm-policy`: ssm:GetParameter, GetParameters
- `codebuild-ecr-scan-policy`: ecr:StartImageScan, DescribeImageScanFindings

---

##  Step 4: Databases 배포 (세분화, 20분)

### 4-1. RDS MySQL

**중요: RDS는 이미 ASM Secret을 읽어서 생성됩니다.**

```bash
cd ../erp-dev-Databases/rds

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- RDS MySQL 8.0 (db.t3.micro)
- Single-AZ
- 20GB gp3 Storage
- Data Subnet
- **비밀번호는 ASM `erp/dev/mysql`에서 자동으로 읽어옴**

**확인:**
```bash
terraform output
# endpoint = "erp-dev-mysql.cniqqqqiyu1n.ap-northeast-2.rds.amazonaws.com"
```

** 대기 시간: 약 10분**

### 4-2. ElastiCache Redis

```bash
cd ../elasticache

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- ElastiCache Redis 7.0
- cache.t3.micro
- 1 Node

**확인:**
```bash
terraform output
# endpoint = "erp-dev-redis.jmz0hq.0001.apn2.cache.amazonaws.com"
```

** 대기 시간: 약 5분**

---

## ️ Step 5: EKS 배포 (통합, 30분)

```bash
cd ../../erp-dev-EKS

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- EKS Cluster (erp-dev, v1.31)
- Node Group (t3.small × 3)
  - desired_size = 3
  - min_size = 1
  - max_size = 3

**확인:**
```bash
terraform output
# cluster_name = "erp-dev"
# cluster_endpoint = "https://xxx.eks.ap-northeast-2.amazonaws.com"
```

** 대기 시간: 약 15분**

**kubeconfig 설정:**
```bash
aws eks update-kubeconfig --region ap-northeast-2 --name erp-dev

# 확인
kubectl get nodes
# NAME                                            STATUS   ROLES    AGE   VERSION
# ip-10-0-10-xxx.ap-northeast-2.compute.internal  Ready    <none>   1m    v1.31.x
# ip-10-0-11-xxx.ap-northeast-2.compute.internal  Ready    <none>   1m    v1.31.x
# ip-10-0-10-yyy.ap-northeast-2.compute.internal  Ready    <none>   1m    v1.31.x
```

---

##  Step 6: ECR Repository 배포 (단일, 5분)

```bash
cd ../erp-dev-ECR

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- ECR Repository: erp/employee-service-lambda (Lambda용)
- ECR Repository: erp/approval-request-service (EKS용)
- ECR Repository: erp/approval-processing-service (EKS용)
- ECR Repository: erp/notification-service (EKS용)

**확인:**
```bash
terraform output

# ECR Repository 목록 확인
aws ecr describe-repositories --region ap-northeast-2 --query 'repositories[?contains(repositoryName, `erp`)].repositoryName' --output table
```

---

##  Step 10: Load Balancer Controller 배포 (단일, 10분)

```bash
cd ../erp-dev-LoadBalancerController

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- AWS Load Balancer Controller (Helm)
- IAM Policy
- ServiceAccount

**확인:**
```bash
kubectl get pods -n kube-system | grep aws-load-balancer-controller
# aws-load-balancer-controller-xxx   1/1     Running   0          1m
```

---

##  Step 10: API Gateway 배포 (통합, 15분)

```bash
cd ../erp-dev-APIGateway

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- NLB (Private, erp-dev-nlb)
- Target Group 4개 (employee, approval-request, approval-processing, notification)
- Listener 4개 (8081, 8082, 8083, 8084)
- VPC Link
- API Gateway HTTP API
- Routes 7개

**확인:**
```bash
terraform output
# api_gateway_url = "https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com"
# nlb_dns = "erp-dev-nlb-xxx.elb.ap-northeast-2.amazonaws.com"
```

---

##  Step 10: Frontend 배포 (통합, 10분)

```bash
cd ../erp-dev-Frontend

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- S3 Bucket (Static Website Hosting)
- CloudFront Distribution

**확인:**
```bash
terraform output
# cloudfront_domain = "d95pjcr73gr6g.cloudfront.net"
# s3_bucket_name = "erp-dev-frontend-bucket"
```

---

##  Step 10: Cognito 배포 (통합, 5분)

```bash
cd ../erp-dev-Cognito

terraform init
terraform apply -auto-approve
```

**생성 리소스:**
- User Pool
- App Client

**확인:**
```bash
terraform output
# user_pool_id = "ap-northeast-2_xxxxx"
# user_pool_client_id = "xxxxx"
```

---

##  최종 확인

### 모든 리소스 확인

```bash
# VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=erp-dev-vpc" --region ap-northeast-2

# EKS
aws eks describe-cluster --name erp-dev --region ap-northeast-2

# RDS
aws rds describe-db-instances --db-instance-identifier erp-dev-mysql --region ap-northeast-2

# NLB
aws elbv2 describe-load-balancers --names erp-dev-nlb --region ap-northeast-2

# API Gateway
aws apigatewayv2 get-apis --region ap-northeast-2 | grep erp-dev
```

### 비용 확인

```bash
# 현재 사용 중인 리소스
aws ce get-cost-and-usage \
  --time-period Start=2024-12-01,End=2024-12-27 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --region ap-northeast-2
```

---

## 🚨 트러블슈팅

### 문제 1: Terraform State Lock

**증상:**
```
Error: Error acquiring the state lock
```

**해결:**
```bash
# Lock 해제
terraform force-unlock <LOCK_ID>
```

### 문제 2: LoadBalancerController - vpc_id 변수 요구

**증상:**
```
var.vpc_id 입력 대기
```

**해결:**
-  이미 수정 완료: variables.tf에서 vpc_id 제거, remote state 사용

### 문제 3: APIGateway - 하드코딩된 Security Group

**증상:**
```
Error: security group 'sg-0a13cde3743d6ead9' does not exist
```

**해결:**
-  이미 수정 완료: remote state에서 ALB SG 가져오도록 변경

### 문제 4: Frontend - S3 Bucket Already Exists

**증상:**
```
Error: BucketAlreadyOwnedByYou
```

**해결:**
```bash
terraform import module.s3.aws_s3_bucket.frontend erp-dev-frontend-dev
```

---

##  배포 완료 체크리스트

- [x] VPC 생성 완료 (vpc-064dc3c3fab271278)
- [x] Subnet 6개 생성 완료 (Public x2, Private x2, Data x2)
- [x] NAT Gateway 생성 완료 (nat-0bc52407b9db0428a)
- [x] Security Groups 4개 생성 완료 (ALB, EKS, RDS, ElastiCache)
- [x] IAM Roles 4개 생성 완료 + CodeBuild 권한 8개 추가
- [x] RDS MySQL 생성 완료 (erp-dev-mysql.cniqqqqiyu1n.ap-northeast-2.rds.amazonaws.com)
- [x] ElastiCache Redis 생성 완료 (erp-dev-redis.jmz0hq.0001.apn2.cache.amazonaws.com)
- [x] EKS Cluster 생성 완료 (erp-dev, v1.31)
- [x] EKS Node Group 생성 완료 (4 nodes, t3.small)
- [x] ECR Repository 생성 완료 (4개)
- [x] Load Balancer Controller 설치 완료 (Helm)
- [x] NLB 생성 완료 (erp-dev-nlb + 4 Target Groups)
- [x] API Gateway 생성 완료 (yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com)
- [x] Frontend S3, CloudFront 생성 완료 (d3goird6ndqlnv.cloudfront.net)
- [x] Cognito User Pool 생성 완료 (ap-northeast-2_OZneAVLnb)

** Phase 1 Terraform 배포 100% 완료**
** Phase 2-7 진행 준비 완료**

---

##  중요 정보 저장

**다음 단계에서 필요한 정보를 저장하세요:**

```bash
# outputs.txt 파일 생성
cat > /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/terraform-outputs.txt << EOF
# Terraform Outputs ($(date))

## VPC
VPC_ID=$(cd erp-dev-VPC/vpc && terraform output -raw vpc_id)
PRIVATE_SUBNET_IDS=$(cd erp-dev-VPC/subnet && terraform output -json private_subnet_ids)

## Databases
RDS_ENDPOINT=$(cd erp-dev-Databases/rds && terraform output -raw endpoint)
REDIS_ENDPOINT=$(cd erp-dev-Databases/elasticache && terraform output -raw endpoint)

## EKS
EKS_CLUSTER_NAME=$(cd erp-dev-EKS && terraform output -raw cluster_name)
EKS_ENDPOINT=$(cd erp-dev-EKS && terraform output -raw cluster_endpoint)

## API Gateway
API_GATEWAY_URL=$(cd erp-dev-APIGateway && terraform output -raw api_gateway_url)
NLB_DNS=$(cd erp-dev-APIGateway && terraform output -raw nlb_dns)

## Frontend
CLOUDFRONT_DOMAIN=$(cd erp-dev-Frontend && terraform output -raw cloudfront_domain)

## Cognito
USER_POOL_ID=$(cd erp-dev-Cognito && terraform output -raw user_pool_id)
EOF

cat terraform-outputs.txt
```

---

##  다음 단계

**Terraform 배포 완료!**

**다음 파일을 읽으세요:**
→ **03_IMAGE_BUILD.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 03_IMAGE_BUILD.md
```

---

**"Terraform 배포가 완료되었습니다. 이제 Kubernetes 환경을 구성할 차례입니다!"**
