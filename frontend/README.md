# ERP 프론트엔드

**프레임워크**: React 18  
**빌드 도구**: Vite  
**배포**: AWS S3 + CloudFront  
**최종 업데이트**: 2025-12-10

---

## 프로젝트 구조

```
frontend/
├── src/
│   ├── components/         # React 컴포넌트
│   │   ├── EmployeeManagement.jsx      # 직원 관리
│   │   ├── CreateApproval.jsx           # 결재 요청
│   │   ├── ApprovalQueue.jsx            # 대기 목록
│   │   ├── AllApprovals.jsx             # 전체 결재
│   │   └── Notifications.jsx            # 실시간 알림
│   ├── services/           # API 서비스
│   │   ├── employeeService.js
│   │   ├── approvalService.js
│   │   ├── processingService.js
│   │   └── notificationService.js
│   ├── config/
│   │   └── api.js          # API 엔드포인트 설정
│   ├── App.jsx
│   └── main.jsx
├── package.json
└── .env.production
```

---

## 주요 컴포넌트

**EmployeeManagement**: 직원 목록 조회, 생성, 수정, 삭제  
**CreateApproval**: 결재 요청 생성 (제목, 내용, 결재 단계)  
**ApprovalQueue**: 결재자별 대기 목록 조회 및 승인/반려  
**AllApprovals**: 전체 결재 내역 조회 (상태별 표시)  
**Notifications**: WebSocket 실시간 알림 수신 및 표시

---

## 빠른 시작

### 로컬 개발

```bash
npm install
npm run dev
```

접속: http://localhost:5173

### 프로덕션 빌드

```bash
npm run build
```

출력: `dist/` 폴더

---

## 환경 설정

**.env (로컬)**
```
VITE_API_BASE_URL=http://localhost
VITE_WS_BASE_URL=http://localhost:8084
```

**.env.production (프로덕션)**
```
VITE_API_BASE_URL=https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev
VITE_WS_BASE_URL=http://a1f6404ce73204456ab80c9b7067c1b7-31ca2443dda9c9fd.elb.ap-northeast-2.amazonaws.com:8084
```

---

## 배포

### S3 + CloudFront

```bash
npm run build
aws s3 sync dist/ s3://erp-dev-frontend-dev --delete
aws cloudfront create-invalidation --distribution-id E3HPT0O3YKLR5N --paths "/*"
```

**배포 URL**
- HTTPS (CloudFront): https://d95pjcr73gr6g.cloudfront.net
- HTTP (S3): http://erp-dev-frontend-dev.s3-website.ap-northeast-2.amazonaws.com

---

## API 서비스

**employeeService.js**: 직원 CRUD API 호출  
**approvalService.js**: 결재 요청 생성 및 조회  
**processingService.js**: 결재 승인/반려 처리  
**notificationService.js**: WebSocket 연결 및 알림 수신

**WebSocket 연결**
- Protocol: SockJS + STOMP
- Endpoint: `/ws/notifications`
- Subscribe: `/topic/notifications`
- 브로드캐스트 방식 (모든 클라이언트에게 전송)

---

## 트러블슈팅

**WebSocket 연결 실패**
- HTTP 페이지로 접속 (http://erp-dev-frontend-dev.s3-website...)
- HTTPS 페이지에서는 ws:// 연결 불가

**CORS 에러**
- API Gateway CORS 설정 확인 (AllowOrigins: *)

---

## 라이선스

MIT License
