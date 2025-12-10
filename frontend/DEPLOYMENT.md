# 프론트엔드 배포 가이드

## ✅ 배포 완료 정보

- **CloudFront URL**: https://d95pjcr73gr6g.cloudfront.net
- **Distribution ID**: E3HPT0O3YKLR5N
- **S3 Bucket**: erp-dev-frontend-dev
- **API Gateway**: https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev

## 1. 빠른 배포 (스크립트 사용)

```bash
./deploy.sh
```

## 2. 수동 배포

### 2.1 빌드
```bash
npm run build
```

### 2.2 S3 업로드
```bash
aws s3 sync dist/ s3://erp-dev-frontend-dev/ --delete
```

### 2.3 CloudFront 캐시 무효화
```bash
aws cloudfront create-invalidation \
  --distribution-id E3HPT0O3YKLR5N \
  --paths "/*"
```

## 3. 접속 확인

```
https://d95pjcr73gr6g.cloudfront.net
```

## 4. 환경변수 설정

`.env.production` 파일에 API Gateway URL이 설정되어 있습니다:
```
VITE_API_BASE_URL=https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev
```

## 5. 주의사항

- 빌드 시 환경변수가 번들에 포함됨 (재빌드 필요)
- CloudFront 캐시 무효화는 5-10분 소요
- API Gateway CORS 설정 확인 필요
