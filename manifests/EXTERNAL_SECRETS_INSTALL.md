# External Secrets Operator 설치 방법

External Secrets Operator는 Helm으로 설치하는 것이 권장됩니다.

## 설치 명령어

```bash
# 1. Helm repo 추가
helm repo add external-secrets https://charts.external-secrets.io

# 2. Helm repo 업데이트
helm repo update

# 3. External Secrets Operator 설치
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace
```

## 설치 확인

```bash
kubectl get pods -n external-secrets-system
```

## 대안: kubectl로 설치 (Helm 없을 때)

```bash
# 1. CRDs 설치
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml

# 2. Operator 설치
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/manifests/external-secrets.yaml
```

## 참고

- 공식 문서: https://external-secrets.io/latest/introduction/getting-started/
- GitHub: https://github.com/external-secrets/external-secrets
