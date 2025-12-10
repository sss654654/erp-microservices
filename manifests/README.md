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
├── approval-processing/            # Approval Processing Service
└── notification/                   # Notification Service
```

---

## 배포

### 순서대로 실행

```bash
kubectl apply -f base/
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

## 리소스 설정

**Deployment**
- Replicas: 2
- Resources: CPU 200m-500m, Memory 256Mi-512Mi
- Liveness/Readiness Probe 설정
- Anti-Affinity (AZ 분산)

**Service**
- Type: ClusterIP (내부 통신)
- Notification Service만 LoadBalancer (Public NLB)

**HPA (Horizontal Pod Autoscaler)**
- Min: 2, Max: 3
- CPU Target: 70%
- metrics-server 필요 (현재 미설치)

**TargetGroupBinding**
- AWS Load Balancer Controller 사용
- Pod IP 자동 등록
- Target Type: ip

---

## 환경 변수

**ConfigMap (erp-config)**
- MONGODB_URI: MongoDB Atlas 연결 문자열
- EMPLOYEE_SERVICE_URL: http://employee-service:8081
- NOTIFICATION_SERVICE_URL: http://notification-service:8084
- REDIS_HOST: ElastiCache 엔드포인트
- GRPC 주소

**Secret (erp-secret)**
- MYSQL_USERNAME: admin (base64)
- MYSQL_PASSWORD: <secret> (base64)

---

## 모니터링

**로그 확인**
```bash
kubectl logs -n erp-dev -l app=employee-service -f
kubectl logs -n erp-dev -l app=employee-service --tail=50
```

**리소스 사용량**
```bash
kubectl top pods -n erp-dev
kubectl top nodes
```

**상태 확인**
```bash
kubectl get pods -n erp-dev -o wide
kubectl describe pod -n erp-dev <pod-name>
```

---

## 트러블슈팅

**Pod CrashLoopBackOff**
```bash
kubectl logs -n erp-dev <pod-name> --previous
kubectl describe pod -n erp-dev <pod-name>
```

**Service 연결 실패**
```bash
kubectl get endpoints -n erp-dev
kubectl run test-pod --rm -i --restart=Never --image=busybox -n erp-dev -- nslookup employee-service
```

**HPA 작동 안 함**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## 라이선스

MIT License
