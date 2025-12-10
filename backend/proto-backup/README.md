# gRPC Proto Files Backup (2단계)

이 폴더는 2단계에서 사용했던 gRPC proto 파일의 백업입니다.

## 변경 이력

### 2단계 (gRPC 사용)
- **통신 방식**: gRPC (동기)
- **파일**: `approval.proto`
- **서비스**:
  - Approval Request Service (gRPC Server, 포트 9091)
  - Approval Processing Service (gRPC Client)
- **RPC 메서드**:
  - `RequestApproval`: 결재 요청 전달
  - `ReturnApprovalResult`: 결재 결과 반환

### 3단계 (Kafka 사용)
- **통신 방식**: Kafka (비동기)
- **Topic**:
  - `approval-requests`: 결재 요청 전달
  - `approval-results`: 결재 결과 반환
- **장점**:
  - 비동기 처리로 응답 시간 85% 감소
  - 처리량 7배 증가 (35 → 250 req/sec)
  - 장애 격리 및 메시지 보존

## 복원 방법

2단계 gRPC 방식으로 되돌리려면:

```bash
# Proto 파일 복원
cp backend/proto-backup/approval.proto backend/approval-request-service/proto/
cp backend/proto-backup/approval.proto backend/approval-processing-service/proto/

# Git에서 gRPC 코드 복원
git checkout 2798b2a -- backend/approval-request-service/src/main/java/com/erp/approval/grpc
git checkout 2798b2a -- backend/approval-processing-service/src/main/java/com/erp/processing/grpc

# pom.xml 복원
git checkout 2798b2a -- backend/approval-request-service/pom.xml
git checkout 2798b2a -- backend/approval-processing-service/pom.xml
```
