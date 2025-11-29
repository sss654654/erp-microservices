import { useState, useEffect } from 'react';
import { processingService } from '../services/processingService';

function ApprovalQueue({ approverId, refresh }) {
  const [queue, setQueue] = useState([]);
  const [loading, setLoading] = useState(false);

  const loadQueue = async () => {
    setLoading(true);
    try {
      const response = await processingService.getQueue(approverId);
      setQueue(response.data);
    } catch (error) {
      console.error('Error loading queue:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (approverId) {
      loadQueue();
    }
  }, [approverId, refresh]);

  const handleProcess = async (requestId, status) => {
    if (!confirm(`정말 ${status === 'approved' ? '승인' : '반려'}하시겠습니까?`)) {
      return;
    }

    try {
      await processingService.processApproval(approverId, requestId, status);
      alert(`결재가 ${status === 'approved' ? '승인' : '반려'}되었습니다!`);
      loadQueue();
    } catch (error) {
      alert('결재 처리 실패: ' + error.message);
    }
  };

  const getStatusText = (status) => {
    const map = { pending: '대기중', approved: '승인', rejected: '반려' };
    return map[status] || status;
  };

  return (
    <section className="section">
      <h2>⏳ 내 결재 대기 목록</h2>
      <button onClick={loadQueue} className="btn btn-secondary">
        새로고침
      </button>
      
      {loading ? (
        <div className="loading">로딩 중...</div>
      ) : queue.length === 0 ? (
        <div className="empty-state">대기 중인 결재가 없습니다</div>
      ) : (
        <div className="approval-list">
          {queue.map((item) => (
            <div key={item.requestId} className="approval-card">
              <div className="approval-header">
                <span className="approval-title">{item.title}</span>
                <span className="approval-id">ID: {item.requestId}</span>
              </div>
              <div className="approval-content">{item.content}</div>
              <div className="approval-steps">
                {item.steps.map((step) => (
                  <div key={step.step} className={`step step-${step.status}`}>
                    {step.step}단계: {step.approverId}번 결재자
                    <br />
                    <strong>{getStatusText(step.status)}</strong>
                  </div>
                ))}
              </div>
              <div className="approval-actions">
                <button
                  className="btn btn-approve"
                  onClick={() => handleProcess(item.requestId, 'approved')}
                >
                  ✓ 승인
                </button>
                <button
                  className="btn btn-reject"
                  onClick={() => handleProcess(item.requestId, 'rejected')}
                >
                  ✗ 반려
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

export default ApprovalQueue;
