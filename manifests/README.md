# Kubernetes Manifests

EKS에 배포되는 Kubernetes 리소스 정의 파일들입니다.

## 구조

```
manifests/
├── base/                           # 공통 리소스
│   ├── namespace.yaml              # erp-dev 네임스페이스
│   └── configmap.yaml              # 환경 변수
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

## 배포

```bash
# Namespace 생성
kubectl apply -f base/namespace.yaml

# ConfigMap 생성
kubectl apply -f base/configmap.yaml

# Secret 생성 (수동)
kubectl create secret generic erp-secrets \
  --from-literal=mysql-url="jdbc:mysql://RDS_ENDPOINT:3306/erp_db" \
  --from-literal=mysql-password=PASSWORD \
  --from-literal=mongodb-uri=MONGODB_URI \
  -n erp-dev

# 서비스 배포
kubectl apply -f employee/
kubectl apply -f approval-request/
kubectl apply -f approval-processing/
kubectl apply -f notification/

# 확인
kubectl get pods -n erp-dev
kubectl get svc -n erp-dev
kubectl get targetgroupbinding -n erp-dev
```

## 주요 리소스

### Deployment
- Replicas: 2
- Image: ECR (806332783810.dkr.ecr.ap-northeast-2.amazonaws.com)
- Resources:
  - Requests: CPU 250m, Memory 512Mi
  - Limits: CPU 500m, Memory 1Gi

### Service
- Type: ClusterIP
- Ports: 8081-8084

### HPA (Horizontal Pod Autoscaler)
- Min Replicas: 2
- Max Replicas: 5
- Target CPU: 70%

### TargetGroupBinding
- AWS Load Balancer Controller가 자동으로 NLB Target Group에 Pod IP 등록
- Health Check: /actuator/health

## 환경 변수

**ConfigMap (erp-config)**:
```yaml
SPRING_PROFILES_ACTIVE: prod
GRPC_SERVER_PORT: 9090
NOTIFICATION_SERVICE_URL: http://notification-service:8084
```

**Secret (erp-secrets)**:
```yaml
mysql-url: jdbc:mysql://RDS_ENDPOINT:3306/erp_db
mysql-password: PASSWORD
mongodb-uri: mongodb+srv://...
redis-host: REDIS_ENDPOINT
redis-port: 6379
```

## CI/CD

CodePipeline이 Git Push를 감지하면:
1. CodeBuild가 Docker 이미지 빌드
2. ECR에 이미지 푸시
3. Kubernetes가 Rolling Update 수행

## 롤백

```bash
# 이전 버전으로 롤백
kubectl rollout undo deployment/employee-service -n erp-dev

# 특정 버전으로 롤백
kubectl rollout undo deployment/employee-service --to-revision=2 -n erp-dev

# 롤아웃 히스토리 확인
kubectl rollout history deployment/employee-service -n erp-dev
```

## 로그 확인

```bash
# Pod 로그
kubectl logs -f deployment/employee-service -n erp-dev

# 최근 100줄
kubectl logs --tail=100 deployment/employee-service -n erp-dev

# 특정 Pod 로그
kubectl logs employee-service-bb8786ffb-62bb8 -n erp-dev
```

## 스케일링

```bash
# 수동 스케일링
kubectl scale deployment/employee-service --replicas=3 -n erp-dev

# HPA 확인
kubectl get hpa -n erp-dev
```
