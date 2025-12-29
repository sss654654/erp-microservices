# ERP Microservices Helm Chart

Kubernetes 환경에서 ERP 마이크로서비스를 배포하기 위한 Helm Chart입니다.

**Orchestration**: Kubernetes 1.31  
**Cluster**: Amazon EKS  
**Namespace**: erp-dev  
**Helm Version**: 3.x

---

## 목차

1. [아키텍처 개요](#아키텍처-개요)
2. [Plain YAML에서 Helm Chart로 전환](#plain-yaml에서-helm-chart로-전환)
3. [Chart 구조](#chart-구조)
4. [배포 가이드](#배포-가이드)
5. [설정 관리](#설정-관리)
6. [Node 배치 전략](#node-배치-전략)
7. [X-Ray 트레이싱](#x-ray-트레이싱)
8. [트러블슈팅](#트러블슈팅)

---

## 아키텍처 개요

### 서비스 구성

**Lambda (AWS):**
- employee-service (8081)

**EKS (Kubernetes):**
- approval-request-service (8082)
- approval-processing-service (8083)
- notification-service (8084)
- kafka (9092)
- zookeeper (2181)

### 외부 연결

```
CloudFront (HTTPS)
  ↓
S3 (Frontend)
  ↓
API Gateway
  ↓
VPC Link
  ↓
NLB (Terraform 관리)
  ├─ Target Group 8081 → Lambda (employee-service)
  ├─ Target Group 8082 → EKS (approval-request-service)
  ├─ Target Group 8083 → EKS (approval-processing-service)
  └─ Target Group 8084 → EKS (notification-service)
```

### 내부 통신

```
approval-request-service
  ├─ gRPC → approval-processing-service (9090)
  ├─ Kafka → notification-service
  └─ REST → employee-service (Lambda via NLB)

approval-processing-service
  ├─ Kafka → notification-service
  └─ REST → employee-service (Lambda via NLB)
```

---

## Plain YAML에서 Helm Chart로 전환

### 전환 이유

**Before (Plain YAML):**
```
manifests/
├── approval-request/
│   ├── deployment.yaml (100줄)
│   ├── service.yaml (20줄)
│   └── hpa.yaml (15줄)
├── approval-processing/
│   ├── deployment.yaml (100줄, 거의 동일)
│   ├── service.yaml (20줄, 거의 동일)
│   └── hpa.yaml (15줄, 거의 동일)
└── notification/
    └── ... (거의 동일)
```

**문제점:**
1. 중복 코드 400줄 (3개 서비스 × 135줄)
2. 환경 분리 불가 (dev/prod 하드코딩)
3. 변경 시 3개 파일 모두 수정 필요
4. Git에 비밀번호 평문 저장

**After (Helm Chart):**
```
helm-chart/
├── Chart.yaml
├── values-dev.yaml (개발 설정)
├── values-prod.yaml (운영 설정)
└── templates/
    ├── deployment.yaml (1개 템플릿 → 3개 Deployment 생성)
    ├── service.yaml (1개 템플릿 → 3개 Service 생성)
    └── hpa.yaml (1개 템플릿 → 3개 HPA 생성)
```

**개선 효과:**
1. 코드 75% 감소 (400줄 → 100줄)
2. 환경별 설정 분리 (values-dev.yaml, values-prod.yaml)
3. 1개 템플릿 수정 → 3개 서비스 자동 반영
4. AWS Secrets Manager 연동 (ExternalSecrets)

---

## Chart 구조

### 디렉토리 구조

```
helm-chart/
├── Chart.yaml                      # Chart 메타데이터
├── values-dev.yaml                 # 개발 환경 설정
├── values-prod.yaml                # 운영 환경 설정 (미래)
├── templates/
│   ├── _helpers.tpl                # 공통 함수
│   ├── deployment.yaml             # Deployment 템플릿
│   ├── service.yaml                # Service 템플릿
│   ├── hpa.yaml                    # HPA 템플릿
│   ├── targetgroupbinding.yaml     # NLB 연결
│   ├── externalsecret.yaml         # AWS Secrets Manager 연동
│   ├── kafka-deployment.yaml       # Kafka
│   ├── kafka-service.yaml
│   ├── zookeeper-deployment.yaml   # Zookeeper
│   ├── zookeeper-service.yaml
│   └── xray-daemonset.yaml         # X-Ray 트레이싱
└── README.md
```

### Chart.yaml

```yaml
apiVersion: v2
name: erp-microservices
description: ERP Microservices Helm Chart
type: application
version: 1.0.0
appVersion: "1.0.0"
```

### 템플릿 구조

**핵심 개념: 1개 템플릿 → 여러 리소스 생성**

```yaml
# templates/deployment.yaml
{{- range $key, $service := .Values.services }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $service.name }}
  namespace: {{ $.Values.namespace }}
spec:
  replicas: {{ $service.replicaCount }}
  template:
    spec:
      containers:
      - name: {{ $service.name }}
        image: "{{ $service.image.repository }}:{{ $service.image.tag }}"
        ports:
        - containerPort: {{ $service.port }}
        resources:
          {{- toYaml $service.resources | nindent 10 }}
{{- end }}
```

**결과:**
- values-dev.yaml에 3개 서비스 정의
- 1개 템플릿이 3번 반복 실행
- 3개 Deployment 자동 생성

---

## 배포 가이드

### 사전 준비

**1. AWS CLI 설정**
```bash
aws configure
```

**2. kubectl 설정**
```bash
aws eks update-kubeconfig --region ap-northeast-2 --name erp-dev-cluster
```

**3. Helm 설치**
```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 확인
helm version
```

**4. External Secrets Operator 설치**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

### 배포 명령어

**개발 환경 배포:**
```bash
cd helm-chart

# Dry-run (실제 배포 없이 확인)
helm install erp-microservices . -f values-dev.yaml --dry-run --debug

# 실제 배포
helm install erp-microservices . -f values-dev.yaml -n erp-dev --create-namespace

# 업그레이드 (변경사항 반영)
helm upgrade erp-microservices . -f values-dev.yaml -n erp-dev
```

**운영 환경 배포 (미래):**
```bash
helm upgrade --install erp-microservices . -f values-prod.yaml -n erp-prod --create-namespace
```

### 배포 확인

```bash
# Helm Release 확인
helm list -n erp-dev

# Pod 상태
kubectl get pods -n erp-dev -o wide

# Service 확인
kubectl get svc -n erp-dev

# HPA 확인
kubectl get hpa -n erp-dev

# TargetGroupBinding 확인
kubectl get targetgroupbinding -n erp-dev

# ExternalSecret 확인
kubectl get externalsecret -n erp-dev
kubectl get secret -n erp-dev
```

### 롤백

```bash
# 히스토리 확인
helm history erp-microservices -n erp-dev

# 이전 버전으로 롤백
helm rollback erp-microservices 1 -n erp-dev
```

### 삭제

```bash
# Chart 삭제 (Pod, Service 등 모두 삭제)
helm uninstall erp-microservices -n erp-dev

# Namespace 삭제
kubectl delete namespace erp-dev
```

---

## 설정 관리

### values-dev.yaml 구조

```yaml
namespace: erp-dev
region: ap-northeast-2

# 3개 EKS 서비스 설정
services:
  approvalRequest:
    name: approval-request-service
    replicaCount: 2
    image:
      repository: 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/approval-request-service
      tag: latest
    port: 8082
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
    hpa:
      enabled: true
      minReplicas: 2
      maxReplicas: 3
      targetCPUUtilizationPercentage: 70
    env:
      MONGODB_URI: "mongodb+srv://..."
      KAFKA_BOOTSTRAP_SERVERS: "kafka-service:9092"
      GRPC_ADDRESS: "approval-processing-service:9090"
    
  approvalProcessing:
    # 동일 구조
    
  notification:
    # 동일 구조
```

### 환경별 차이

| 설정 | 개발 (dev) | 운영 (prod) |
|------|-----------|------------|
| replicaCount | 2 | 5 |
| minReplicas | 2 | 5 |
| maxReplicas | 3 | 20 |
| CPU requests | 200m | 500m |
| Memory requests | 256Mi | 1Gi |
| CPU limits | 500m | 2000m |
| Memory limits | 512Mi | 2Gi |

### 비밀 정보 관리

**AWS Secrets Manager 연동 (ExternalSecrets):**

```yaml
# templates/externalsecret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: mysql-secret
spec:
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: mysql-secret
  data:
  - secretKey: username
    remoteRef:
      key: erp/dev/mysql
      property: username
  - secretKey: password
    remoteRef:
      key: erp/dev/mysql
      property: password
```

**동작 과정:**
1. ExternalSecret이 AWS Secrets Manager에서 비밀 정보 가져옴
2. Kubernetes Secret 자동 생성
3. Pod가 Secret 마운트하여 사용
4. Git에 비밀번호 저장 불필요

---

## Node 배치 전략

### EKS Node 구조

**Node Group 1 (서비스용, 2개):**
```
ap-northeast-2a: 1개 Node (Taint 없음)
ap-northeast-2c: 1개 Node (Taint 없음)
```

**Node Group 2 (Kafka 전용, 2개):**
```
ap-northeast-2a: 1개 Node (Taint: workload=kafka:NoSchedule)
ap-northeast-2c: 1개 Node (Taint: workload=kafka:NoSchedule)
```

### Pod 배치

**서비스 Pod (6개):**
- Anti-Affinity로 2개 AZ에 균등 분산
- Kafka Node는 Taint 때문에 접근 불가

```
서비스 Node (2a): approval-request-1, approval-processing-1, notification-1
서비스 Node (2c): approval-request-2, approval-processing-2, notification-2
```

**Kafka + Zookeeper (4개):**
- nodeSelector + Toleration으로 Kafka Node로만 배치
- Anti-Affinity로 2개 AZ에 균등 분산

```
Kafka Node (2a): kafka-1, zookeeper-1
Kafka Node (2c): kafka-2, zookeeper-2
```

### 격리 메커니즘

**1. Taint (Node에 설정):**
```yaml
# Terraform에서 설정
taints = [{
  key    = "workload"
  value  = "kafka"
  effect = "NoSchedule"
}]
```

**2. Toleration (Kafka Pod에 설정):**
```yaml
# templates/kafka-deployment.yaml
tolerations:
- key: "workload"
  operator: "Equal"
  value: "kafka"
  effect: "NoSchedule"
```

**3. nodeSelector (Kafka Pod에 설정):**
```yaml
nodeSelector:
  workload: kafka
```

**4. Anti-Affinity (모든 Pod에 설정):**
```yaml
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
            - approval-request-service
        topologyKey: topology.kubernetes.io/zone
```

**결과:**
- 서비스 Pod는 Kafka Node 접근 불가 (Taint)
- Kafka Pod는 Kafka Node로만 이동 (nodeSelector + Toleration)
- 같은 서비스 Pod는 다른 AZ에 배치 (Anti-Affinity)
- 완벽한 격리 및 고가용성 확보

---

## X-Ray 트레이싱

### 아키텍처

```
Application Pod (Sidecar 패턴)
├─ Container 1: approval-request-service (8082)
└─ Container 2: xray-daemon (2000)
     ↓ UDP
AWS X-Ray Service
```

**Sidecar 패턴:**
- 각 Application Pod에 X-Ray Daemon 컨테이너 추가
- Application이 localhost:2000으로 트레이스 전송
- X-Ray Daemon이 AWS X-Ray로 전송

### Deployment 설정

```yaml
# templates/deployment.yaml
spec:
  template:
    spec:
      containers:
      # Application Container
      - name: {{ $service.name }}
        image: "{{ $service.image.repository }}:{{ $service.image.tag }}"
        env:
        - name: AWS_XRAY_DAEMON_ADDRESS
          value: "127.0.0.1:2000"
        - name: AWS_XRAY_CONTEXT_MISSING
          value: "LOG_ERROR"
      
      # X-Ray Daemon Sidecar
      - name: xray-daemon
        image: public.ecr.aws/xray/aws-xray-daemon:latest
        ports:
        - containerPort: 2000
          protocol: UDP
        resources:
          limits:
            memory: 256Mi
          requests:
            cpu: 50m
            memory: 128Mi
```

### DaemonSet (Lambda용)

```yaml
# templates/xray-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: xray-daemon
spec:
  template:
    spec:
      hostNetwork: true  # Node의 네트워크 사용
      containers:
      - name: xray-daemon
        image: public.ecr.aws/xray/aws-xray-daemon:latest
        ports:
        - containerPort: 2000
          protocol: UDP
          hostPort: 2000  # Node의 2000 포트 사용
```

**용도:**
- Lambda가 EKS Node의 2000 포트로 트레이스 전송
- DaemonSet이 모든 Node에 X-Ray Daemon 배포
- Lambda → Node IP:2000 → X-Ray Service

### 트레이싱 확인

```bash
# X-Ray Daemon 로그
kubectl logs -n erp-dev -l app=approval-request-service -c xray-daemon

# AWS X-Ray Console
https://console.aws.amazon.com/xray/home?region=ap-northeast-2#/service-map
```

---

## Kafka 구현

### 현재 구조 (Deployment)

```yaml
# templates/kafka-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: kafka
        image: confluentinc/cp-kafka:latest
        env:
        - name: KAFKA_BROKER_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
```

**문제점:**
1. 데이터 영속성 없음 (volumeClaimTemplates 없음)
2. Pod 재시작 시 메시지 소실
3. Stateful 애플리케이션을 Deployment로 배포

### 개선 방안 (StatefulSet)

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
  template:
    spec:
      containers:
      - name: kafka
        volumeMounts:
        - name: kafka-data
          mountPath: /var/lib/kafka/data
```

**개선 효과:**
- 각 Pod마다 고유 EBS 볼륨 (10Gi)
- Pod 재시작 시 데이터 보존
- 고정된 Pod 이름 (kafka-0, kafka-1, kafka-2)
- 비용: $2.4/월 (10Gi × 3개 × $0.08/GB)

**프로덕션 권장:**
- MSK (Managed Streaming for Kafka) 사용
- 비용: $310/월
- 관리 부담 감소, 고가용성 자동 확보

---

## TargetGroupBinding

### 역할

**Kubernetes Service를 AWS NLB에 연결:**

```yaml
# templates/targetgroupbinding.yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: approval-request-tgb
spec:
  serviceRef:
    name: approval-request-service
    port: 8082
  targetGroupARN: arn:aws:elasticloadbalancing:ap-northeast-2:806332783810:targetgroup/erp-dev-approval-req-nlb-tg/xxx
  targetType: ip
```

**동작 과정:**
1. AWS Load Balancer Controller가 TargetGroupBinding 감지
2. Service의 Endpoint (Pod IP) 조회
3. Pod IP를 NLB Target Group에 자동 등록
4. Pod 생성/삭제 시 자동으로 등록/해제

**구조:**
```
API Gateway
  ↓
VPC Link
  ↓
NLB (Terraform 생성)
  ├─ Target Group 8082 (Terraform 생성)
  │    ↓ TargetGroupBinding (Helm Chart)
  │    ├─ Pod IP 1 (자동 등록)
  │    └─ Pod IP 2 (자동 등록)
  ├─ Target Group 8083
  └─ Target Group 8084
```

**장점:**
- Terraform이 인프라 관리 (NLB, Target Group)
- Kubernetes가 애플리케이션 관리 (Pod)
- TargetGroupBinding이 둘을 연결
- 역할 분리 명확

---

## HPA (Horizontal Pod Autoscaler)

### 설정

```yaml
# templates/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ $service.name }}-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ $service.name }}
  minReplicas: {{ $service.hpa.minReplicas }}
  maxReplicas: {{ $service.hpa.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ $service.hpa.targetCPUUtilizationPercentage }}
```

### 동작

**CPU 70% 초과 시:**
```
현재: 2개 Pod (CPU 80%)
  ↓ HPA 감지
스케일 아웃: 3개 Pod (CPU 53%)
  ↓ 부하 감소
안정화
```

**CPU 50% 미만 시:**
```
현재: 3개 Pod (CPU 40%)
  ↓ HPA 감지 (5분 대기)
스케일 인: 2개 Pod (CPU 60%)
  ↓ 안정화
```

### 현재 상태

**metrics-server 미설치:**
```bash
# 설치 필요
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 확인
kubectl top pods -n erp-dev
```

**개발 환경:**
- HPA 구현만 해놓음 (실제 작동 안 함)
- 프로덕션 전환 시 활성화 예정

---

## 트러블슈팅

### Pod CrashLoopBackOff

**원인:**
- 애플리케이션 시작 실패
- 환경 변수 오류
- 외부 서비스 연결 실패 (RDS, MongoDB)

**해결:**
```bash
# 로그 확인
kubectl logs -n erp-dev <pod-name>

# 이전 로그 확인 (재시작 전)
kubectl logs -n erp-dev <pod-name> --previous

# 상세 정보
kubectl describe pod -n erp-dev <pod-name>
```

### Service 연결 실패

**원인:**
- Selector 불일치
- Pod가 Ready 상태 아님

**해결:**
```bash
# Endpoint 확인 (Pod IP가 등록되었는지)
kubectl get endpoints -n erp-dev

# Service 상세 정보
kubectl describe svc -n erp-dev approval-request-service

# Pod Label 확인
kubectl get pods -n erp-dev --show-labels
```

### HPA 작동 안 함

**원인:**
- metrics-server 미설치
- Resource requests 미설정

**해결:**
```bash
# metrics-server 설치
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 확인
kubectl top pods -n erp-dev
kubectl get hpa -n erp-dev
```

### TargetGroupBinding 실패

**원인:**
- AWS Load Balancer Controller 미설치
- IAM 권한 부족
- Target Group ARN 오류

**해결:**
```bash
# TargetGroupBinding 상태 확인
kubectl describe targetgroupbinding -n erp-dev

# AWS Load Balancer Controller 로그
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Target Group 확인 (AWS Console)
aws elbv2 describe-target-health --target-group-arn <arn>
```

### ExternalSecret 동기화 실패

**원인:**
- AWS Secrets Manager에 비밀 정보 없음
- IAM 권한 부족
- SecretStore 설정 오류

**해결:**
```bash
# ExternalSecret 상태
kubectl describe externalsecret -n erp-dev mysql-secret

# Secret 생성 확인
kubectl get secret -n erp-dev mysql-secret

# External Secrets Operator 로그
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets
```

### Kafka 연결 실패

**원인:**
- Kafka Pod가 Ready 상태 아님
- Zookeeper 연결 실패
- 네트워크 정책

**해결:**
```bash
# Kafka 로그
kubectl logs -n erp-dev -l app=kafka

# Zookeeper 로그
kubectl logs -n erp-dev -l app=zookeeper

# Kafka 연결 테스트
kubectl run kafka-test --image=confluentinc/cp-kafka:latest --rm -it --restart=Never -n erp-dev -- \
  kafka-topics --bootstrap-server kafka-service:9092 --list
```

---

## CI/CD 통합

### CodePipeline 배포

**buildspec.yml:**
```yaml
phases:
  pre_build:
    commands:
    - aws eks update-kubeconfig --region ap-northeast-2 --name erp-dev-cluster
  
  build:
    commands:
    - mvn clean package
    - docker build -t $IMAGE_URI .
    - docker push $IMAGE_URI
  
  post_build:
    commands:
    - helm upgrade --install erp-microservices helm-chart/ \
        -f helm-chart/values-dev.yaml \
        -n erp-dev \
        --set services.approvalRequest.image.tag=$IMAGE_TAG
```

**동작:**
1. Git Push
2. CodePipeline 트리거
3. 이미지 빌드 및 ECR 푸시
4. Helm upgrade (새 이미지 태그 적용)
5. Kubernetes Rolling Update

**장점:**
- Git이 진실 (Source of Truth)
- values-dev.yaml 변경 시 자동 반영
- 롤백 가능 (helm rollback)

---

## 모니터링

### 로그 확인

```bash
# 특정 Pod
kubectl logs -n erp-dev <pod-name> -f

# Label로 필터링
kubectl logs -n erp-dev -l app=approval-request-service -f

# 이전 로그 (재시작 전)
kubectl logs -n erp-dev <pod-name> --previous

# 여러 Pod 동시 확인 (stern 사용)
stern -n erp-dev approval-request-service
```

### 리소스 모니터링

```bash
# Pod 리소스 사용량
kubectl top pods -n erp-dev

# Node 리소스 사용량
kubectl top nodes

# HPA 상태
kubectl get hpa -n erp-dev -w
```

### X-Ray 트레이싱

```bash
# AWS X-Ray Console
https://console.aws.amazon.com/xray/home?region=ap-northeast-2#/service-map

# X-Ray Daemon 로그
kubectl logs -n erp-dev -l app=approval-request-service -c xray-daemon
```

---

## 라이선스

MIT License
