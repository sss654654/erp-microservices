# 03. Helm Chart 생성

**소요 시간**: 2시간  
**목표**: Plain YAML → Helm Chart 전환 (환경 분리, 템플릿 재사용)

---

## EKS Node 구조 설계

### 최종 Node 배치 (4개 Node, 2개 AZ)

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

### Pod 배치 전략

**서비스 Pod (8개):**
- Anti-Affinity로 2개 AZ에 균등 분산
- Kafka Node는 Taint 때문에 접근 불가
```
서비스 Node (2a): employee, approval-request, approval-processing, notification (각 1개)
서비스 Node (2c): employee, approval-request, approval-processing, notification (각 1개)
```

**Kafka + Zookeeper (4개):**
- nodeSelector + Toleration으로 Kafka Node로만 배치
- Anti-Affinity로 2개 AZ에 균등 분산
```
Kafka Node (2a): Kafka Pod 1, Zookeeper Pod 1
Kafka Node (2c): Kafka Pod 2, Zookeeper Pod 2
```

### 격리 메커니즘

**Taint (Node에 설정):**
- Kafka Node에 `workload=kafka:NoSchedule` Taint 추가
- 서비스 Pod는 Toleration 없어서 Kafka Node 접근 불가

**Toleration (Kafka Pod에 설정):**
- Kafka/Zookeeper만 Toleration 있어서 Kafka Node 접근 가능

**nodeSelector (Kafka Pod에 설정):**
- Kafka/Zookeeper는 `workload: kafka` 레이블 있는 Node로만 이동

**결과: 완벽한 격리**

---

##  기초 개념 이해

### 현재 구조 (Before)

**1. manifests 폴더 (Plain YAML)**
```
manifests/
├── base/
│   ├── configmap.yaml          # 공통 환경 변수 (하드코딩)
│   ├── secret.yaml             # 비밀번호 (평문)
│   └── targetgroupbinding.yaml # NLB 연결 (4개 서비스)
├── employee/
│   ├── employee-deployment.yaml      # Pod 생성 방법
│   ├── employee-service.yaml         # 네트워크 설정
│   └── employee-service-hpa.yaml     # Auto Scaling
├── approval-request/
│   └── ... (employee와 거의 동일)
├── approval-processing/
│   └── ... (employee와 거의 동일)
└── notification/
    └── ... (employee와 거의 동일)
```

**문제점:**
- 4개 서비스 파일이 거의 동일 (중복 400줄)
- 개발계/운영계 분리 불가 (하드코딩)
- 비밀번호가 Git에 평문으로 저장

**2. backend 폴더 (4개 buildspec.yml)**
```
backend/
├── employee-service/buildspec.yml
├── approval-request-service/buildspec.yml
├── approval-processing-service/buildspec.yml
└── notification-service/buildspec.yml
```

**각 buildspec.yml 내용 (거의 동일):**
```yaml
phases:
  pre_build:
    - ECR 로그인
    - kubeconfig 업데이트
  build:
    - mvn clean package
    - docker build
  post_build:
    - docker push
    - kubectl set image deployment/서비스명 ...  # ️ 이미지만 변경!
```

**문제점:**
- `kubectl set image`는 이미지만 변경
- manifests 파일 변경 (replicas, resources 등)은 반영 안 됨
- 4개 파일 중복

---

### Helm Chart 구조 (After)

**1. helm-chart 폴더 (템플릿 + 설정 분리)**
```
helm-chart/
├── Chart.yaml              # Helm Chart 메타데이터
├── values-dev.yaml         # 개발계 설정 (변수)
├── values-prod.yaml        # 운영계 설정 (미래)
└── templates/              # 템플릿 (재사용)
    ├── deployment.yaml     # 4개 서비스 통합 템플릿
    ├── service.yaml        # 4개 서비스 통합 템플릿
    └── ...
```

**핵심 개념:**

**템플릿 (templates/):**
- Go 템플릿 문법 사용
- `{{ .Values.xxx }}` 형태로 변수 참조
- 1개 파일로 4개 서비스 생성 가능

**예시:**
```yaml
# templates/deployment.yaml (1개 파일)
{{- range $key, $service := .Values.services }}  # 서비스 개수만큼 반복
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $service.name }}  # employee-service, approval-request-service...
spec:
  replicas: {{ $service.replicaCount }}  # values-dev.yaml에서 가져옴
  template:
    spec:
      containers:
      - image: "{{ $service.image.repository }}:{{ $service.image.tag }}"
        resources:
          {{- toYaml $service.resources | nindent 10 }}  # values에서 가져옴
{{- end }}
```

**설정 파일 (values-dev.yaml):**
- 환경별로 다른 값 저장
- 템플릿에서 `{{ .Values.xxx }}`로 참조

**예시:**
```yaml
# values-dev.yaml (개발계)
services:
  employee:
    name: employee-service
    replicaCount: 2           # 개발계는 2개
    image:
      repository: xxx/employee-service
      tag: latest
    resources:
      limits:
        memory: 512Mi         # 개발계는 512Mi

# values-prod.yaml (운영계)
services:
  employee:
    replicaCount: 5           # 운영계는 5개
    resources:
      limits:
        memory: 2Gi           # 운영계는 2Gi
```

**결과:**
- 1개 템플릿 → 4개 Deployment 생성
- 환경별 설정 분리 (dev/prod)
- 중복 코드 제거 (400줄 → 100줄)

---

### buildspec.yml 변화 (Phase 4에서 구현)

**Before (4개 파일):**
```yaml
# backend/employee-service/buildspec.yml
post_build:
  - kubectl set image deployment/employee-service ...  # 이미지만 변경
```

**After (1개 파일):**
```yaml
# 루트/buildspec.yml
post_build:
  - helm upgrade --install erp-microservices helm-chart/ \
      -f helm-chart/values-dev.yaml  # 전체 리소스 배포
```

**차이점:**
- `kubectl set image`: 이미지만 변경 (Deployment의 나머지는 그대로)
- `helm upgrade`: 전체 리소스 재배포 (Deployment, Service, HPA 모두 반영)

**예시:**
```yaml
# values-dev.yaml 수정
services:
  employee:
    replicaCount: 2 → 5  # Pod 개수 변경
    resources:
      limits:
        memory: 512Mi → 1Gi  # 메모리 변경
```

```bash
# Git Push 후 CodePipeline 실행
helm upgrade ...  # ← values-dev.yaml 변경사항이 자동 반영됨!
```

**결과:**
- Git이 진실 (Source of Truth)
- manifests 변경이 자동 반영
- 롤백 가능 (`helm rollback`)

---

##  현재 문제점 분석

### 문제 1: Plain YAML (환경 분리 불가)

**현재 구조:**
```
manifests/
├── base/
│   ├── configmap.yaml          # 하드코딩
│   └── secret.yaml             # 평문
├── employee/
│   ├── employee-deployment.yaml
│   ├── employee-service.yaml
│   └── employee-service-hpa.yaml
├── approval-request/
│   └── ... (거의 동일)
├── approval-processing/
│   └── ... (거의 동일)
└── notification/
    └── ... (거의 동일)
```

**문제:**
-  환경별 설정 분리 불가 (개발계/운영계)
-  4개 Deployment 파일 중복 (400줄 중 300줄 중복)
-  하드코딩된 값 (replicas, image, resources)
-  버전 관리 어려움 (배포 히스토리 없음)

**실제 파일 확인:**
```yaml
# manifests/employee/employee-deployment.yaml
spec:
  replicas: 2  # ← 하드코딩
  template:
    spec:
      containers:
      - image: xxx:latest  # ← 하드코딩
        resources:
          limits:
            memory: 512Mi  # ← 하드코딩
```

### 문제 2: Secret 평문 저장

**현재:**
```yaml
# manifests/base/secret.yaml
stringData:
  MYSQL_USERNAME: "admin"
  MYSQL_PASSWORD: "123456789"  # ️ Git에 평문 커밋
```

**문제:**
-  비밀번호가 Git에 노출
-  AWS Secrets Manager 미사용
-  실무에서 절대 금지

### 문제 3: LoadBalancer 중복

**현재:**
```yaml
# manifests/notification/notification-service.yaml
spec:
  type: LoadBalancer  # ️ 추가 NLB 생성
```

**문제:**
-  Terraform NLB + Kubernetes LoadBalancer = NLB 2개
-  비용 낭비 ($16/월)
-  일관성 없음

---

##  Helm Chart로 해결

### 해결 방법

**1. 환경 분리:**
```yaml
# values-dev.yaml
services:
  employee:
    replicaCount: 2
    resources:
      limits:
        memory: 512Mi

# values-prod.yaml
services:
  employee:
    replicaCount: 5
    resources:
      limits:
        memory: 2Gi
```

**2. 템플릿 재사용:**
```yaml
# templates/deployment.yaml
{{- range $key, $service := .Values.services }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $service.name }}
spec:
  replicas: {{ $service.replicaCount }}
  # ... 모든 서비스 동일 구조
{{- end }}
```

**3. Secret 제거:**
```yaml
# External Secrets Operator가 Secrets Manager에서 자동 동기화
# Git에는 Secret 없음
```

**4. 모든 Service ClusterIP:**
```yaml
# templates/service.yaml
spec:
  type: ClusterIP  # ← 모든 Service 통일
```

---

##  Helm Chart 구조

```
helm-chart/
├── Chart.yaml                      # 메타데이터
├── values-dev.yaml                 # 개발계 설정
├── values-prod.yaml                # 운영계 설정 (미래)
└── templates/
    ├── namespace.yaml              # Namespace
    ├── configmap.yaml              # 환경 변수
    ├── externalsecret.yaml         # Secrets Manager 연동
    ├── deployment.yaml             # 4개 서비스 통합
    ├── service.yaml                # ClusterIP (모두)
    ├── hpa.yaml                    # Auto Scaling
    ├── targetgroupbinding.yaml     # NLB 연결
    └── kafka.yaml                  # Kafka + Zookeeper
```

---

##  Step 1: External Secrets Operator 설치 (10분)

### 1-1. Helm으로 설치

```bash
# Helm repo 추가
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# 설치
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --wait
```

**확인:**
```bash
kubectl get pods -n external-secrets-system

# 예상 출력:
# NAME                                                READY   STATUS    RESTARTS   AGE
# external-secrets-xxx                                1/1     Running   0          1m
# external-secrets-cert-controller-xxx                1/1     Running   0          1m
# external-secrets-webhook-xxx                        1/1     Running   0          1m
```

---

##  Step 2: 폴더 생성 (5분)

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project

# Helm Chart 폴더 생성
mkdir -p helm-chart/templates

# 기존 manifests 폴더는 나중에 삭제 (백업용으로 유지)
```

---

## 📄 Step 3: Chart.yaml 작성 (5분)

```bash
cat > helm-chart/Chart.yaml << 'EOF'
apiVersion: v2
name: erp-microservices
description: ERP Microservices Helm Chart with AWS Secrets Manager Integration
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: ERP Team
    email: team@erp.com
EOF
```

---

## 📄 Step 4: values-dev.yaml 작성 (30분)

```bash
cat > helm-chart/values-dev.yaml << 'EOF'
# 개발 환경 설정
namespace: erp-dev

# AWS Secrets Manager 설정
secretsManager:
  enabled: true
  region: ap-northeast-2
  secrets:
    rds:
      name: erp/dev/mysql  #  Terraform이 생성한 실제 Secret 이름
      keys:
        - username
        - password
        - host
        - port
        - database

# 공통 설정
config:
  # MongoDB는 Atlas 사용 (외부), ConfigMap에 URI 하드코딩
  mongodbUri: "mongodb+srv://erp_user:2dvZYzleqGYdyANc@erp-dev-cluster.4fboxqw.mongodb.net/erp"
  redisHost: "erp-dev-redis.jmz0hq.0001.apn2.cache.amazonaws.com"
  redisPort: "6379"
  kafkaBootstrapServers: "kafka.erp-dev.svc.cluster.local:9092"

# 서비스별 설정
services:
  approvalRequest:
    enabled: true
    name: approval-request-service
    replicaCount: 2
    image:
      repository: 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/approval-request-service
      tag: latest
      pullPolicy: Always
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
    targetGroupArn: "arn:aws:elasticloadbalancing:ap-northeast-2:806332783810:targetgroup/erp-dev-approval-req-nlb-tg/665fd67efb37d9fb"
    env:
      - name: SPRING_DATA_MONGODB_URI
        valueFrom:
          secretKeyRef:
            name: mongodb-secret
            key: uri
      - name: EMPLOYEE_SERVICE_URL
        value: "http://employee-service:8081"
      - name: NOTIFICATION_SERVICE_URL
        value: "http://notification-service:8084"
      - name: SPRING_KAFKA_BOOTSTRAP_SERVERS
        value: "kafka.erp-dev.svc.cluster.local:9092"
  
  approvalProcessing:
    enabled: true
    name: approval-processing-service
    replicaCount: 2
    image:
      repository: 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/approval-processing-service
      tag: latest
      pullPolicy: Always
    port: 8083
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
    targetGroupArn: "arn:aws:elasticloadbalancing:ap-northeast-2:806332783810:targetgroup/erp-dev-approval-proc-nlb-tg/0bd3707f32e721cd"
    env:
      - name: SPRING_KAFKA_BOOTSTRAP_SERVERS
        value: "kafka.erp-dev.svc.cluster.local:9092"
  
  employee:
    enabled: false  # Lambda로 전환됨
    name: employee-service
    replicaCount: 2
    image:
      repository: 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service
      tag: latest
      pullPolicy: Always
    port: 8081
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
    targetGroupArn: "arn:aws:elasticloadbalancing:ap-northeast-2:806332783810:targetgroup/erp-dev-employee-nlb-tg/e8df94d1784737ee"
    env:
      - name: SPRING_DATASOURCE_URL
        value: "jdbc:mysql://erp-dev-mysql.cniqqqqiyu1n.ap-northeast-2.rds.amazonaws.com:3306/erp?useSSL=true"
      - name: SPRING_DATASOURCE_USERNAME
        valueFrom:
          secretKeyRef:
            name: rds-secret
            key: username
      - name: SPRING_DATASOURCE_PASSWORD
        valueFrom:
          secretKeyRef:
            name: rds-secret
            key: password
  
  notification:
    enabled: true
    name: notification-service
    replicaCount: 2
    image:
      repository: 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/notification-service
      tag: latest
      pullPolicy: Always
    port: 8084
    resources:
      requests:
        cpu: 150m
        memory: 200Mi
      limits:
        cpu: 400m
        memory: 300Mi
    hpa:
      enabled: true
      minReplicas: 2
      maxReplicas: 3
      targetCPUUtilizationPercentage: 70
    targetGroupArn: "arn:aws:elasticloadbalancing:ap-northeast-2:806332783810:targetgroup/erp-dev-notification-nlb-tg/671f2eb0a241a3f2"
    env:
      - name: REDIS_HOST
        value: "erp-dev-redis.jmz0hq.0001.apn2.cache.amazonaws.com"
      - name: REDIS_PORT
        value: "6379"

# Kafka 설정
kafka:
  enabled: true
  replicaCount: 1
  image:
    repository: confluentinc/cp-kafka
    tag: 7.5.0
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi

# Zookeeper 설정
zookeeper:
  enabled: true
  replicaCount: 1
  image:
    repository: confluentinc/cp-zookeeper
    tag: 7.5.0
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 250m
      memory: 512Mi
EOF
```

---

## 📄 Step 5: templates/ 파일 작성 (1시간)

### 5-1. namespace.yaml

```bash
cat > helm-chart/templates/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.namespace }}
EOF
```

### 5-2. externalsecret.yaml

```bash
cat > helm-chart/templates/externalsecret.yaml << 'EOF'
{{- if .Values.secretsManager.enabled }}
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rds-secret
  namespace: {{ .Values.namespace }}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: rds-secret
    creationPolicy: Owner
  data:
  {{- range .Values.secretsManager.secrets.rds.keys }}
  - secretKey: {{ . }}
    remoteRef:
      key: {{ $.Values.secretsManager.secrets.rds.name }}
      property: {{ . }}
  {{- end }}
{{- end }}
EOF
```

**️ MongoDB Secret 제거:**
- MongoDB는 Atlas 사용 (외부 관리)
- Secrets Manager에 저장 불필요
- ConfigMap에 URI 하드코딩 (개발 환경)

### 5-3. deployment.yaml

```bash
cat > helm-chart/templates/deployment.yaml << 'EOF'
{{- range $key, $service := .Values.services }}
{{- if $service.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $service.name }}
  namespace: {{ $.Values.namespace }}
  labels:
    app: {{ $service.name }}
spec:
  replicas: {{ $service.replicaCount }}
  selector:
    matchLabels:
      app: {{ $service.name }}
  template:
    metadata:
      labels:
        app: {{ $service.name }}
    spec:
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
      containers:
      - name: {{ $service.name }}
        image: "{{ $service.image.repository }}:{{ $service.image.tag }}"
        imagePullPolicy: {{ $service.image.pullPolicy }}
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
          capabilities:
            drop: [ALL]
        ports:
        - containerPort: {{ $service.port }}
          name: http
        resources:
          {{- toYaml $service.resources | nindent 10 }}
        {{- if $service.env }}
        env:
          {{- toYaml $service.env | nindent 8 }}
        {{- end }}
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: {{ $service.port }}
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: {{ $service.port }}
          initialDelaySeconds: 30
          periodSeconds: 5
{{- end }}
{{- end }}
EOF
```

### 5-4. service.yaml

```bash
cat > helm-chart/templates/service.yaml << 'EOF'
{{- range $key, $service := .Values.services }}
{{- if $service.enabled }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $service.name }}
  namespace: {{ $.Values.namespace }}
spec:
  type: ClusterIP
  selector:
    app: {{ $service.name }}
  ports:
  - port: {{ $service.port }}
    targetPort: {{ $service.port }}
    protocol: TCP
    name: http
{{- end }}
{{- end }}
EOF
```

### 5-5. hpa.yaml

```bash
cat > helm-chart/templates/hpa.yaml << 'EOF'
{{- range $key, $service := .Values.services }}
{{- if and $service.enabled $service.hpa.enabled }}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ $service.name }}-hpa
  namespace: {{ $.Values.namespace }}
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
{{- end }}
{{- end }}
EOF
```

### 5-6. targetgroupbinding.yaml

```bash
cat > helm-chart/templates/targetgroupbinding.yaml << 'EOF'
{{- range $key, $service := .Values.services }}
{{- if $service.enabled }}
---
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: {{ $service.name }}-tgb
  namespace: {{ $.Values.namespace }}
spec:
  serviceRef:
    name: {{ $service.name }}
    port: {{ $service.port }}
  targetGroupARN: {{ $service.targetGroupArn }}
{{- end }}
{{- end }}
EOF
```

### 5-7. kafka.yaml

```bash
cat > helm-chart/templates/kafka.yaml << 'EOF'
{{- if .Values.kafka.enabled }}
---
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: {{ .Values.namespace }}
spec:
  ports:
  - port: 9092
  selector:
    app: kafka
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
        ports:
        - containerPort: 9092
        env:
        - name: KAFKA_BROKER_ID
          value: "1"
        - name: KAFKA_ZOOKEEPER_CONNECT
          value: "zookeeper:2181"
        - name: KAFKA_ADVERTISED_LISTENERS
          value: "PLAINTEXT://kafka.{{ .Values.namespace }}.svc.cluster.local:9092"
        - name: KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
          value: "1"
        - name: KAFKA_AUTO_CREATE_TOPICS_ENABLE
          value: "true"
        resources:
          {{- toYaml .Values.kafka.resources | nindent 10 }}
{{- end }}
---
{{- if .Values.zookeeper.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: zookeeper
  namespace: {{ .Values.namespace }}
spec:
  ports:
  - port: 2181
  selector:
    app: zookeeper
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zookeeper
  namespace: {{ .Values.namespace }}
spec:
  replicas: {{ .Values.zookeeper.replicaCount }}
  selector:
    matchLabels:
      app: zookeeper
  template:
    metadata:
      labels:
        app: zookeeper
    spec:
      containers:
      - name: zookeeper
        image: "{{ .Values.zookeeper.image.repository }}:{{ .Values.zookeeper.image.tag }}"
        ports:
        - containerPort: 2181
        env:
        - name: ZOOKEEPER_CLIENT_PORT
          value: "2181"
        - name: ZOOKEEPER_TICK_TIME
          value: "2000"
        resources:
          {{- toYaml .Values.zookeeper.resources | nindent 10 }}
{{- end }}
EOF
```

---

##  Step 6: 검증 (10분)

### 5-1. Helm Lint

```bash
cd helm-chart

helm lint . -f values-dev.yaml
```

**성공 메시지:**
```
==> Linting .
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed
```

### 5-2. Helm Template (Dry-run)

```bash
helm template . -f values-dev.yaml > test-output.yaml

# 생성된 YAML 확인
cat test-output.yaml | head -50
```

### 5-3. 리소스 개수 확인

```bash
# Deployment 개수 (4개 서비스 + Kafka + Zookeeper = 6개)
grep -c "kind: Deployment" test-output.yaml
# 6

# Service 개수 (4개 서비스 + Kafka + Zookeeper = 6개)
grep -c "kind: Service" test-output.yaml
# 6

# HPA 개수 (4개)
grep -c "kind: HorizontalPodAutoscaler" test-output.yaml
# 4

# TargetGroupBinding 개수 (4개)
grep -c "kind: TargetGroupBinding" test-output.yaml
# 4
```

---

##  완료 체크리스트

- [ ] helm-chart/ 폴더 생성
- [ ] Chart.yaml 작성
- [ ] values-dev.yaml 작성
- [ ] templates/namespace.yaml 작성
- [ ] templates/externalsecret.yaml 작성
- [ ] templates/deployment.yaml 작성
- [ ] templates/service.yaml 작성
- [ ] templates/hpa.yaml 작성
- [ ] templates/targetgroupbinding.yaml 작성
- [ ] templates/kafka.yaml 작성
- [ ] helm lint 통과
- [ ] helm template 출력 확인
- [ ] 리소스 개수 확인 (Deployment 6, Service 6, HPA 4, TGB 4)

---

##  다음 단계

**Helm Chart 생성 완료!**

**다음 파일을 읽으세요:**
→ **03.5_LAMBDA.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 03.5_LAMBDA.md
```

---

**"Helm Chart가 완성되었습니다. 이제 Secrets Manager를 설정할 차례입니다!"**
