# ERP Kubernetes Manifests

**Orchestration**: Kubernetes 1.31  
**Cluster**: Amazon EKS  
**Namespace**: erp-dev  
**최종 업데이트**: 2025-12-10

---

## Manifest 구조

```
manifests/
├── base/                           # 공통 리소스
│   ├── namespace.yaml              # erp-dev Namespace
│   └── configmap.yaml              # 공통 ConfigMap
├── employee/                       # Employee Service
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── hpa.yaml
│   └── targetgroupbinding.yaml
├── approval-request/               # Approval Request Service
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── hpa.yaml
│   └── targetgroupbinding.yaml
├── approval-processing/            # Approval Processing Service
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── hpa.yaml
│   └── targetgroupbinding.yaml
├── notification/                   # Notification Service (WebSocket)
│   ├── deployment.yaml
│   ├── service.yaml               # type: LoadBalancer (NLB 자동 생성)
│   └── hpa.yaml
└── kafka/                          # Kafka (Deployment, 개선 필요)
    ├── deployment.yaml             # replicas: 1, 메모리만 사용
    └── service.yaml                # ClusterIP
```

---

## 배포

### 순서대로 실행

```bash
# 1. 공통 리소스
kubectl apply -f base/

# 2. Kafka (Approval Services가 의존)
kubectl apply -f kafka/

# 3. 각 서비스
kubectl apply -f employee/
kubectl apply -f approval-request/
kubectl apply -f approval-processing/
kubectl apply -f notification/
```

### 배포 확인

```bash
kubectl get pods -n erp-dev
kubectl get svc -n erp-dev
kubectl get hpa -n erp-dev
kubectl get targetgroupbinding -n erp-dev
```

---

## 개발 환경 설정

### 현재 구성

**Pod 수:**
- Employee: 2개
- Approval Request: 2개
- Approval Processing: 2개
- Notification: 2개
- **합계: 8개 Pod** (EKS 비용 $82.30/월)

**설정:**
```yaml
# Deployment
replicas: 2                          # 고가용성 최소 요구사항

# HPA
minReplicas: 2
maxReplicas: 3                       # 개발 환경이므로 제한적

# Node Group (Terraform)
desired: 3
min: 1
max: 3                               # Kafka 설치 위한 최소 구성
```

**이유:**
- 비용 고려한 최소 구성
- 프로덕션 확장 기반 마련 (HPA, RollingUpdate 구현)
- Kafka 최소 3개 브로커 권장으로 Node 3개

---

### 프로덕션 전환 시

**확장:**
- HPA: minReplicas 2→5~10, maxReplicas 3→10~20
- Node: desired 3→6~10, max 3→20
- Multi-AZ: 2개 AZ → 3개 AZ

**배포 전략:**
- 현재: RollingUpdate
- 전환: Blue/Green 또는 Canary

**모니터링:**
- 추가: Prometheus + Grafana, Kafka Lag 모니터링

**보안:**
- Network Policy, Kafka TLS/SSL, AWS Secrets Manager 연동

---

## Kubernetes 리소스

### 1. Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # 최소 1개는 항상 실행
      maxSurge: 1            # 최대 3개까지 동시 실행
  template:
    spec:
      containers:
      - name: employee-service
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:        # 실패 시 재시작
          httpGet:
            path: /actuator/health
            port: 8081
        readinessProbe:       # 실패 시 Service에서 제외
          httpGet:
            path: /actuator/health
            port: 8081
        securityContext:
          runAsNonRoot: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
      affinity:
        podAntiAffinity:      # AZ 분산 배치
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              topologyKey: topology.kubernetes.io/zone
```

**주요 설정:**
- **RollingUpdate**: 무중단 배포
- **Resource Limits**: CPU 200m~500m, Memory 256Mi~512Mi
- **Health Check**: Spring Boot Actuator 활용
- **Security Context**: root 실행 금지, 권한 최소화
- **Pod Anti-Affinity**: AZ 분산으로 고가용성 확보

---

### 2. Service

```yaml
apiVersion: v1
kind: Service
spec:
  type: ClusterIP  # 또는 LoadBalancer
  ports:
  - port: 8081
    targetPort: 8081
```

**Service Type:**

| 서비스 | Type | 이유 |
|--------|------|------|
| Employee | ClusterIP | TargetGroupBinding 사용 |
| Approval Request | ClusterIP | TargetGroupBinding 사용 |
| Approval Processing | ClusterIP | TargetGroupBinding 사용 |
| Notification | LoadBalancer | NLB 자동 생성 (문제 있음) |
| Kafka | ClusterIP | 내부 통신만 |

**상세:** [현재 NLB 구조 문제점](#현재-nlb-구조-문제점)

---

### 3. TargetGroupBinding

**4개 서비스 모두 Terraform NLB에 연결:**

```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: employee-tgb
  namespace: erp-dev
spec:
  serviceRef:
    name: employee-service
    port: 8081
  targetGroupARN: arn:aws:elasticloadbalancing:...
  targetType: ip
```

**역할:**
- ClusterIP Service를 Terraform NLB에 연결
- Pod IP를 NLB Target Group에 자동 등록/제거
- AWS Load Balancer Controller가 자동으로 처리

**상세:** [현재 NLB 구조 문제점](#현재-nlb-구조-문제점)

---

### 4. HPA (Horizontal Pod Autoscaler)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 2
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**설정:**
- minReplicas 2: 고가용성 최소 요구사항
- maxReplicas 3: 개발 환경이므로 제한적 (프로덕션 10~20)
- CPU 70%: 일반적인 임계값

**현재 상태:**
- metrics-server 미설치 (구현만 해놓음)
- 프로덕션 전환 시 활성화 예정

---

## Kafka 구현의 아쉬운 점

### 문제점

**Deployment로 배포:**
```yaml
kind: Deployment  # StatefulSet 아님
spec:
  replicas: 1
  # volumeClaimTemplates 없음 = 메모리만 사용
```

**3가지 문제:**
1. 데이터 영속성 없음 (Pod 재시작 시 메시지 소실)
2. 고가용성 없음 (replicas 1)
3. Stateful 애플리케이션을 Deployment로 배포

---

### 다른 서비스는 왜 Deployment로 괜찮은가?

**Employee, Approval, Notification:**
- **데이터는 외부 저장**: RDS (MySQL), ElastiCache (Redis), MongoDB Atlas
- **Stateless**: Pod 자체는 상태 저장 안 함
- **Pod 재시작해도 문제 없음**: 외부 DB에 다시 연결

**Kafka는 왜 문제?**
- **데이터는 Pod 내부 저장**: Kafka 자체가 메시지를 디스크에 저장
- **Stateful**: Pod가 상태를 가짐
- **Pod 재시작 시 데이터 소실**: 메모리만 사용

| 서비스 | 데이터 저장 | 리소스 | 문제 |
|--------|-----------|--------|------|
| Employee | RDS | Deployment | ✅ 괜찮음 |
| Approval | RDS | Deployment | ✅ 괜찮음 |
| Notification | ElastiCache | Deployment | ✅ 괜찮음 |
| Kafka | **Pod 내부** | Deployment | ❌ 문제 |

---

### StatefulSet으로 구현했다면

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
spec:
  serviceName: kafka-headless
  replicas: 3
  volumeClaimTemplates:
  - metadata:
      name: kafka-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: gp3
      resources:
        requests:
          storage: 10Gi
```

**Deployment vs StatefulSet:**

| 항목 | Deployment | StatefulSet |
|------|-----------|-------------|
| Pod 이름 | kafka-xxxxx (랜덤) | kafka-0, kafka-1, kafka-2 (고정) |
| 생성 순서 | 동시 (병렬) | 순차 (0→1→2) |
| 삭제 순서 | 동시 (병렬) | 역순 (2→1→0, 마스터 보호) |
| 볼륨 | 공유 어려움 (EFS 필요) | 각 Pod마다 고유 EBS |
| 재시작 | 새 Pod, 새 볼륨 | 같은 이름, 같은 볼륨 |
| 데이터 | 소실 | 보존 |
| 적합 | Stateless (API) | Stateful (DB, Kafka) |

---

### StatefulSet 동작 과정

**스토리지 생성 흐름:**
```
StatefulSet
  ↓ volumeClaimTemplates
PVC 생성 요청
  ↓ storageClassName: gp3 참조
StorageClass (gp3)
  ↓ EBS CSI Driver 호출
AWS EBS 볼륨 생성
  ↓ 
PV 자동 생성 (EBS 연결)
  ↓
PVC ↔ PV 바인딩
  ↓
Pod가 PVC 마운트
```

**배포 시 순차 생성:**
```bash
kubectl apply -f kafka-statefulset.yaml
```
```
Step 1: kafka-0 생성
  ├─ PVC 생성: kafka-data-kafka-0
  ├─ StorageClass gp3가 EBS 볼륨 자동 생성 (10Gi)
  ├─ PV 자동 생성 및 PVC 바인딩
  ├─ Pod kafka-0 생성, 볼륨 마운트
  └─ Ready 확인 후 다음 Pod 생성 ✅

Step 2: kafka-1 생성 (kafka-0 Ready 후)
  ├─ PVC 생성: kafka-data-kafka-1
  ├─ 새 EBS 볼륨 생성 (10Gi)
  └─ Pod kafka-1 생성 ✅

Step 3: kafka-2 생성 (kafka-1 Ready 후)
  └─ 동일 과정 반복 ✅
```

**Pod 재시작 시 (핵심):**
```
Deployment:
  Pod 삭제 → 새 Pod (랜덤 이름) → 메모리만 사용 → 데이터 소실 ❌

StatefulSet:
  Pod kafka-1 삭제
    ↓
  PVC kafka-data-kafka-1 유지 (EBS 볼륨 보존)
    ↓
  새 Pod kafka-1 생성 (같은 이름, 고정 ID)
    ↓
  같은 PVC 연결 → 같은 EBS 마운트 → 데이터 복구 ✅
```

**삭제 시 역순 (마스터 보호):**
```bash
kubectl delete statefulset kafka
```
```
kafka-2 삭제 → kafka-1 삭제 → kafka-0 삭제 (마지막)

이유: 분산 DB에서 0번은 보통 마스터 역할
      중요한 정보가 있으므로 마지막에 삭제
```

**용어:**
- **PV (PersistentVolume)**: 실제 스토리지 (EBS 볼륨)
- **PVC (PersistentVolumeClaim)**: Pod가 스토리지 요청
- **StorageClass (SC)**: 스토리지 타입 정의 (gp3, gp2 등), PV 자동 생성
- **volumeClaimTemplates**: 각 Pod마다 PVC 자동 생성 (StatefulSet 전용)
- **ReadWriteOnce (RWO)**: 단일 노드에서만 읽기/쓰기 (EBS 기본값)

**비용:**
- EBS gp3: $0.08/GB/월
- 10Gi × 3개 = $2.4/월

---

### MSK vs 자체 구축

**비용 비교:**

| 구성 | 비용 | 데이터 영속성 | 고가용성 | 관리 부담 |
|------|------|--------------|---------|----------|
| 현재 (Deployment) | $0 | ❌ | ❌ | 높음 |
| StatefulSet + PVC | $3/월 | ✅ | ⚠️ 수동 | 높음 |
| MSK | $310/월 | ✅ | ✅ 자동 | 낮음 |

**왜 이렇게 구현?**
- 학습 목적 (Kafka 비동기 메시징 경험)
- 비용 절감 (MSK $310/월 vs 현재 $0)
- 개발 환경 (메시지 소실 허용)
- 14일 기간 제약

**프로덕션 전환 시:**
- MSK 사용 권장 (관리 부담 감소, 고가용성)
- 또는 StatefulSet + PVC (비용 절감)
- 현재 Deployment는 절대 불가 (데이터 소실)

---

## 현재 NLB 구조 문제점

### 실제 코드 분석

**Terraform (infrastructure/terraform/dev/erp-dev-APIGateway/nlb/nlb.tf):**
```hcl
# NLB 1개 생성
resource "aws_lb" "nlb" {
  name               = "erp-dev-nlb"
  load_balancer_type = "network"
  ...
}

# Target Group 4개 생성
resource "aws_lb_target_group" "employee" { port = 8081 }
resource "aws_lb_target_group" "approval_request" { port = 8082 }
resource "aws_lb_target_group" "approval_processing" { port = 8083 }
resource "aws_lb_target_group" "notification" { port = 8084 }
```

**Kubernetes (manifests/):**
```yaml
# Employee, Approval Request, Approval Processing: ClusterIP
apiVersion: v1
kind: Service
spec:
  type: ClusterIP

---
# Notification: LoadBalancer (문제!)
apiVersion: v1
kind: Service
metadata:
  name: notification-service
spec:
  type: LoadBalancer  # ← 별도 NLB 자동 생성
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

**TargetGroupBinding (manifests/base/targetgroupbinding.yaml):**
```yaml
# 4개 서비스 모두 Terraform NLB에 연결
- employee-service → erp-dev-employee-nlb-tg
- approval-request-service → erp-dev-approval-req-nlb-tg
- approval-processing-service → erp-dev-approval-proc-nlb-tg
- notification-service → erp-dev-notification-nlb-tg  # ← 이것도 연결됨!
```

---

### 문제: Notification이 NLB 2개에 중복 연결

**현재 상황:**
```
Terraform NLB (erp-dev-nlb)
├─ Employee (TargetGroupBinding)
├─ Approval Request (TargetGroupBinding)
├─ Approval Processing (TargetGroupBinding)
└─ Notification (TargetGroupBinding) ← 연결됨

Kubernetes LoadBalancer NLB (자동 생성)
└─ Notification (LoadBalancer) ← 또 연결됨!
```

**결과:**
- **NLB 2개 사용 중** (Terraform 1개 + Kubernetes 1개)
- Notification Service가 **2개 NLB에 동시 연결**
- Kubernetes LoadBalancer NLB는 **사용 안 하고 놀고 있음** (API Gateway는 Terraform NLB 사용)
- 비용 낭비, 일관성 없음

---

### 설계 실수 과정

**초기 생각:**
> "API Gateway를 사용하니 Kubernetes Service에서 NLB를 생성해야 하지 않을까? 특히 WebSocket은 지속적인 연결 유지가 필요하니 Notification만 LoadBalancer로 설정하자."

**나중에 깨달은 점:**
> "모든 Service를 ClusterIP로 설정하고 TargetGroupBinding을 통해 Terraform NLB의 Target Group에 연결해도 외부 접근이 가능하다. WebSocket도 동일한 NLB로 처리 가능하다 (NLB는 Layer 4 TCP)."

**결과:**
- 처음에는 Notification만 LoadBalancer로 구현
- 나중에 TargetGroupBinding 추가하면서 Terraform NLB에도 연결
- **중복 연결 발생, 놀고 있는 NLB 생성**

---

### 올바른 구조 (NLB 1개)

**모든 Service를 ClusterIP + TargetGroupBinding으로 통일:**

```yaml
# Notification Service도 ClusterIP로 변경
apiVersion: v1
kind: Service
metadata:
  name: notification-service
spec:
  type: ClusterIP  # LoadBalancer → ClusterIP
  ports:
  - port: 8084

---
# TargetGroupBinding 추가
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: notification-tgb
spec:
  serviceRef:
    name: notification-service
    port: 8084
  targetGroupARN: arn:aws:...notification-nlb-tg
  targetType: ip
```

**구조:**
```
API Gateway
  ↓
VPC Link
  ↓
NLB 1개 (Terraform 생성)
  ├─ Target Group 1 (8081) → Employee Pods (ClusterIP + TargetGroupBinding)
  ├─ Target Group 2 (8082) → Approval Request Pods (ClusterIP + TargetGroupBinding)
  ├─ Target Group 3 (8083) → Approval Processing Pods (ClusterIP + TargetGroupBinding)
  └─ Target Group 4 (8084) → Notification Pods (ClusterIP + TargetGroupBinding)
```

**장점:**
- NLB 1개로 통일 (비용 절감)
- 일관성 있는 구조 (모두 ClusterIP + TargetGroupBinding)
- Terraform이 인프라 관리, Kubernetes가 애플리케이션 관리 (역할 분리)
- WebSocket도 동일한 NLB로 처리 가능 (NLB는 Layer 4 TCP)

---

### 왜 WebSocket도 NLB 1개로 가능한가?

**NLB 특성:**
- Layer 4 (TCP) 로드밸런서
- TCP 연결 유지 가능
- WebSocket은 TCP 위에서 작동

**동작:**
```
Client (WebSocket 연결)
  ↓
API Gateway WebSocket API
  ↓
VPC Link
  ↓
NLB (TCP 연결 유지)
  ↓
Notification Pod (WebSocket 연결 유지)
```

**결론:**
- LoadBalancer든 TargetGroupBinding이든 **NLB는 동일하게 작동**
- WebSocket 때문에 별도 NLB 필요 없음
- 모든 Service를 ClusterIP + TargetGroupBinding으로 통일 가능

---

### 실무 패턴

**표준 패턴 (API Gateway + Kubernetes):**
1. Terraform: NLB + Target Group 생성
2. Kubernetes: 모든 Service를 ClusterIP
3. TargetGroupBinding: Pod IP를 NLB Target Group에 연결

**피해야 할 패턴:**
- ❌ 일부는 LoadBalancer, 일부는 ClusterIP (일관성 없음)
- ❌ Kubernetes가 NLB 생성 (Terraform과 역할 중복)

**배운 점:**
- 처음부터 전체 아키텍처를 설계하고 구현해야 함
- 일관성이 가장 중요
- Terraform(인프라)과 Kubernetes(애플리케이션) 역할 분리

---

## 환경 변수

**ConfigMap**: 민감하지 않은 설정
```yaml
MONGODB_URI: mongodb+srv://...
EMPLOYEE_SERVICE_URL: http://employee-service:8081
KAFKA_BOOTSTRAP_SERVERS: kafka-service:9092
```

**Secret**: 민감한 정보 (base64)
```yaml
MYSQL_USERNAME: YWRtaW4=
MYSQL_PASSWORD: <base64-encoded>
```

**개선 필요**: AWS Secrets Manager 연동

---

## 모니터링

```bash
# 로그
kubectl logs -n erp-dev -l app=employee-service -f

# 리소스
kubectl top pods -n erp-dev

# 상태
kubectl get pods -n erp-dev -o wide
```

---

## 트러블슈팅

**Pod CrashLoopBackOff:**
```bash
kubectl logs -n erp-dev <pod-name> --previous
kubectl describe pod -n erp-dev <pod-name>
```

**Service 연결 실패:**
```bash
kubectl get endpoints -n erp-dev
kubectl describe svc -n erp-dev employee-service
```

**HPA 작동 안 함:**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## 라이선스

MIT License
