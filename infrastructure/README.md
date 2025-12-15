# ERP 인프라 (Terraform)

**IaC 도구**: Terraform 1.6+  
**클라우드**: AWS  
**리전**: ap-northeast-2 (서울)  
**최종 업데이트**: 2025-12-10

---

## Terraform 모듈 구조

### 설계 철학

**세분화 vs 통합 전략**

폴더는 세분화하고 각 tfstate 파일을 따로 저장하는 것이 나중에 콘솔에서 작업했을 때도 형상 맞춰주기 좋습니다.

급하게 콘솔로 RDS 파라미터 변경 시 → 해당 경로의 tfstate 파일은 RDS 파라미터 정보만 가지고 있기에 찾아보기 쉽고, 다른 리소스에 영향 없이 수정 가능합니다.

### 모듈 구조

```
infrastructure/terraform/dev/
├── erp-dev-VPC/                    # 세분화 (각각 독립 apply)
│   ├── vpc/                        # terraform apply 1
│   ├── subnet/                     # terraform apply 2
│   └── route-table/                # terraform apply 3
├── erp-dev-SecurityGroups/         # 세분화 (각각 독립 apply)
│   ├── eks-sg/
│   ├── rds-sg/
│   ├── elasticache-sg/
│   └── alb-sg/
├── erp-dev-Databases/              # 세분화 (각각 독립 apply)
│   ├── rds/
│   └── elasticache/
├── erp-dev-IAM/                    # 통합 (main.tf로 한 번에 apply)
│   ├── main.tf                     # 모듈 호출
│   ├── eks-cluster-role/
│   ├── eks-node-role/
│   ├── codebuild-role/
│   └── codepipeline-role/
├── erp-dev-EKS/                    # 통합 (main.tf로 한 번에 apply)
├── erp-dev-APIGateway/             # 통합 (main.tf로 한 번에 apply)
│   ├── nlb/
│   ├── target-groups/
│   ├── vpc-link/
│   └── api-gateway/
├── erp-dev-Frontend/               # 통합 (main.tf로 한 번에 apply)
│   ├── s3/
│   └── cloudfront/
├── erp-dev-LoadBalancerController/ # 단일 리소스
└── erp-dev-Secrets/                # 단일 리소스
```

---

## 세분화 전략 (erp-dev-SecurityGroups 예시)

**왜 세분화했는가?**

1. **독립적인 생명주기**: RDS SG 규칙 변경 시 EKS SG 영향 없음
2. **콘솔 작업 후 형상 관리 용이**: 급하게 콘솔에서 3307 포트 추가 → 해당 폴더만 terraform plan으로 확인
3. **State Lock 충돌 방지**: 4개 폴더 = 4개 독립 tfstate → 팀원 A가 RDS SG 수정 중, 팀원 B는 EKS SG 수정 가능
4. **빠른 Plan/Apply**: 전체 SG 한 번에 약 2분 → 개별 SG 약 20초 (10배 빠름)

**실행 방법**
```bash
cd erp-dev-SecurityGroups
cd eks-sg && terraform init && terraform apply -auto-approve
cd ../rds-sg && terraform init && terraform apply -auto-approve
cd ../elasticache-sg && terraform init && terraform apply -auto-approve
cd ../alb-sg && terraform init && terraform apply -auto-approve
```

**장점**: 변경 영향 범위 최소화, 콘솔 작업 후 형상 관리 쉬움, 팀 협업 용이, 빠른 피드백  
**단점**: 초기 구축 시 4번 실행 필요, 의존성 관리 필요

---

## 통합 전략 (erp-dev-IAM 예시)

**왜 통합했는가?**

1. **강한 의존성**: EKS Cluster Role과 Node Role은 함께 생성되어야 함
2. **상호 참조**: CodeBuild Role과 CodePipeline Role은 서로 참조
3. **공유 Policy**: IAM Policy는 여러 Role에서 공유
4. **원자성**: 모든 Role이 함께 생성되거나 함께 실패해야 함

**실행 방법**
```bash
cd erp-dev-IAM
terraform init
terraform apply -auto-approve
```

**장점**: 의존성 관리 자동, 원자성 보장, 간단한 실행  
**단점**: 한 Role 변경 시 전체 Plan 필요

---

## 배포 순서

```bash
cd infrastructure/terraform/dev

# 1. VPC (세분화)
cd erp-dev-VPC/vpc && terraform init && terraform apply -auto-approve
cd ../subnet && terraform init && terraform apply -auto-approve
cd ../route-table && terraform init && terraform apply -auto-approve

# 2. Security Groups (세분화)
cd ../../erp-dev-SecurityGroups
cd eks-sg && terraform init && terraform apply -auto-approve
cd ../rds-sg && terraform init && terraform apply -auto-approve
cd ../elasticache-sg && terraform init && terraform apply -auto-approve
cd ../alb-sg && terraform init && terraform apply -auto-approve

# 3. IAM (통합)
cd ../../erp-dev-IAM && terraform init && terraform apply -auto-approve

# 4. Databases (세분화)
cd ../erp-dev-Databases/rds && terraform init && terraform apply -auto-approve
cd ../elasticache && terraform init && terraform apply -auto-approve

# 5. Secrets (단일)
cd ../../erp-dev-Secrets && terraform init && terraform apply -auto-approve

# 6. EKS (통합)
cd ../erp-dev-EKS && terraform init && terraform apply -auto-approve

# 7. Load Balancer Controller (단일)
cd ../erp-dev-LoadBalancerController && terraform init && terraform apply -auto-approve

# 8. API Gateway (통합)
cd ../erp-dev-APIGateway && terraform init && terraform apply -auto-approve

# 9. Frontend (통합)
cd ../erp-dev-Frontend && terraform init && terraform apply -auto-approve
```

---

## AWS 리소스

**네트워크**: VPC, Subnet (Public × 2, Private × 2), NAT Gateway, Security Group × 4  
**컴퓨팅**: EKS 1.31, Worker Nodes (t3.small × 2~3)  
**데이터베이스**: RDS MySQL 8.0, ElastiCache Redis 7.0, MongoDB Atlas M0  
**로드밸런서**: NLB (Private), API Gateway (HTTP)  
**스토리지**: S3, ECR  
**CDN**: CloudFront  
**CI/CD**: CodePipeline × 4, CodeBuild × 4

---

## 주요 설정

**VPC CIDR**
```
VPC: 10.0.0.0/16
Public Subnet: 10.0.1.0/24, 10.0.2.0/24
Private Subnet: 10.0.10.0/24, 10.0.11.0/24
```

**EKS**
```
Cluster: erp-dev
Version: 1.31
Node Type: t3.small
Desired: 3 (Kafka 설치를 위해 1개 추가)
Min: 1, Max: 3
```

**RDS**
```
Engine: MySQL 8.0
Instance: db.t3.micro
Storage: 20GB
Multi-AZ: false
```

---

## 비용

**월 예상 비용**: $206

EKS $73, Worker Nodes $45 (3개), RDS $15, ElastiCache $12, NAT Gateway $32, NLB $16, 기타 $13

**Worker Node 3개 이유**: Kafka 설치를 위한 메모리 확보 (기존 2개 Node는 메모리 부족)

---

## 하이브리드 구조 미구현

### 현재 구조 (모두 EKS)

```
API Gateway (단일 진입점)
  ├─ /employees/*     → VPC Link → NLB → Employee Pods (2)
  ├─ /approvals/*     → VPC Link → NLB → Approval Pods (4) - Kafka
  └─ /notifications/* → VPC Link → NLB → Notification Pods (2) - WebSocket

총 8 Pods (Employee 2 + Approval Request 2 + Approval Processing 2 + Notification 2)
비용: EKS $82.30/월
```

### 하이브리드 구조였다면

**API Gateway의 장점 활용**

현재 프로젝트에서 API Gateway를 선택한 이유는 마이크로서비스 중앙 관리(인증/CORS)였습니다. API Gateway의 또 다른 강력한 기능은 **Lambda 직접 통합**입니다. VPC Link 없이 Lambda를 바로 호출할 수 있어, 간단한 API는 Lambda로 분리하면 비용 절감이 가능합니다.

**아키텍처:**
```
API Gateway (단일 진입점)
  ├─ /employees/*     → Lambda (직접 통합, VPC Link 불필요) → RDS Proxy → MySQL
  ├─ /approvals/*     → VPC Link → NLB → Approval Pods (4) - Kafka
  └─ /notifications/* → VPC Link → NLB → Notification Pods (2) - WebSocket

총 6 Pods (Approval Request 2 + Approval Processing 2 + Notification 2)
비용: EKS $61.73 (6 Pods) + Lambda $3 = $64.73 (21% 절감)
```

**Lambda 통합 방식:**

1. **API Gateway → Lambda (직접 통합)**
   - VPC Link 불필요
   - Lambda가 RDS Proxy 통해 MySQL 접근
   - Cold Start: 300~500ms (첫 요청만)

2. **API Gateway → VPC Link → NLB (기존 방식)**
   - WebSocket, Kafka Consumer는 EKS 유지
   - 지속적인 연결/장시간 실행 필요

**Lambda 전환 가능:**
- **Employee Service**: 간단한 CRUD, MySQL 조회만, 실행 시간 200ms

**Lambda 전환 불가:**
- **Notification**: WebSocket 연결 유지 필요 (Lambda는 요청-응답 모델)
- **Approval Services**: Kafka Consumer 장시간 실행 (Lambda 15분 제한 초과)

**API Gateway 라우팅 설정:**
```yaml
# Lambda 통합
/employees/{proxy+}:
  ANY:
    integration: AWS_PROXY
    uri: arn:aws:lambda:ap-northeast-2:xxx:function:employee-service

# NLB 통합 (VPC Link)
/notifications/{proxy+}:
  ANY:
    integration: HTTP_PROXY
    connectionType: VPC_LINK
    uri: http://nlb-internal.amazonaws.com/notifications/{proxy}

/approvals/{proxy+}:
  ANY:
    integration: HTTP_PROXY
    connectionType: VPC_LINK
    uri: http://nlb-internal.amazonaws.com/approvals/{proxy}
```

**왜 구현 못 했나:**
- 14일 기간 제약
- Lambda + RDS Proxy 연결 설정
- API Gateway 라우팅 분기 구현
- 학습 우선순위: Kafka 비동기 메시징

**상세 비용 비교:**

| 항목 | 현재 (모두 EKS) | 하이브리드 |
|------|----------------|-----------|
| EKS | $82.30 (8 Pods) | $61.73 (6 Pods) |
| Lambda | $0 | $3 |
| 합계 | $82.30 | $64.73 |

**핵심:**
- API Gateway는 Lambda 직접 통합 가능 (VPC Link 불필요)
- 간단한 API는 Lambda, 복잡한 API는 NLB → EKS
- 하나의 API Gateway에서 Lambda와 NLB를 동시에 사용하는 하이브리드 구조

---

## 트러블슈팅

**Terraform State Lock**
```bash
terraform force-unlock <lock-id>
```

**EKS 노드 생성 실패**
```bash
aws iam get-role --role-name erp-dev-eks-node-role
```

---

## 라이선스

MIT License
