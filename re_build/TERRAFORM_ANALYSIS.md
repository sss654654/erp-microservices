# Terraform 100% 분석 결과 및 리팩토링 가이드

**분석일**: 2024-12-27  
**분석 범위**: infrastructure/terraform/dev 전체 .tf 파일 (98개)

---

## 📊 실제 Terraform 구조

### 1. VPC (세분화 - 3단계)

```
erp-dev-VPC/
├── vpc/ (terraform apply 1)
│   └── vpc.tf: VPC (10.0.0.0/16) + IGW
├── subnet/ (terraform apply 2)
│   └── subnet.tf: 
│       - Public: 10.0.0.0/24, 10.0.1.0/24
│       - Private: 10.0.10.0/24, 10.0.11.0/24
│       - Data: 10.0.20.0/24, 10.0.21.0/24
│       - NAT Gateway (Public Subnet 1)
└── route-table/ (terraform apply 3)
    └── route-table.tf: Public RT, Private RT + Associations
```

### 2. SecurityGroups (세분화 - 4개 독립)

```
erp-dev-SecurityGroups/
├── alb-sg/ (terraform apply 1)
├── eks-sg/ (terraform apply 2)
│   └── eks-sg.tf:
│       - Ingress: 8081-8084 from ALB
│       - Ingress: All from self
│       - Egress: All
│       - EKS Cluster SG Rule: All from VPC (NLB용)
├── rds-sg/ (terraform apply 3)
│   └── rds-sg.tf: 3306 from EKS
└── elasticache-sg/ (terraform apply 4)
    └── elasticache-sg.tf: 6379 from EKS
```

### 3. IAM (통합 - 1번 apply)

```
erp-dev-IAM/
├── main.tf (module 호출)
├── eks-cluster-role/
├── eks-node-role/
├── codebuild-role/
│   └── codebuild-role.tf:
│       - ECR 권한
│       - EKS DescribeCluster
│       - CloudWatch Logs
│       - S3 (CodePipeline artifact)
│       - CodeConnections
│       ⚠️ 없는 권한: Secrets Manager, Parameter Store, ECR Scan
└── codepipeline-role/
```

### 4. Secrets (통합 - 1번 apply)

```
erp-dev-Secrets/
├── main.tf (module 호출)
├── mysql-secret/
│   └── mysql-secret.tf:
│       - Secret 이름: erp/dev/mysql ← 실제 이름!
│       - Secret 내용: {username, password, host, port, database}
└── eks-node-secrets-policy/
    └── eks-node-secrets-policy.tf:
        - EKS Node Role에 Secrets Manager 읽기 권한 추가
```

**⚠️ 중요:**
- MongoDB Secret 없음 (Atlas 사용)
- Secret 이름: `erp/dev/mysql` (가이드는 `prod/rds/password`로 잘못 작성됨)

### 5. Databases (세분화 - 2개 독립)

```
erp-dev-Databases/
├── rds/ (terraform apply 1)
│   └── rds.tf:
│       - MySQL 8.0
│       - db.t3.micro
│       - Single-AZ
│       - Data Subnet
│       - 20GB gp3
└── elasticache/ (terraform apply 2)
    └── elasticache.tf:
        - Redis 7.0
        - cache.t3.micro
        - 1 Node
        - Data Subnet
```

### 6. EKS (통합 - 1번 apply)

```
erp-dev-EKS/
├── main.tf (module 호출)
├── eks-cluster/
│   └── eks-cluster.tf:
│       - Kubernetes 1.31
│       - Private Subnet
│       - OIDC Provider
├── eks-node-group/
│   └── eks-node-group.tf:
│       - t3.small
│       - desired_size: 3 ← Kafka 때문
│       - min_size: 1
│       - max_size: 3
│       - Launch Template (20GB gp3, IMDSv2)
└── eks-cluster-sg-rules/
    └── cluster-sg-rules.tf:
        - EKS Cluster SG에 VPC ingress 추가 (NLB용)
```

**⚠️ Node 3개 이유:**
- Kafka 메모리 요구사항
- 서비스 Pod Anti-Affinity 분산

### 7. LoadBalancerController (단일 - 1번 apply)

```
erp-dev-LoadBalancerController/
└── load-balancer-controller.tf:
    - IAM Role for ServiceAccount
    - Kubernetes ServiceAccount
    - Helm Release (v1.7.0)
```

### 8. APIGateway (통합 - 1번 apply)

```
erp-dev-APIGateway/
├── main.tf (module 호출)
├── nlb/
│   └── nlb.tf:
│       - NLB (Private, Internal)
│       - 4 Target Groups (employee, approval-request, approval-processing, notification)
│       - 4 Listeners (8081, 8082, 8083, 8084)
└── api-gateway/
    └── api-gateway.tf:
        - VPC Link
        - API Gateway HTTP API
        - 7 Routes:
          1. /api/employees
          2. /api/approvals
          3. /api/process
          4. /api/notifications
          5. /api/attendance → Employee Service
          6. /api/quests → Employee Service
          7. /api/leaves → Employee Service
```

### 9. Frontend (통합 - 1번 apply)

```
erp-dev-Frontend/
├── main.tf (module 호출)
├── s3/
│   └── s3-bucket.tf:
│       - Static Website Hosting
│       - Public Access
└── cloudfront/
    └── cloudfront-distribution.tf: CDN
```

### 10. Cognito (통합 - 1번 apply)

```
erp-dev-Cognito/
├── main.tf (module 호출)
└── user-pool/
    ├── user-pool.tf:
    │   - Email login
    │   - Custom attributes (position, department, employeeId)
    │   - Lambda auto-confirm
    └── lambda.tf: Auto-confirm Lambda
```

---

## 🔧 리팩토링 필요 사항

### 1. Secret 이름 수정

**파일:** 02_HELM_CHART.md, 03_SECRETS_SETUP.md

**Before:**
```yaml
secretsManager:
  secrets:
    rds:
      name: prod/rds/password  # ❌ 틀림
```

**After:**
```yaml
secretsManager:
  secrets:
    rds:
      name: erp/dev/mysql  # ✅ 실제 이름
```

### 2. MongoDB Secret 제거

**파일:** 03_SECRETS_SETUP.md

**Before:**
```bash
aws secretsmanager create-secret --name prod/mongodb/uri ...  # ❌ 불필요
```

**After:**
```bash
# MongoDB는 Atlas 사용 (외부)
# Secrets Manager 생성 불필요
# ConfigMap에 URI 하드코딩 (개발 환경)
```

### 3. IAM 권한 추가

**파일:** 01_TERRAFORM.md, 04_BUILDSPEC.md

**codebuild-role.tf에 추가 필요:**
```hcl
# Secrets Manager 읽기 권한
resource "aws_iam_role_policy" "codebuild_secrets" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-secrets-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:ap-northeast-2:806332783810:secret:erp/*"
    }]
  })
}

# Parameter Store 읽기 권한
resource "aws_iam_role_policy" "codebuild_ssm" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-ssm-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = "arn:aws:ssm:ap-northeast-2:806332783810:parameter/erp/*"
    }]
  })
}

# ECR 이미지 스캔 권한
resource "aws_iam_role_policy" "codebuild_ecr_scan" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-ecr-scan-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:StartImageScan",
        "ecr:DescribeImageScanFindings"
      ]
      Resource = "*"
    }]
  })
}
```

### 4. Kafka 전용 Node 구성

**파일:** 01_TERRAFORM.md, 02_HELM_CHART.md

**eks-node-group.tf 수정:**
```hcl
# Kafka 전용 Node Group 추가
resource "aws_eks_node_group" "kafka" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.project_name}-${var.environment}-kafka-node-group"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.kafka.id
    version = "$Latest"
  }

  capacity_type = "ON_DEMAND"

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  taint {
    key    = "workload"
    value  = "kafka"
    effect = "NO_SCHEDULE"
  }

  labels = {
    workload = "kafka"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-kafka-node-group"
    Environment = var.environment
  }
}

# 기존 Node Group은 desired_size = 2로 변경
resource "aws_eks_node_group" "main" {
  # ...
  scaling_config {
    desired_size = 2  # 3 → 2
    max_size     = 3
    min_size     = 1
  }
}
```

**Helm Chart kafka.yaml 수정:**
```yaml
# templates/kafka.yaml
{{- if .Values.kafka.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka
  namespace: {{ .Values.namespace }}
spec:
  replicas: {{ .Values.kafka.replicaCount }}
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      # Kafka 전용 Node에만 배치
      nodeSelector:
        workload: kafka
      tolerations:
      - key: "workload"
        operator: "Equal"
        value: "kafka"
        effect: "NoSchedule"
      containers:
      - name: kafka
        image: "{{ .Values.kafka.image.repository }}:{{ .Values.kafka.image.tag }}"
        # ...
{{- end }}
```

**서비스 Pod Anti-Affinity (이미 구현됨):**
```yaml
# templates/deployment.yaml (이미 있음)
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - {{ $service.name }}
        topologyKey: topology.kubernetes.io/zone
```

---

## 📋 수정할 파일 목록

### 1. 01_TERRAFORM.md

**추가:**
- Step 3.5: IAM CodeBuild Role에 권한 추가 (Secrets Manager, Parameter Store, ECR Scan)
- Step 6.5: EKS Kafka 전용 Node Group 추가

### 2. 02_HELM_CHART.md

**수정:**
- values-dev.yaml: Secret 이름 `erp/dev/mysql`
- templates/kafka.yaml: nodeSelector + tolerations 추가

### 3. 03_SECRETS_SETUP.md

**수정:**
- MongoDB Secret 생성 제거
- Secret 이름 `erp/dev/mysql`로 수정
- External Secrets Operator만 설치

### 4. 04_BUILDSPEC.md

**수정:**
- env.secrets-manager: Secret 이름 수정
- env.parameter-store: 추가

---

지금 바로 수정하겠습니다!
