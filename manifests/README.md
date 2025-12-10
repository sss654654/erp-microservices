# ERP Kubernetes Manifests

**Orchestration**: Kubernetes 1.31  
**Cluster**: Amazon EKS  
**Namespace**: erp-dev  
**최종 업데이트**: 2025-12-10

---

## 📋 Manifest 구성

### 디렉토리 구조

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
└── notification/                   # Notification Service
    ├── deployment.yaml
    ├── service.yaml
    ├── hpa.yaml
    └── targetgroupbinding.yaml
```

---

## 🚀 배포

### 1. Namespace 및 공통 리소스

```bash
kubectl apply -f base/namespace.yaml
kubectl apply -f base/configmap.yaml
```

### 2. 서비스 배포

```bash
# Employee Service
kubectl apply -f employee/

# Approval Request Service
kubectl apply -f approval-request/

# Approval Processing Service
kubectl apply -f approval-processing/

# Notification Service
kubectl apply -f notification/
```

### 3. 배포 확인

```bash
# Pod 상태
kubectl get pods -n erp-dev

# Service 상태
kubectl get svc -n erp-dev

# HPA 상태
kubectl get hpa -n erp-dev

# TargetGroupBinding 상태
kubectl get targetgroupbinding -n erp-dev
```

---

## 📊 리소스 설정

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: employee-service
  namespace: erp-dev
spec:
  replicas: 2
  selector:
    matchLabels:
      app: employee-service
  template:
    metadata:
      labels:
        app: employee-service
    spec:
      containers:
      - name: employee-service
        image: 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service:latest
        ports:
        - containerPort: 8081
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /employees
            port: 8081
          initialDelaySeconds: 90
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /employees
            port: 8081
          initialDelaySeconds: 60
          periodSeconds: 5
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: employee-service
  namespace: erp-dev
spec:
  selector:
    app: employee-service
  ports:
  - port: 8081
    targetPort: 8081
  type: ClusterIP
```

### HPA (Horizontal Pod Autoscaler)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: employee-service-hpa
  namespace: erp-dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: employee-service
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

### TargetGroupBinding

```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: employee-service-tgb
  namespace: erp-dev
spec:
  serviceRef:
    name: employee-service
    port: 8081
  targetGroupARN: arn:aws:elasticloadbalancing:ap-northeast-2:806332783810:targetgroup/erp-dev-employee-tg/xxx
  targetType: ip
```

---

## 🔧 환경 변수

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: erp-config
  namespace: erp-dev
data:
  MONGODB_URI: "mongodb+srv://erp_user:***@erp-dev-cluster.4fboxqw.mongodb.net/erp"
  EMPLOYEE_SERVICE_URL: "http://employee-service:8081"
  NOTIFICATION_SERVICE_URL: "http://notification-service:8084"
  REDIS_HOST: "erp-dev-redis.jmz0hq.0001.apn2.cache.amazonaws.com"
  REDIS_PORT: "6379"
  GRPC_APPROVAL_PROCESSING_ADDRESS: "static://approval-processing-service:9090"
  GRPC_APPROVAL_REQUEST_ADDRESS: "static://approval-request-service:9091"
```

### Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: erp-secret
  namespace: erp-dev
type: Opaque
data:
  MYSQL_USERNAME: YWRtaW4=  # base64 encoded
  MYSQL_PASSWORD: ZXJwMTIzNDUh  # base64 encoded
```

---

## 📊 모니터링

### Pod 로그

```bash
# 실시간 로그
kubectl logs -n erp-dev -l app=employee-service -f

# 최근 50줄
kubectl logs -n erp-dev -l app=employee-service --tail=50

# 특정 Pod
kubectl logs -n erp-dev <pod-name>
```

### Pod 상태

```bash
# 전체 Pod
kubectl get pods -n erp-dev -o wide

# 특정 Pod 상세
kubectl describe pod -n erp-dev <pod-name>
```

### 리소스 사용량

```bash
# CPU/Memory 사용량
kubectl top pods -n erp-dev

# Node 사용량
kubectl top nodes
```

---

## 🐛 트러블슈팅

### Pod CrashLoopBackOff

```bash
# 로그 확인
kubectl logs -n erp-dev <pod-name> --previous

# 이벤트 확인
kubectl describe pod -n erp-dev <pod-name>

# 환경 변수 확인
kubectl exec -n erp-dev <pod-name> -- env
```

### Service 연결 실패

```bash
# Service 엔드포인트 확인
kubectl get endpoints -n erp-dev

# Service DNS 테스트
kubectl run test-pod --rm -i --restart=Never --image=busybox -n erp-dev -- nslookup employee-service
```

### HPA 작동 안 함

```bash
# metrics-server 설치
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# HPA 상태 확인
kubectl describe hpa -n erp-dev employee-service-hpa
```

---

## 📚 참고 자료

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

---

## 📄 라이선스

MIT License
