# DevOps 신입 포트폴리오 분석: CGV vs ERP 프로젝트

**작성일**: 2025-12-28  
**목적**: 객관적인 포트폴리오 평가 및 개선 방향 제시

---

## 전제 조건

### CGV 프로젝트에서의 역할
- **담당**: 개발계 인프라 구축
- **경험**: Helm Chart 받아서 코드 수정, 배포
- **한계**: CI/CD 파이프라인 전체 설계 경험 부족 (팀에서 구축된 것 활용)

### ERP 프로젝트 목표
- AWS DVA 학습 후 AWS 네이티브 도구 실전 적용
- CI/CD 파이프라인을 처음부터 끝까지 직접 설계
- CGV에서 경험하지 못한 부분 보완

### 현재 진행 상황
- 01~05단계: 완료 (Terraform, Helm Chart, Lambda)
- 06단계: Step 3까지 완료 (Parameter Store, CloudWatch, X-Ray)
- 06단계: Step 4 진행 예정 (buildspec.yml 작성)

---

## Part 1: CI/CD 구조 비교

### CGV 프로젝트 CI/CD

**CI (GitLab Runner):**
```
GitLab Commit
  ↓
GitLab Runner 실행
  ↓
SonarQube (코드 품질 분석)
  ↓
Dependency Check (취약점 스캔)
  ↓
Docker Build
  ↓
ECR Push (PrivateLink)
```

**CD (Argo CD):**
```
운영계/QA (Pull 방식):
GitLab 저장소 → Argo CD Polling → Sync → EKS 배포

개발계 (Push 방식):
ECR 새 이미지 → ImageUpdater 감지 → Argo CD Sync → EKS 배포
```

**특징:**
- GitOps 원칙 (Git이 Single Source of Truth)
- 정적 분석 강화 (SonarQube, Dependency Check)
- 환경별 배포 전략 (Prod 수동, Dev 자동)
- 팀 구축 파이프라인 활용

---

### ERP 프로젝트 CI/CD (재구축 전 - 문제)

**CI/CD (CodePipeline):**
```
GitHub Push
  ↓
CodePipeline 트리거 (4개 파이프라인)
  ↓
CodeBuild (서비스별 buildspec.yml)
  ↓
kubectl set image (이미지만 변경)
```

**문제점:**
1. 서비스별 독립 파이프라인 (4개)
2. kubectl set image만 실행 (Manifests 변경 반영 안 됨)
3. Plain YAML (환경 분리 불가)
4. Secret 평문 하드코딩
5. Git이 진실이 아님

---

### ERP 프로젝트 CI/CD (재구축 후 - 목표)

**CI/CD (CodePipeline):**
```
GitHub Push
  ↓
CodePipeline 트리거 (1개 통합)
  ↓
CodeBuild (루트 buildspec.yml)
  ├─ Git diff로 변경 감지
  ├─ 변경된 서비스만 빌드
  ├─ ECR 이미지 스캔
  ├─ Helm values 업데이트
  └─ helm upgrade (전체 리소스 배포)
```

**개선 사항:**
1. 단일 파이프라인 (관리 단순화)
2. helm upgrade (Manifests 자동 반영)
3. Helm Chart (환경 분리 가능)
4. Secrets Manager (보안 강화)
5. Git이 진실 (Source of Truth)

**추가 기능 (CGV 대비):**
- Parameter Store (설정 중앙 관리)
- CloudWatch Logs (로그 중앙 집중)
- X-Ray (서비스 간 트레이싱)
- ECR 자동 스캔 (Critical 발견 시 배포 중단)
- Git diff 변경 감지 (선택적 빌드)

---

## Part 2: 객관적 평가

### 적절한 부분 (강점)

#### 1. AWS 네이티브 도구 실전 적용 ⭐⭐⭐⭐⭐

**CGV에서 못한 것:**
- GitLab CI/CD 코드를 받아서 사용
- AWS 도구 미경험

**ERP에서 달성:**
- CodePipeline, CodeBuild 직접 설계
- Parameter Store, Secrets Manager 통합
- CloudWatch Logs, X-Ray 설정
- IAM Role 권한 설계

**면접 포인트:**
- "CGV에서는 GitLab을 사용했지만, AWS 네이티브 도구를 경험하고 싶어 ERP에서는 CodePipeline을 선택했습니다"
- "DVA 학습 후 Parameter Store, X-Ray 등을 실전에 적용했습니다"

---

#### 2. Terraform 전체 인프라 코드화 ⭐⭐⭐⭐

**CGV에서 못한 것:**
- Terraform 경험 제한적 (개발계 일부만)

**ERP에서 달성:**
- VPC부터 EKS까지 전체 인프라 Terraform 구현
- 모듈 구조 설계 (세분화 vs 통합)
- Remote State 관리
- 98개 .tf 파일 작성

**면접 포인트:**
- "SecurityGroups는 세분화, IAM은 통합하여 변경 빈도에 따라 구조 설계했습니다"
- "실무 조언을 반영하여 유지보수 용이한 구조로 구축했습니다"

---

#### 3. Helm Chart 직접 작성 ⭐⭐⭐⭐⭐

**CGV에서 못한 것:**
- Helm Chart를 받아서 values만 수정

**ERP에서 달성:**
- Chart.yaml, templates/ 전체 작성
- Go 템플릿 문법 활용 (range, if)
- values-dev.yaml로 환경 분리
- External Secrets Operator 통합

**면접 포인트:**
- "CGV에서는 Helm Chart를 받아서 사용했지만, ERP에서는 처음부터 직접 작성했습니다"
- "1개 템플릿으로 4개 서비스 Deployment 생성하는 구조를 설계했습니다"

---

#### 4. Lambda 하이브리드 아키텍처 ⭐⭐⭐⭐

**CGV에서 없던 것:**
- 모든 서비스 EKS

**ERP에서 달성:**
- Employee Service를 Lambda로 전환
- 비용 21% 절감 ($82.30 → $64.73)
- Lambda Web Adapter로 코드 수정 없이 전환
- API Gateway 직접 통합 (VPC Link 불필요)

**면접 포인트:**
- "간단한 CRUD는 Lambda, 복잡한 로직은 EKS로 분리하여 비용 최적화했습니다"
- "Lambda Web Adapter로 기존 Spring Boot 코드를 그대로 사용했습니다"

---

#### 5. 마이크로서비스 통신 패턴 경험 ⭐⭐⭐⭐⭐

**CGV에서 없던 것:**
- 단일 API 서버 (서비스 간 통신 없음)

**ERP에서 달성:**
- gRPC 동기 통신 → Kafka 비동기 전환
- 성능 85% 개선 (850ms → 120ms)
- 장애 격리 (한 서비스 다운되어도 메시지 보존)

**면접 포인트:**
- "gRPC로 먼저 구현하여 동기 통신의 블로킹 문제를 직접 경험했습니다"
- "Kafka로 전환하여 응답 시간 85% 개선, 에러율 0%로 감소시켰습니다"

---

### 아쉬운 부분 (개선 필요)

#### 1. 정적 분석 도구 부재 ⭐⭐

**CGV 강점:**
- SonarQube (코드 품질)
- Dependency Check (취약점)
- 빌드 전 차단

**ERP 현황:**
- ECR 이미지 스캔만 존재
- 빌드 후 스캔 (늦음)
- 코드 품질 분석 없음

**개선 방안:**
```yaml
# buildspec.yml에 추가
pre_build:
  - mvn sonar:sonar (SonarQube)
  - mvn dependency-check:check
  - 기준 미달 시 빌드 중단
```

**우선순위**: 중 (면접에서 "추가 예정"으로 설명 가능)

---

#### 2. DR (재해 복구) 없음 ⭐⭐⭐

**CGV 강점:**
- Aurora Global DB (서울 ↔ 도쿄)
- Step Functions 자동 복구
- RTO 5분, RPO 1초
- ECR Cross-Region Replication

**ERP 현황:**
- 단일 리전 (서울)
- DR 계획 없음
- 장애 시 수동 복구

**개선 방안:**
- Multi-Region 구성은 비용 문제로 현실적으로 어려움
- 대신 "Backup & Restore" 전략 추가:
  - RDS 자동 백업 (Point-in-Time Recovery)
  - Velero로 Kubernetes 리소스 백업
  - 복구 절차 문서화

**우선순위**: 하 (개인 프로젝트 범위 초과, 면접에서 "비용 제약" 설명)

---

#### 3. 모니터링 & 알림 부족 ⭐⭐⭐⭐

**CGV 강점:**
- Datadog + CloudWatch 통합
- Slack 실시간 알림
- Route53 Health Check 모니터링
- DR 장애 자동 감지

**ERP 현황:**
- CloudWatch Logs (로그 수집만)
- X-Ray (트레이싱만)
- 알림 없음
- 대시보드 없음

**개선 방안:**
1. **CloudWatch Alarm 추가** (30분)
   - ERROR 로그 10회 이상 → SNS → Email
   - Pod 재시작 감지 → 알림

2. **Prometheus + Grafana** (2시간)
   - Kafka Lag 모니터링
   - Pod CPU/Memory 대시보드
   - HPA 스케일링 추적

**우선순위**: 상 (실무 필수, 구현 시간 짧음)

---

#### 4. GitOps 미적용 ⭐⭐⭐

**CGV 강점:**
- Argo CD Pull 방식
- Git이 Single Source of Truth
- Drift Detection (Git vs 클러스터 비교)

**ERP 현황:**
- CodePipeline Push 방식
- buildspec.yml에서 helm upgrade
- Git이 진실이지만 Drift 감지 없음

**개선 방안:**
- Argo CD 추가 (CodePipeline과 병행)
- 또는 현재 구조 유지하고 면접에서 차이점 설명

**우선순위**: 중 (학습 가치 높지만 시간 소요)

---

#### 5. 백업 전략 없음 ⭐⭐

**CGV 강점:**
- AWS Backup (GitLab EC2, 3시간 주기)
- Velero (Kubernetes 리소스)

**ERP 현황:**
- RDS 자동 백업만 (기본 설정)
- Kubernetes 리소스 백업 없음

**개선 방안:**
- Velero 설치 (1시간)
- S3 백업 설정
- 복구 테스트

**우선순위**: 중 (실무 중요하지만 개인 프로젝트에서는 선택)

---

## Part 3: 세부 비교 분석

### 1. Terraform 사용 수준

| 항목 | CGV | ERP |
|------|-----|-----|
| **작성 범위** | 개발계 일부 | 전체 인프라 (98개 .tf) |
| **모듈 구조** | 불명 | 세분화/통합 전략 설계 |
| **Remote State** | 불명 | S3 + DynamoDB Lock |
| **변수 관리** | 불명 | 환경별 tfvars |
| **의존성 관리** | 불명 | data source 활용 |

**ERP 강점:**
- VPC부터 Cognito까지 전체 구현
- SecurityGroups 세분화, IAM 통합 등 실무 패턴 적용
- 98개 파일로 대규모 인프라 관리 경험

**면접 어필:**
- "SecurityGroups는 변경 빈도가 높아 세분화, IAM은 Trust Policy 일관성을 위해 통합했습니다"
- "Remote State로 모듈 간 의존성을 data source로 해결했습니다"

---

### 2. Kubernetes 사용 수준

| 항목 | CGV | ERP |
|------|-----|-----|
| **Helm Chart** | 받아서 수정 | 처음부터 작성 |
| **템플릿 작성** | 경험 없음 | Go 템플릿 활용 |
| **리소스 종류** | Deployment, Service | Deployment, Service, HPA, TGB, ExternalSecret |
| **네트워크** | Ingress (ALB) | TargetGroupBinding (NLB) |
| **Secret 관리** | 불명 | External Secrets Operator |
| **로그 수집** | 불명 | Fluent Bit DaemonSet |
| **트레이싱** | 없음 | X-Ray DaemonSet |

**ERP 강점:**
- Helm Chart 전체 구조 이해 (Chart.yaml, templates/, values)
- TargetGroupBinding으로 AWS NLB 통합
- External Secrets Operator로 Secrets Manager 연동
- DaemonSet 활용 (Fluent Bit, X-Ray)

**면접 어필:**
- "CGV에서는 Helm Chart를 받아서 사용했지만, ERP에서는 템플릿부터 직접 작성했습니다"
- "TargetGroupBinding으로 Kubernetes Service와 AWS NLB를 통합했습니다"

---

### 3. AWS 리소스 사용 범위

| 서비스 | CGV | ERP | ERP 활용도 |
|--------|-----|-----|-----------|
| **Compute** | EKS, EC2 | EKS, Lambda | ⭐⭐⭐⭐ (하이브리드) |
| **Network** | ALB, Route53, CloudFront | NLB, API Gateway, CloudFront | ⭐⭐⭐⭐⭐ (API Gateway 통합) |
| **Database** | Aurora Global DB | RDS, ElastiCache | ⭐⭐⭐ (단일 리전) |
| **Storage** | S3 | S3, ECR | ⭐⭐⭐⭐ |
| **Security** | WAF, Secret Manager | Secrets Manager, Cognito | ⭐⭐⭐⭐ |
| **CI/CD** | 없음 (GitLab) | CodePipeline, CodeBuild | ⭐⭐⭐⭐⭐ |
| **Monitoring** | CloudWatch, Datadog | CloudWatch, X-Ray | ⭐⭐⭐⭐ |
| **Messaging** | Kinesis | Kafka (EKS) | ⭐⭐⭐ (관리형 아님) |
| **Config** | 불명 | Parameter Store | ⭐⭐⭐⭐⭐ |
| **DR** | Step Functions, EventBridge | 없음 | ⭐ |

**ERP 차별화 포인트:**
1. **API Gateway**: 마이크로서비스 단일 진입점
2. **Lambda**: 하이브리드 아키텍처
3. **CodePipeline**: AWS 네이티브 CI/CD
4. **Parameter Store**: 설정 중앙 관리
5. **X-Ray**: 분산 트레이싱

**CGV 차별화 포인트:**
1. **Aurora Global DB**: 멀티 리전 복제
2. **Step Functions**: DR 자동화
3. **WAF**: 웹 방화벽
4. **Kinesis**: 관리형 스트리밍
5. **Datadog**: 통합 모니터링

---

# DevOps 신입 포트폴리오 분석: CGV vs ERP 프로젝트 (Part 1)

**작성일**: 2025-12-28  
**목적**: 객관적인 포트폴리오 평가 및 개선 방향 제시

---

## 전제 조건

### CGV 프로젝트에서의 역할
- **담당**: 개발계 인프라 구축
- **경험**: Helm Chart 받아서 코드 수정, 배포
- **한계**: CI/CD 파이프라인 전체 설계 경험 부족 (팀에서 구축된 것 활용)

### ERP 프로젝트 목표
- AWS DVA 학습 후 AWS 네이티브 도구 실전 적용
- CI/CD 파이프라인을 처음부터 끝까지 직접 설계
- CGV에서 경험하지 못한 부분 보완

### 현재 진행 상황
- 01~05단계: 완료 (Terraform, Helm Chart, Lambda)
- 06단계: Step 3까지 완료 (Parameter Store, CloudWatch, X-Ray)
- 06단계: Step 4 진행 예정 (buildspec.yml 작성)

---

## Part 1: CI/CD 구조 비교

### CGV 프로젝트 CI/CD

**CI (GitLab Runner):**
```
GitLab Commit
  ↓
GitLab Runner 실행
  ↓
SonarQube (코드 품질 분석)
  ↓
Dependency Check (취약점 스캔)
  ↓
Docker Build
  ↓
ECR Push (PrivateLink)
```

**CD (Argo CD):**
```
운영계/QA (Pull 방식):
GitLab 저장소 → Argo CD Polling → Sync → EKS 배포

개발계 (Push 방식):
ECR 새 이미지 → ImageUpdater 감지 → Argo CD Sync → EKS 배포
```

**특징:**
- GitOps 원칙 (Git이 Single Source of Truth)
- 정적 분석 강화 (SonarQube, Dependency Check)
- 환경별 배포 전략 (Prod 수동, Dev 자동)
- 팀 구축 파이프라인 활용

---

### ERP 프로젝트 CI/CD (재구축 전 - 문제)

**CI/CD (CodePipeline):**
```
GitHub Push
  ↓
CodePipeline 트리거 (4개 파이프라인)
  ↓
CodeBuild (서비스별 buildspec.yml)
  ↓
kubectl set image (이미지만 변경)
```

**문제점:**
1. 서비스별 독립 파이프라인 (4개)
2. kubectl set image만 실행 (Manifests 변경 반영 안 됨)
3. Plain YAML (환경 분리 불가)
4. Secret 평문 하드코딩
5. Git이 진실이 아님

---

### ERP 프로젝트 CI/CD (재구축 후 - 목표)

**CI/CD (CodePipeline):**
```
GitHub Push
  ↓
CodePipeline 트리거 (1개 통합)
  ↓
CodeBuild (루트 buildspec.yml)
  ├─ Git diff로 변경 감지
  ├─ 변경된 서비스만 빌드
  ├─ ECR 이미지 스캔
  ├─ Helm values 업데이트
  └─ helm upgrade (전체 리소스 배포)
```

**개선 사항:**
1. 단일 파이프라인 (관리 단순화)
2. helm upgrade (Manifests 자동 반영)
3. Helm Chart (환경 분리 가능)
4. Secrets Manager (보안 강화)
5. Git이 진실 (Source of Truth)

**추가 기능 (CGV 대비):**
- Parameter Store (설정 중앙 관리)
- CloudWatch Logs (로그 중앙 집중)
- X-Ray (서비스 간 트레이싱)
- ECR 자동 스캔 (Critical 발견 시 배포 중단)
- Git diff 변경 감지 (선택적 빌드)

---

## Part 2: 객관적 평가

### 적절한 부분 (강점)

#### 1. AWS 네이티브 도구 실전 적용 ⭐⭐⭐⭐⭐

**CGV에서 못한 것:**
- GitLab CI/CD 코드를 받아서 사용
- AWS 도구 미경험

**ERP에서 달성:**
- CodePipeline, CodeBuild 직접 설계
- Parameter Store, Secrets Manager 통합
- CloudWatch Logs, X-Ray 설정
- IAM Role 권한 설계

**면접 포인트:**
- "CGV에서는 GitLab을 사용했지만, AWS 네이티브 도구를 경험하고 싶어 ERP에서는 CodePipeline을 선택했습니다"
- "DVA 학습 후 Parameter Store, X-Ray 등을 실전에 적용했습니다"

---

#### 2. Terraform 전체 인프라 코드화 ⭐⭐⭐⭐

**CGV에서 못한 것:**
- Terraform 경험 제한적 (개발계 일부만)

**ERP에서 달성:**
- VPC부터 EKS까지 전체 인프라 Terraform 구현
- 모듈 구조 설계 (세분화 vs 통합)
- Remote State 관리
- 98개 .tf 파일 작성

**면접 포인트:**
- "SecurityGroups는 세분화, IAM은 통합하여 변경 빈도에 따라 구조 설계했습니다"
- "실무 조언을 반영하여 유지보수 용이한 구조로 구축했습니다"

---

#### 3. Helm Chart 직접 작성 ⭐⭐⭐⭐⭐

**CGV에서 못한 것:**
- Helm Chart를 받아서 values만 수정

**ERP에서 달성:**
- Chart.yaml, templates/ 전체 작성
- Go 템플릿 문법 활용 (range, if)
- values-dev.yaml로 환경 분리
- External Secrets Operator 통합

**면접 포인트:**
- "CGV에서는 Helm Chart를 받아서 사용했지만, ERP에서는 처음부터 직접 작성했습니다"
- "1개 템플릿으로 4개 서비스 Deployment 생성하는 구조를 설계했습니다"

---

#### 4. Lambda 하이브리드 아키텍처 ⭐⭐⭐⭐

**CGV에서 없던 것:**
- 모든 서비스 EKS

**ERP에서 달성:**
- Employee Service를 Lambda로 전환
- 비용 21% 절감 ($82.30 → $64.73)
- Lambda Web Adapter로 코드 수정 없이 전환
- API Gateway 직접 통합 (VPC Link 불필요)

**면접 포인트:**
- "간단한 CRUD는 Lambda, 복잡한 로직은 EKS로 분리하여 비용 최적화했습니다"
- "Lambda Web Adapter로 기존 Spring Boot 코드를 그대로 사용했습니다"

---

#### 5. 마이크로서비스 통신 패턴 경험 ⭐⭐⭐⭐⭐

**CGV에서 없던 것:**
- 단일 API 서버 (서비스 간 통신 없음)

**ERP에서 달성:**
- gRPC 동기 통신 → Kafka 비동기 전환
- 성능 85% 개선 (850ms → 120ms)
- 장애 격리 (한 서비스 다운되어도 메시지 보존)

**면접 포인트:**
- "gRPC로 먼저 구현하여 동기 통신의 블로킹 문제를 직접 경험했습니다"
- "Kafka로 전환하여 응답 시간 85% 개선, 에러율 0%로 감소시켰습니다"

---

### 아쉬운 부분 (개선 필요)

#### 1. 정적 분석 도구 부재 ⭐⭐

**CGV 강점:**
- SonarQube (코드 품질)
- Dependency Check (취약점)
- 빌드 전 차단

**ERP 현황:**
- ECR 이미지 스캔만 존재
- 빌드 후 스캔 (늦음)
- 코드 품질 분석 없음

**개선 방안:**
```yaml
# buildspec.yml에 추가
pre_build:
  - mvn sonar:sonar (SonarQube)
  - mvn dependency-check:check
  - 기준 미달 시 빌드 중단
```

**우선순위**: 중 (면접에서 "추가 예정"으로 설명 가능)

---

#### 2. DR (재해 복구) 없음 ⭐⭐⭐

**CGV 강점:**
- Aurora Global DB (서울 ↔ 도쿄)
- Step Functions 자동 복구
- RTO 5분, RPO 1초
- ECR Cross-Region Replication

**ERP 현황:**
- 단일 리전 (서울)
- DR 계획 없음
- 장애 시 수동 복구

**개선 방안:**
- Multi-Region 구성은 비용 문제로 현실적으로 어려움
- 대신 "Backup & Restore" 전략 추가:
  - RDS 자동 백업 (Point-in-Time Recovery)
  - Velero로 Kubernetes 리소스 백업
  - 복구 절차 문서화

**우선순위**: 하 (개인 프로젝트 범위 초과, 면접에서 "비용 제약" 설명)

---

#### 3. 모니터링 & 알림 부족 ⭐⭐⭐⭐

**CGV 강점:**
- Datadog + CloudWatch 통합
- Slack 실시간 알림
- Route53 Health Check 모니터링
- DR 장애 자동 감지

**ERP 현황:**
- CloudWatch Logs (로그 수집만)
- X-Ray (트레이싱만)
- 알림 없음
- 대시보드 없음

**개선 방안:**
1. **CloudWatch Alarm 추가** (30분)
   - ERROR 로그 10회 이상 → SNS → Email
   - Pod 재시작 감지 → 알림

2. **Prometheus + Grafana** (2시간)
   - Kafka Lag 모니터링
   - Pod CPU/Memory 대시보드
   - HPA 스케일링 추적

**우선순위**: 상 (실무 필수, 구현 시간 짧음)

---

#### 4. GitOps 미적용 ⭐⭐⭐

**CGV 강점:**
- Argo CD Pull 방식
- Git이 Single Source of Truth
- Drift Detection (Git vs 클러스터 비교)

**ERP 현황:**
- CodePipeline Push 방식
- buildspec.yml에서 helm upgrade
- Git이 진실이지만 Drift 감지 없음

**개선 방안:**
- Argo CD 추가 (CodePipeline과 병행)
- 또는 현재 구조 유지하고 면접에서 차이점 설명

**우선순위**: 중 (학습 가치 높지만 시간 소요)

---

#### 5. 백업 전략 없음 ⭐⭐

**CGV 강점:**
- AWS Backup (GitLab EC2, 3시간 주기)
- Velero (Kubernetes 리소스)

**ERP 현황:**
- RDS 자동 백업만 (기본 설정)
- Kubernetes 리소스 백업 없음

**개선 방안:**
- Velero 설치 (1시간)
- S3 백업 설정
- 복구 테스트

**우선순위**: 중 (실무 중요하지만 개인 프로젝트에서는 선택)
# DevOps 신입 포트폴리오 분석: CGV vs ERP 프로젝트 (Part 2)

## Part 3: 세부 비교 분석

### 1. Terraform 사용 수준

| 항목 | CGV | ERP |
|------|-----|-----|
| **작성 범위** | 개발계 일부 | 전체 인프라 (98개 .tf) |
| **모듈 구조** | 불명 | 세분화/통합 전략 설계 |
| **Remote State** | 불명 | S3 + DynamoDB Lock |
| **변수 관리** | 불명 | 환경별 tfvars |
| **의존성 관리** | 불명 | data source 활용 |

**ERP 강점:**
- VPC부터 Cognito까지 전체 구현
- SecurityGroups 세분화, IAM 통합 등 실무 패턴 적용
- 98개 파일로 대규모 인프라 관리 경험

**면접 어필:**
- "SecurityGroups는 변경 빈도가 높아 세분화, IAM은 Trust Policy 일관성을 위해 통합했습니다"
- "Remote State로 모듈 간 의존성을 data source로 해결했습니다"

---

### 2. Kubernetes 사용 수준

| 항목 | CGV | ERP |
|------|-----|-----|
| **Helm Chart** | 받아서 수정 | 처음부터 작성 |
| **템플릿 작성** | 경험 없음 | Go 템플릿 활용 |
| **리소스 종류** | Deployment, Service | Deployment, Service, HPA, TGB, ExternalSecret |
| **네트워크** | Ingress (ALB) | TargetGroupBinding (NLB) |
| **Secret 관리** | 불명 | External Secrets Operator |
| **로그 수집** | 불명 | Fluent Bit DaemonSet |
| **트레이싱** | 없음 | X-Ray DaemonSet |

**ERP 강점:**
- Helm Chart 전체 구조 이해 (Chart.yaml, templates/, values)
- TargetGroupBinding으로 AWS NLB 통합
- External Secrets Operator로 Secrets Manager 연동
- DaemonSet 활용 (Fluent Bit, X-Ray)

**면접 어필:**
- "CGV에서는 Helm Chart를 받아서 사용했지만, ERP에서는 템플릿부터 직접 작성했습니다"
- "TargetGroupBinding으로 Kubernetes Service와 AWS NLB를 통합했습니다"

---

### 3. AWS 리소스 사용 범위

| 서비스 | CGV | ERP | ERP 활용도 |
|--------|-----|-----|-----------|
| **Compute** | EKS, EC2 | EKS, Lambda | ⭐⭐⭐⭐ (하이브리드) |
| **Network** | ALB, Route53, CloudFront | NLB, API Gateway, CloudFront | ⭐⭐⭐⭐⭐ (API Gateway 통합) |
| **Database** | Aurora Global DB | RDS, ElastiCache | ⭐⭐⭐ (단일 리전) |
| **Storage** | S3 | S3, ECR | ⭐⭐⭐⭐ |
| **Security** | WAF, Secret Manager | Secrets Manager, Cognito | ⭐⭐⭐⭐ |
| **CI/CD** | 없음 (GitLab) | CodePipeline, CodeBuild | ⭐⭐⭐⭐⭐ |
| **Monitoring** | CloudWatch, Datadog | CloudWatch, X-Ray | ⭐⭐⭐⭐ |
| **Messaging** | Kinesis | Kafka (EKS) | ⭐⭐⭐ (관리형 아님) |
| **Config** | 불명 | Parameter Store | ⭐⭐⭐⭐⭐ |
| **DR** | Step Functions, EventBridge | 없음 | ⭐ |

**ERP 차별화 포인트:**
1. **API Gateway**: 마이크로서비스 단일 진입점
2. **Lambda**: 하이브리드 아키텍처
3. **CodePipeline**: AWS 네이티브 CI/CD
4. **Parameter Store**: 설정 중앙 관리
5. **X-Ray**: 분산 트레이싱

**CGV 차별화 포인트:**
1. **Aurora Global DB**: 멀티 리전 복제
2. **Step Functions**: DR 자동화
3. **WAF**: 웹 방화벽
4. **Kinesis**: 관리형 스트리밍
5. **Datadog**: 통합 모니터링

---

### 4. 아키텍처 복잡도

#### CGV 아키텍처
```
사용자
  ↓
CloudFront (CDN)
  ↓
Route53 (Health Check)
  ↓
ALB (Ingress)
  ↓
EKS (API Server)
  ├─ Redis (Queue)
  ├─ Kinesis (Stream)
  └─ Aurora Global DB
```

**특징:**
- 단일 API 서버 (모놀리식 구조)
- 큐 시스템 (Redis + Kinesis)
- 멀티 리전 DB
- DR 자동화

---

#### ERP 아키텍처
```
사용자
  ↓
CloudFront (CDN)
  ↓
API Gateway (단일 진입점)
  ├─ Lambda (Employee Service)
  └─ NLB
      ↓
      EKS (3개 마이크로서비스)
      ├─ Approval Request
      ├─ Approval Processing
      └─ Notification
      ↓
      Kafka (비동기 통신)
      ↓
      RDS, ElastiCache, MongoDB
```

**특징:**
- 마이크로서비스 (4개 독립 서비스)
- 하이브리드 (Lambda + EKS)
- 비동기 통신 (Kafka)
- 단일 리전

---

### 5. 비용 최적화

#### CGV
- **비용 정보 없음** (팀 프로젝트)
- 추정: EKS + Aurora Global DB + Kinesis = 높은 비용

#### ERP
- **총 비용**: $64.73/월
- **Lambda 전환 효과**: 21% 절감 ($82.30 → $64.73)
- **비용 구성**:
  - EKS: $73 (Control Plane)
  - EC2: $30 (t3.medium 2대)
  - RDS: $15 (db.t3.micro)
  - 기타: $10 (NAT, ALB, S3 등)

**면접 어필:**
- "Employee Service를 Lambda로 전환하여 월 $17.57 절감했습니다"
- "비용 모니터링을 통해 최적화 포인트를 찾았습니다"

---

### 6. 보안 설계

#### CGV
- WAF (웹 방화벽)
- PrivateLink (ECR 접근)
- Secret Manager
- 불명 (인증/인가)

#### ERP
- Cognito (인증/인가)
- Secrets Manager (DB 자격증명)
- Parameter Store (설정 암호화)
- Security Groups (최소 권한)
- IAM Role (Pod별 권한)

**ERP 강점:**
- Cognito JWT 토큰 기반 인증
- External Secrets Operator로 Secret 자동 동기화
- IAM Role for Service Account (IRSA)

**면접 어필:**
- "Cognito로 JWT 토큰 기반 인증을 구현했습니다"
- "Secrets Manager와 Kubernetes를 External Secrets Operator로 통합했습니다"

---

### 7. 성능 최적화

#### CGV
- Redis Queue (트래픽 버퍼링)
- Kinesis (스트림 처리)
- KEDA (이벤트 기반 스케일링)
- Karpenter (빠른 노드 프로비저닝)

#### ERP
- Kafka (비동기 통신)
- ElastiCache (캐싱)
- HPA (CPU 기반 스케일링)
- CloudFront (정적 콘텐츠 캐싱)

**CGV 강점:**
- KEDA + Karpenter 조합 (더 빠른 스케일링)
- Kinesis (관리형 스트리밍)

**ERP 강점:**
- Kafka로 85% 성능 개선 실증
- gRPC → Kafka 전환 경험

**면접 어필:**
- "gRPC 동기 통신의 블로킹 문제를 직접 경험하고 Kafka로 해결했습니다"
- "응답 시간 850ms → 120ms로 개선했습니다"

---

## Part 4: 면접 대응 전략

### 1. CGV 프로젝트 질문 대응

**Q: CGV에서 CI/CD를 어떻게 구축했나요?**

**A (정직한 답변):**
"CGV에서는 팀에서 구축한 GitLab CI/CD 파이프라인을 활용했습니다. 저는 개발계 인프라를 담당하여 Helm Chart를 받아 values를 수정하고 배포하는 역할을 했습니다. 파이프라인 전체를 설계한 경험은 없었기 때문에, ERP 프로젝트에서는 CodePipeline을 처음부터 직접 설계하여 이 부분을 보완했습니다."

**포인트:**
- 솔직하게 역할 범위 인정
- ERP에서 보완한 점 강조
- 학습 의지 표현

---

**Q: Argo CD를 사용해봤나요?**

**A:**
"CGV에서 Argo CD가 구축되어 있었지만, 제가 직접 설정하거나 관리한 경험은 없습니다. GitOps의 장점은 이해하고 있으며, ERP 프로젝트에서는 CodePipeline을 사용했지만 향후 Argo CD를 추가하여 Pull 방식 배포를 경험해보고 싶습니다."

**포인트:**
- 경험 범위 명확히
- GitOps 개념 이해 표현
- 학습 계획 제시

---

**Q: SonarQube로 코드 품질을 어떻게 관리했나요?**

**A:**
"CGV에서는 SonarQube가 CI 파이프라인에 통합되어 있었고, 코드 품질 기준을 통과해야 빌드가 진행되었습니다. ERP 프로젝트에서는 아직 SonarQube를 추가하지 않았지만, buildspec.yml에 pre_build 단계로 추가할 계획입니다."

**포인트:**
- CGV 경험 활용
- ERP 개선 계획 제시

---

### 2. ERP 프로젝트 질문 대응

**Q: 왜 CodePipeline을 선택했나요?**

**A:**
"CGV에서는 GitLab을 사용했기 때문에 AWS 네이티브 CI/CD 도구를 경험하지 못했습니다. DVA 자격증 학습 후 CodePipeline, CodeBuild, Parameter Store 등을 실전에 적용하고 싶어 ERP 프로젝트에서 선택했습니다. AWS 환경에서는 다른 서비스와의 통합이 자연스럽다는 장점도 있었습니다."

**포인트:**
- 명확한 선택 이유
- 학습 목표 달성
- AWS 통합 장점

---

**Q: DR 계획이 없는데 괜찮나요?**

**A:**
"개인 프로젝트 특성상 비용 제약으로 Multi-Region 구성은 어려웠습니다. 대신 RDS 자동 백업과 Point-in-Time Recovery를 활성화했고, 향후 Velero로 Kubernetes 리소스 백업을 추가할 계획입니다. 실무에서는 CGV처럼 Aurora Global DB와 Step Functions를 활용한 DR 자동화가 필요하다고 생각합니다."

**포인트:**
- 현실적인 제약 인정
- 대안 제시
- 실무 이해도 표현

---

**Q: 모니터링이 부족한 것 같은데요?**

**A:**
"현재 CloudWatch Logs와 X-Ray로 로그 수집과 트레이싱은 구현했지만, 알림 시스템이 없는 것은 맞습니다. 다음 단계로 CloudWatch Alarm을 추가하여 ERROR 로그 발생 시 SNS로 알림을 받을 계획입니다. 또한 Prometheus + Grafana로 Kafka Lag과 Pod 메트릭을 시각화하고 싶습니다."

**포인트:**
- 현황 정확히 인지
- 구체적인 개선 계획
- 실무 도구 이해

---

**Q: Lambda와 EKS를 어떻게 선택했나요?**

**A:**
"Employee Service는 단순 CRUD로 트래픽이 적고 다른 서비스와 통신이 없어 Lambda로 전환했습니다. Approval 관련 서비스들은 Kafka로 비동기 통신하고 복잡한 비즈니스 로직이 있어 EKS에 유지했습니다. Lambda 전환으로 월 $17.57를 절감했고, API Gateway 직접 통합으로 VPC Link 비용도 줄였습니다."

**포인트:**
- 명확한 선택 기준
- 비용 최적화 결과
- 아키텍처 이해도

---

### 3. 비교 질문 대응

**Q: CGV와 ERP 중 어느 프로젝트가 더 좋은가요?**

**A:**
"두 프로젝트는 목적이 달랐습니다. CGV는 팀 프로젝트로 실무 환경을 경험하고 협업 능력을 키웠습니다. ERP는 개인 프로젝트로 인프라를 처음부터 끝까지 직접 설계하며 AWS 도구를 깊이 이해했습니다. CGV에서 못했던 Terraform 전체 작성, Helm Chart 직접 작성, CodePipeline 설계를 ERP에서 보완했습니다."

**포인트:**
- 우열 비교 회피
- 각 프로젝트의 가치 강조
- 보완 관계 설명

---

**Q: CGV가 더 복잡한데 ERP를 강조하는 이유는?**

**A:**
"CGV는 확실히 DR 자동화, KEDA, Karpenter 등 고급 기능이 많습니다. 하지만 저는 개발계만 담당하여 전체 파이프라인을 설계한 경험은 없었습니다. ERP에서는 규모는 작지만 Terraform부터 CodePipeline까지 모든 단계를 직접 설계하고 문제를 해결했습니다. 신입으로서는 큰 프로젝트의 일부보다 작은 프로젝트 전체를 이해하는 것이 중요하다고 생각했습니다."

**포인트:**
- CGV 가치 인정
- 역할 범위 명확히
- 학습 깊이 강조

---

## Part 5: 개선 우선순위 및 실행 계획

### 즉시 실행 (1주일 이내)

#### 1. CloudWatch Alarm 추가 (2시간)
```yaml
# Terraform으로 구현
resource "aws_cloudwatch_log_metric_filter" "error_logs" {
  name           = "erp-dev-error-count"
  log_group_name = "/aws/eks/erp-dev/application"
  pattern        = "[time, request_id, level = ERROR*, ...]"
  
  metric_transformation {
    name      = "ErrorCount"
    namespace = "ERP/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "erp-dev-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ErrorCount"
  namespace           = "ERP/Application"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

**효과:**
- 장애 조기 감지
- 실무 필수 기능
- 면접 어필 포인트

---

#### 2. buildspec.yml 완성 (4시간)
- Git diff 변경 감지
- ECR 이미지 스캔
- Helm values 업데이트
- helm upgrade 배포

**효과:**
- 06단계 완료
- CI/CD 파이프라인 완성
- 포트폴리오 핵심 완성

---

### 단기 실행 (2주일 이내)

#### 3. Prometheus + Grafana (4시간)
```bash
# Helm으로 설치
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

# Kafka Exporter 추가
helm install kafka-exporter prometheus-community/prometheus-kafka-exporter
```

**대시보드:**
- Kafka Lag 모니터링
- Pod CPU/Memory 사용률
- HPA 스케일링 이벤트
- Request 처리 시간

**효과:**
- 시각화 강화
- 실무 도구 경험
- 면접 시연 가능

---

#### 4. Velero 백업 (2시간)
```bash
# Velero 설치
velero install \
  --provider aws \
  --bucket erp-dev-velero-backup \
  --backup-location-config region=ap-northeast-2 \
  --snapshot-location-config region=ap-northeast-2

# 일일 백업 스케줄
velero schedule create daily-backup --schedule="0 2 * * *"
```

**효과:**
- Kubernetes 리소스 백업
- 복구 절차 문서화
- DR 전략 보완

---

### 중기 실행 (1개월 이내)

#### 5. SonarQube 통합 (4시간)
```yaml
# buildspec.yml pre_build 단계
pre_build:
  commands:
    - mvn sonar:sonar \
        -Dsonar.host.url=$SONAR_HOST \
        -Dsonar.login=$SONAR_TOKEN \
        -Dsonar.qualitygate.wait=true
```

**효과:**
- 코드 품질 관리
- CGV 경험 활용
- 정적 분석 추가

---

#### 6. Argo CD 추가 (선택, 8시간)
```bash
# Argo CD 설치
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Application 생성
argocd app create erp-dev \
  --repo https://github.com/user/erp-project \
  --path helm-chart \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace erp-dev
```

**효과:**
- GitOps 경험
- Pull 방식 배포
- Drift Detection

**주의:**
- CodePipeline과 병행 (복잡도 증가)
- 학습 시간 필요
- 우선순위 낮음

---

## Part 6: 최종 결론

### 현재 포트폴리오 평가

#### 강점 (신입 수준 초과)
1. **Terraform 전체 인프라 코드화** (98개 .tf 파일)
2. **Helm Chart 직접 작성** (CGV에서 못한 경험)
3. **Lambda 하이브리드 아키텍처** (비용 최적화 실증)
4. **마이크로서비스 통신 패턴** (gRPC → Kafka 전환)
5. **AWS 네이티브 도구 실전 적용** (CodePipeline, Parameter Store, X-Ray)

#### 약점 (개선 필요)
1. **모니터링 & 알림 부족** (CloudWatch Alarm 추가 필요)
2. **정적 분석 도구 부재** (SonarQube 추가 고려)
3. **DR 계획 없음** (비용 제약으로 현실적 어려움)
4. **GitOps 미적용** (선택 사항)
5. **백업 전략 미흡** (Velero 추가 고려)

---

### 면접 핵심 메시지

#### 1. 역할 범위 명확히
"CGV는 팀 프로젝트로 개발계를 담당했고, ERP는 개인 프로젝트로 전체를 설계했습니다."

#### 2. 보완 관계 강조
"CGV에서 경험하지 못한 Terraform, Helm Chart, CodePipeline을 ERP에서 직접 구현했습니다."

#### 3. 학습 과정 표현
"gRPC의 블로킹 문제를 직접 경험하고 Kafka로 해결하며 비동기 통신을 이해했습니다."

#### 4. 비용 최적화 실증
"Lambda 전환으로 월 $17.57 절감, 응답 시간 85% 개선을 달성했습니다."

#### 5. 개선 계획 제시
"CloudWatch Alarm과 Prometheus를 추가하여 모니터링을 강화할 계획입니다."

---

### 최종 판단

**ERP 프로젝트는 신입 DevOps 포트폴리오로 적절합니다.**

**이유:**
1. 전체 인프라를 직접 설계한 경험 (CGV보다 깊이 있음)
2. AWS 네이티브 도구 실전 적용 (DVA 학습 활용)
3. 문제 해결 과정 명확 (gRPC → Kafka, kubectl → Helm)
4. 비용 최적화 실증 (Lambda 전환)
5. 개선 여지 명확 (모니터링, 백업 등)

**개선 방향:**
1. **즉시**: CloudWatch Alarm + buildspec.yml 완성
2. **단기**: Prometheus + Velero
3. **중기**: SonarQube (선택)
4. **장기**: Argo CD (선택)

**면접 전략:**
- CGV 역할 범위 솔직히 인정
- ERP 전체 설계 경험 강조
- 두 프로젝트의 보완 관계 설명
- 개선 계획 구체적으로 제시
- 학습 과정과 문제 해결 스토리 준비
# DevOps 신입 포트폴리오 분석: CGV vs ERP 프로젝트 (Part 3)

## Part 7: 실전 면접 시나리오

### 시나리오 1: 프로젝트 소개 (3분)

**면접관: "포트폴리오를 간단히 소개해주세요."**

**답변 예시:**
"두 개의 프로젝트를 진행했습니다.

첫 번째는 CGV 야구 티켓팅 시스템으로, 3주간 팀 프로젝트였습니다. 저는 개발계 인프라를 담당하여 Helm Chart를 받아 배포하고 코드를 수정했습니다. GitLab CI/CD와 Argo CD가 구축되어 있었고, 이를 활용하여 개발 환경을 운영했습니다.

두 번째는 ERP 결재 시스템으로, 개인 프로젝트입니다. CGV에서 경험하지 못한 부분을 보완하기 위해 시작했습니다. Terraform으로 VPC부터 EKS까지 전체 인프라를 구축하고, Helm Chart를 처음부터 작성했으며, CodePipeline으로 CI/CD를 직접 설계했습니다. 특히 gRPC 동기 통신의 블로킹 문제를 경험하고 Kafka로 전환하여 응답 시간을 85% 개선했습니다."

**포인트:**
- 두 프로젝트의 역할 차이 명확히
- CGV: 팀 협업, ERP: 전체 설계
- 구체적인 성과 (85% 개선)

---

### 시나리오 2: 기술 깊이 질문

**면접관: "Kafka를 선택한 이유는 무엇인가요?"**

**답변 예시:**
"처음에는 gRPC로 동기 통신을 구현했습니다. Approval Request가 Processing을 호출하고, Processing이 Notification을 호출하는 구조였습니다. 하지만 테스트 결과 응답 시간이 850ms로 느렸고, 한 서비스가 다운되면 전체가 실패하는 문제가 있었습니다.

Kafka로 전환한 후 Request는 메시지만 발행하고 즉시 응답하여 120ms로 개선되었습니다. Processing과 Notification은 독립적으로 메시지를 소비하므로 한 서비스가 다운되어도 메시지가 보존되어 장애 격리가 가능해졌습니다.

다만 Kafka를 EKS Deployment로 배포하여 Pod 재시작 시 데이터가 손실되는 문제가 있습니다. 실무에서는 StatefulSet이나 MSK를 사용해야 한다고 생각합니다."

**포인트:**
- 문제 인식 → 해결 → 결과 (스토리)
- 구체적인 수치 (850ms → 120ms)
- 한계 인지 및 개선 방향

---

**면접관: "Terraform 모듈을 어떻게 구조화했나요?"**

**답변 예시:**
"SecurityGroups는 세분화하고 IAM은 통합했습니다.

SecurityGroups는 서비스 추가 시마다 규칙이 변경되므로 NLB, EKS, RDS, Lambda 등으로 분리했습니다. 한 서비스의 규칙 변경이 다른 서비스에 영향을 주지 않도록 했습니다.

반면 IAM은 Trust Policy가 일관되어야 하므로 하나의 파일로 통합했습니다. 예를 들어 EKS Node Role은 EC2, ECR, CloudWatch, X-Ray 등 여러 정책을 연결하는데, 이를 분리하면 Trust Policy가 중복되고 관리가 어려워집니다.

이 구조는 실무 조언을 받아 변경 빈도에 따라 설계한 것입니다."

**포인트:**
- 명확한 설계 원칙
- 실무 피드백 반영
- 유지보수 고려

---

### 시나리오 3: 문제 해결 능력

**면접관: "가장 어려웠던 문제와 해결 과정을 말해주세요."**

**답변 예시:**
"CloudWatch Logs가 수집되지 않는 문제가 있었습니다.

먼저 Fluent Bit Pod 로그를 확인했더니 로그 그룹이 없다는 에러가 있었습니다. Terraform 코드를 확인하니 로그 그룹 이름이 /aws/eks/erp-dev였는데, Helm Chart values에는 /aws/eks/erp-dev/application으로 설정되어 있었습니다.

Terraform으로 올바른 로그 그룹을 생성하고, Fluent Bit DaemonSet을 재시작했습니다. 그 후 API 요청을 보내고 CloudWatch Console에서 로그 스트림이 생성되는 것을 확인했습니다.

이 과정에서 Fluent Bit가 각 Node에서 /var/log/containers/*.log를 수집하여 CloudWatch로 전송하는 구조를 이해하게 되었습니다."

**포인트:**
- 문제 → 원인 분석 → 해결 → 검증 (체계적)
- 로그 확인 습관
- 학습 내용 정리

---

### 시나리오 4: 비교 질문

**면접관: "CGV와 ERP 중 어느 것이 더 복잡한가요?"**

**답변 예시:**
"기능 복잡도는 CGV가 높습니다. DR 자동화, KEDA, Karpenter, Aurora Global DB 등 고급 기능이 많습니다.

하지만 제 역할 범위는 ERP가 더 넓었습니다. CGV에서는 개발계만 담당하여 Helm Chart를 받아 사용했지만, ERP에서는 Terraform부터 CodePipeline까지 전체를 직접 설계했습니다.

신입으로서는 큰 프로젝트의 일부를 경험하는 것도 중요하지만, 작은 프로젝트라도 전체를 이해하는 것이 더 중요하다고 생각했습니다. 그래서 ERP에서는 모든 단계를 직접 구현하며 왜 이렇게 설계하는지 이해하려고 노력했습니다."

**포인트:**
- 복잡도 vs 역할 범위 구분
- 학습 깊이 강조
- 주도적 학습 태도

---

### 시나리오 5: 개선 방향

**면접관: "ERP 프로젝트에서 개선하고 싶은 부분은?"**

**답변 예시:**
"세 가지를 개선하고 싶습니다.

첫째, 모니터링 강화입니다. 현재 CloudWatch Logs와 X-Ray로 로그와 트레이싱은 수집하지만 알림이 없습니다. CloudWatch Alarm으로 ERROR 로그 발생 시 SNS 알림을 추가하고, Prometheus + Grafana로 Kafka Lag과 Pod 메트릭을 시각화할 계획입니다.

둘째, 정적 분석 도구 추가입니다. CGV에서 SonarQube를 경험했는데, ERP에는 없습니다. buildspec.yml pre_build 단계에 추가하여 코드 품질 기준을 통과해야 빌드되도록 할 계획입니다.

셋째, Kafka를 StatefulSet으로 전환하거나 MSK로 마이그레이션하고 싶습니다. 현재 Deployment로 배포하여 Pod 재시작 시 데이터가 손실되는 문제가 있습니다."

**포인트:**
- 구체적인 개선 계획
- 우선순위 명확
- 실무 도구 이해

---

## Part 8: 핵심 수치 정리

### 프로젝트 규모

| 항목 | CGV | ERP |
|------|-----|-----|
| **기간** | 3주 (팀) | 2개월 (개인) |
| **인프라 코드** | 불명 | 98개 .tf 파일 |
| **Kubernetes 리소스** | 불명 | 15개 템플릿 |
| **마이크로서비스** | 1개 (모놀리식) | 4개 (Lambda 포함) |
| **AWS 리소스** | 20+ | 30+ |
| **환경** | 4개 (Prod/Dev/QA/DR) | 1개 (Dev) |
| **리전** | 2개 (서울/도쿄) | 1개 (서울) |

---

### 성능 개선

| 지표 | Before | After | 개선율 |
|------|--------|-------|--------|
| **응답 시간** | 850ms (gRPC) | 120ms (Kafka) | 85% ↓ |
| **에러율** | 15% (동기) | 0% (비동기) | 100% ↓ |
| **월 비용** | $82.30 (EKS 4개) | $64.73 (Lambda 전환) | 21% ↓ |

---

### 인프라 구성

#### CGV
- **Compute**: EKS (Node 수 불명), EC2 (GitLab)
- **Database**: Aurora Global DB (서울 Primary, 도쿄 Secondary)
- **Network**: ALB, Route53, CloudFront, WAF
- **Messaging**: Redis, Kinesis Data Streams
- **Monitoring**: Datadog, CloudWatch
- **Backup**: AWS Backup (3시간 주기), Velero

#### ERP
- **Compute**: EKS (t3.medium 2대), Lambda (512MB)
- **Database**: RDS MySQL (db.t3.micro), ElastiCache (cache.t3.micro), MongoDB Atlas
- **Network**: NLB, API Gateway, CloudFront
- **Messaging**: Kafka (EKS Deployment)
- **Monitoring**: CloudWatch Logs, X-Ray
- **Backup**: RDS 자동 백업 (7일)

---

### CI/CD 비교

| 단계 | CGV | ERP |
|------|-----|-----|
| **Source** | GitLab | GitHub |
| **Build** | GitLab Runner | CodeBuild |
| **Test** | SonarQube, Dependency Check | ECR Scan |
| **Deploy** | Argo CD (Pull) | helm upgrade (Push) |
| **Config** | 불명 | Parameter Store |
| **Secret** | Secret Manager | Secrets Manager + External Secrets |
| **Rollback** | Argo CD Sync | helm rollback |

---

## Part 9: 문서화 전략

### 포트폴리오 README 구조 제안

```markdown
# ERP 결재 시스템 - AWS 기반 마이크로서비스

## 프로젝트 개요
- 목적: AWS 네이티브 도구 실전 적용 및 마이크로서비스 아키텍처 학습
- 기간: 2개월
- 역할: 전체 인프라 설계 및 구축

## 주요 성과
- 🚀 Kafka 전환으로 응답 시간 85% 개선 (850ms → 120ms)
- 💰 Lambda 하이브리드로 월 비용 21% 절감 ($82.30 → $64.73)
- 📦 Terraform 98개 파일로 전체 인프라 코드화
- 🎯 Helm Chart 직접 작성으로 환경 분리 구현

## 아키텍처
[아키텍처 다이어그램]

## 기술 스택
- **IaC**: Terraform
- **Container**: EKS, Docker, Helm
- **Serverless**: Lambda, API Gateway
- **CI/CD**: CodePipeline, CodeBuild
- **Monitoring**: CloudWatch, X-Ray
- **Database**: RDS, ElastiCache, MongoDB
- **Messaging**: Kafka

## 주요 구현 내용

### 1. Terraform 인프라 코드화
- VPC, EKS, RDS, Lambda 등 30+ AWS 리소스
- SecurityGroups 세분화, IAM 통합 전략
- Remote State로 모듈 간 의존성 관리

### 2. Helm Chart 작성
- 1개 템플릿으로 4개 서비스 Deployment 생성
- External Secrets Operator로 Secrets Manager 통합
- TargetGroupBinding으로 NLB 연동

### 3. Lambda 하이브리드 아키텍처
- Employee Service를 Lambda로 전환
- Lambda Web Adapter로 코드 수정 없이 마이그레이션
- API Gateway 직접 통합으로 VPC Link 비용 절감

### 4. Kafka 비동기 통신
- gRPC 동기 통신의 블로킹 문제 해결
- 응답 시간 85% 개선, 에러율 0%
- 장애 격리 (메시지 보존)

### 5. CI/CD 파이프라인
- Git diff로 변경된 서비스만 빌드
- ECR 이미지 스캔 (Critical 발견 시 중단)
- helm upgrade로 전체 리소스 배포

### 6. 관측성 (Observability)
- CloudWatch Logs (Fluent Bit DaemonSet)
- X-Ray 분산 트레이싱
- Parameter Store 설정 중앙 관리

## 문제 해결 사례

### Case 1: gRPC 성능 문제
**문제**: 동기 통신으로 응답 시간 850ms, 에러율 15%
**해결**: Kafka 비동기 전환
**결과**: 응답 시간 120ms, 에러율 0%

### Case 2: CloudWatch Logs 미수집
**문제**: 로그 그룹 이름 불일치
**해결**: Terraform 수정 및 Fluent Bit 재시작
**결과**: 로그 정상 수집 및 실시간 모니터링

## 개선 계획
- [ ] CloudWatch Alarm 추가 (ERROR 로그 알림)
- [ ] Prometheus + Grafana (Kafka Lag 모니터링)
- [ ] SonarQube 통합 (코드 품질 분석)
- [ ] Velero 백업 (Kubernetes 리소스)

## 관련 프로젝트
- CGV 티켓팅 시스템: GitLab CI/CD, Argo CD 경험
```

---

### 각 단계별 README 작성

#### 01_TERRAFORM/README.md
```markdown
# Terraform 인프라 구축

## 구조 설계
- SecurityGroups: 세분화 (변경 빈도 높음)
- IAM: 통합 (Trust Policy 일관성)
- Remote State: S3 + DynamoDB Lock

## 주요 리소스
- VPC: 2 AZ, Public/Private Subnet
- EKS: 1.28, t3.medium 2대
- RDS: MySQL 8.0, db.t3.micro
- Lambda: Employee Service, 512MB

## 실행 방법
[생략]
```

#### 05_HELM_CHART/README.md
```markdown
# Helm Chart 작성

## 템플릿 구조
- 1개 Deployment 템플릿 → 4개 서비스 생성
- Go 템플릿 문법 (range, if)
- values-dev.yaml로 환경 분리

## External Secrets Operator
- Secrets Manager와 Kubernetes Secret 동기화
- 5분마다 자동 갱신

## TargetGroupBinding
- Kubernetes Service와 AWS NLB 통합
- Pod IP 자동 등록/해제
```

---

## Part 10: 최종 체크리스트

### 즉시 확인 사항

- [ ] **buildspec.yml 완성** (Step 4)
  - Git diff 변경 감지
  - ECR 이미지 스캔
  - Helm values 업데이트
  - helm upgrade 배포

- [ ] **CloudWatch Alarm 추가**
  - ERROR 로그 10회 이상 → SNS 알림
  - Pod 재시작 감지 → 알림

- [ ] **README 작성**
  - 프로젝트 개요
  - 주요 성과 (수치 포함)
  - 아키텍처 다이어그램
  - 문제 해결 사례

- [ ] **면접 준비**
  - 3분 프로젝트 소개 연습
  - 기술 질문 답변 준비
  - 문제 해결 스토리 정리

---

### 단기 개선 사항 (2주)

- [ ] **Prometheus + Grafana**
  - Kafka Lag 모니터링
  - Pod CPU/Memory 대시보드
  - HPA 스케일링 추적

- [ ] **Velero 백업**
  - Kubernetes 리소스 백업
  - 복구 절차 문서화

- [ ] **아키텍처 다이어그램**
  - draw.io 또는 Lucidchart
  - Before/After 비교 (gRPC vs Kafka)

---

### 중기 개선 사항 (1개월)

- [ ] **SonarQube 통합**
  - buildspec.yml pre_build 단계
  - 코드 품질 기준 설정

- [ ] **Kafka StatefulSet 전환**
  - 또는 MSK 마이그레이션
  - 데이터 손실 방지

- [ ] **Argo CD 추가 (선택)**
  - GitOps 경험
  - Pull 방식 배포

---

### 면접 전 최종 점검

- [ ] **CGV 역할 범위 명확히**
  - 개발계만 담당
  - Helm Chart 받아서 사용
  - 파이프라인 설계 경험 없음

- [ ] **ERP 전체 설계 강조**
  - Terraform 98개 파일
  - Helm Chart 직접 작성
  - CodePipeline 직접 설계

- [ ] **수치 암기**
  - 응답 시간: 850ms → 120ms (85% 개선)
  - 비용: $82.30 → $64.73 (21% 절감)
  - 에러율: 15% → 0%

- [ ] **개선 계획 준비**
  - CloudWatch Alarm (즉시)
  - Prometheus + Grafana (단기)
  - SonarQube (중기)

---

## 결론

**ERP 프로젝트는 신입 DevOps 엔지니어 포트폴리오로 충분히 적절합니다.**

**핵심 강점:**
1. 전체 인프라 직접 설계 (CGV보다 깊이)
2. AWS 네이티브 도구 실전 적용
3. 문제 해결 과정 명확 (gRPC → Kafka)
4. 비용 최적화 실증 (Lambda 전환)

**개선 방향:**
1. 즉시: CloudWatch Alarm + buildspec.yml
2. 단기: Prometheus + Velero
3. 중기: SonarQube (선택)

**면접 전략:**
1. CGV 역할 범위 솔직히 인정
2. ERP 전체 설계 경험 강조
3. 두 프로젝트의 보완 관계 설명
4. 구체적인 수치로 성과 표현
5. 개선 계획 명확히 제시

**다음 단계:**
1. buildspec.yml 완성 (4시간)
2. CloudWatch Alarm 추가 (2시간)
3. README 작성 (2시간)
4. 면접 답변 연습 (1일)

---

**작성 완료: 2025-12-28**
# ERP 프로젝트 분석 및 재구축 가이드

작성일: 2024-12-27

---

## 목차

1. [현재 상황 분석](#현재-상황-분석)
2. [발견된 문제점](#발견된-문제점)
3. [Terraform 구조 분석](#terraform-구조-분석)
4. [재구축 해결 방안](#재구축-해결-방안)

---

## 현재 상황 분석

### 프로젝트 배경

**CGV 프로젝트 경험:**
- GitLab CI + ArgoCD + Helm Chart 사용
- 전체 CI/CD 구조는 팀에서 구축된 것 활용
- 한계: 파이프라인 전체 흐름 이해했지만 직접 설계 경험 부족

**ERP 프로젝트 목표:**
- AWS 네이티브 도구 (CodePipeline, CodeBuild) 실전 적용
- CI/CD 파이프라인을 처음부터 끝까지 직접 설계

**결과: 실패한 설계**
- 서비스별 독립 파이프라인 (4개 CodePipeline)
- kubectl set image만 실행 (Manifests 변경 반영 안 됨)
- Git이 진실이 아님
- 환경 분리 불가능

---

## 발견된 문제점

### 1. CI/CD 구조 문제

**서비스별 독립 파이프라인**
- 4개 마이크로서비스 = 4개 CodePipeline = 4개 buildspec.yml
- Manifests 변경이 배포 안 됨
- 서비스 간 의존성 무시
- 롤백 불가능

**buildspec.yml 위치**
- backend/서비스명/buildspec.yml (4개 중복)
- 변경 시 4개 파일 모두 수정 필요

**kubectl set image만 실행**
```yaml
post_build:
  commands:
    - kubectl set image deployment/서비스명 ...
```
- 이미지만 변경
- Deployment의 나머지 설정은 그대로 유지
- Manifests 변경 반영 안 됨

### 2. Manifests 구조 문제

**Plain YAML (하드코딩)**
- 환경별 설정 분리 불가능
- 4개 Deployment 파일 중복 (400줄 중 300줄 중복)
- 버전 관리 어려움

**Secret 평문 저장**
```yaml
# manifests/base/secret.yaml
stringData:
  MYSQL_PASSWORD: "123456789"  # Git에 평문 커밋
```

**LoadBalancer 중복**
```yaml
# manifests/notification/notification-service.yaml
spec:
  type: LoadBalancer  # 추가 NLB 생성
```
- Terraform NLB + Kubernetes LoadBalancer = NLB 2개
- 비용 낭비 ($16/월)

### 3. 인프라 구조 문제

**NLB 중복 생성**
- Terraform: erp-dev-nlb (4개 Target Group)
- Kubernetes: LoadBalancer Service (notification)
- 결과: NLB 2개 사용 중

**Lambda 미사용**
- Employee Service는 간단한 CRUD (Lambda 적합)
- 비용 최적화 기회 놓침 (21% 절감 가능)

**Kafka Deployment**
- StatefulSet 아닌 Deployment 사용
- 데이터 영속성 없음
- Pod 재시작 시 메시지 소실

---

## Terraform 구조 분석

### 전체 구조 (98개 .tf 파일)

**1. VPC (세분화 - 3단계)**
```
erp-dev-VPC/
├── vpc/          # VPC + IGW
├── subnet/       # Public/Private/Data Subnet + NAT
└── route-table/  # Route Table + Associations
```

**2. SecurityGroups (세분화 - 4개 독립)**
```
erp-dev-SecurityGroups/
├── alb-sg/
├── eks-sg/
├── rds-sg/
└── elasticache-sg/
```

**3. IAM (통합 - 1번 apply)**
```
erp-dev-IAM/
├── eks-cluster-role/
├── eks-node-role/
├── codebuild-role/    # 권한 추가 필요
└── codepipeline-role/
```

**4. Secrets (통합 - 1번 apply)**
```
erp-dev-Secrets/
├── mysql-secret/              # Secret 이름: erp/dev/mysql
└── eks-node-secrets-policy/   # EKS Node에 읽기 권한
```

**5. Databases (세분화 - 2개 독립)**
```
erp-dev-Databases/
├── rds/          # MySQL 8.0, db.t3.micro
└── elasticache/  # Redis 7.0, cache.t3.micro
```

**6. EKS (통합 - 1번 apply)**
```
erp-dev-EKS/
├── eks-cluster/           # Kubernetes 1.31
├── eks-node-group/        # t3.small × 3
└── eks-cluster-sg-rules/  # VPC ingress (NLB용)
```

**7. LoadBalancerController (단일)**
- Helm Release v1.7.0
- IAM Role for ServiceAccount

**8. APIGateway (통합 - 1번 apply)**
```
erp-dev-APIGateway/
├── nlb/          # NLB + 4 Target Groups
└── api-gateway/  # HTTP API + 7 Routes
```

**9. Frontend (통합)**
```
erp-dev-Frontend/
├── s3/          # Static Website Hosting
└── cloudfront/  # CDN
```

**10. Cognito (통합)**
- User Pool + Lambda auto-confirm

### 주요 발견 사항

**Secret 이름**
- 실제: erp/dev/mysql
- MongoDB Secret 없음 (Atlas 사용)

**CodeBuild Role 권한 부족**
- Secrets Manager 읽기 권한 없음
- Parameter Store 읽기 권한 없음
- ECR 이미지 스캔 권한 없음

**EKS Node 3개 이유**
- Kafka 메모리 요구사항
- 서비스 Pod Anti-Affinity 분산

---

## 재구축 해결 방안

### 1. Helm Chart 전환

**Before (Plain YAML):**
- 4개 Deployment 파일 중복
- 환경 분리 불가

**After (Helm Chart):**
- 1개 템플릿 → 4개 Deployment 생성
- values-dev.yaml / values-prod.yaml 분리

### 2. 단일 buildspec.yml

**Before:**
```yaml
# backend/서비스명/buildspec.yml (4개)
post_build:
  - kubectl set image deployment/서비스명 ...
```

**After:**
```yaml
# 루트/buildspec.yml (1개)
post_build:
  - helm upgrade --install erp-microservices helm-chart/ \
      -f helm-chart/values-dev.yaml
```

### 3. Secrets Manager 통합

**Before:**
```yaml
# manifests/base/secret.yaml
stringData:
  MYSQL_PASSWORD: "123456789"
```

**After:**
```yaml
# External Secrets Operator
# Secrets Manager에서 자동 동기화
# Git에 Secret 없음
```

### 4. NLB 중복 제거

**Before:**
- Terraform NLB + Kubernetes LoadBalancer

**After:**
- 모든 Service를 ClusterIP
- TargetGroupBinding으로 Terraform NLB 연결

### 5. CodePipeline 강점 극대화

**CGV와 차별화:**
- AWS Secrets Manager 통합
- Parameter Store 활용
- ECR 이미지 스캔 자동화
- CloudWatch Logs 중앙 집중
- 변경 감지 로직 (Git diff)

---

## 재구축 단계

**Phase 0:** 준비 및 백업
**Phase 1:** Terraform 배포 (2시간)
**Phase 2:** Helm Chart 생성 (2시간)
**Phase 2.5:** Lambda 전환 (선택, 2시간)
**Phase 3:** Secrets Manager 설정 (30분)
**Phase 4:** buildspec.yml 작성 (1시간)
**Phase 5:** CodePipeline 생성 (1시간)
**Phase 6:** 검증 및 테스트 (1시간)

총 소요 시간: 9.5시간 (Lambda 포함)

---

## 개선 효과

### Before (문제)
- 4개 CodePipeline (관리 복잡)
- kubectl set image (Manifests 반영 안 됨)
- Plain YAML (환경 분리 불가)
- Secret 평문 (보안 취약)
- NLB 중복 (비용 낭비)
- Git이 진실 아님

### After (해결)
- 1개 CodePipeline (단일 관리)
- helm upgrade (Manifests 자동 반영)
- Helm Chart (환경 분리 가능)
- Secrets Manager (보안 강화)
- NLB 1개 (비용 절감)
- Git이 진실 (Source of Truth)

---

## 참고 사항

**MongoDB URI:**
- Atlas 외부 서비스 사용
- Secrets Manager 불필요
- ConfigMap에 URI 하드코딩 (개발 환경)

**Kafka 구조:**
- Deployment 유지 (StatefulSet 아님)
- 개발 환경이므로 메시지 소실 허용
- 비용 절감 (MSK $310/월 vs 현재 $0)

**Lambda 전환 (선택):**
- Employee Service만 가능
- 비용 21% 절감 ($82.30 → $64.73)
- Cold Start 300~500ms (첫 요청만)
