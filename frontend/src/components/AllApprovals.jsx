import { useState, useEffect } from 'react';
import { approvalService } from '../services/approvalService';

function AllApprovals({ refresh }) {
  const [approvals, setApprovals] = useState([]);
  const [loading, setLoading] = useState(false);

  const loadApprovals = async () => {
    setLoading(true);
    try {
      const response = await approvalService.getApprovals();
      setApprovals(response.data);
    } catch (error) {
      console.error('Error loading approvals:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadApprovals();
  }, [refresh]);

  const getStatusText = (status) => {
    const map = { pending: '대기중', approved: '승인', rejected: '반려' };
    return map[status] || status;
  };

  const getFinalStatusText = (status) => {
    const map = {
      in_progress: '진행중',
      approved: '승인완료',
      rejected: '반려됨',
    };
    return map[status] || status;
  };

  const formatDate = (dateString) => {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleString('ko-KR', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <section className="section">
      <h2>📊 전체 결재 현황</h2>
      <button onClick={loadApprovals} className="btn btn-secondary">
        새로고침
      </button>

      {loading ? (
        <div className="loading">로딩 중...</div>
      ) : approvals.length === 0 ? (
        <div className="empty-state">결재 요청이 없습니다</div>
      ) : (
        <div className="approval-list">
          {approvals.map((item) => (
            <div key={item.id} className="approval-card">
              <div className="approval-header">
                <span className="approval-title">{item.title}</span>
                <div>
                  <span className="approval-id">ID: {item.requestId}</span>
                  <span className={`status-badge status-${item.finalStatus.replace('_', '-')}`}>
                    {getFinalStatusText(item.finalStatus)}
                  </span>
                </div>
              </div>
              <div className="approval-content">{item.content}</div>
              <div className="approval-steps">
                {item.steps.map((step) => (
                  <div key={step.step} className={`step step-${step.status}`}>
                    {step.step}단계: {step.approverId}번 결재자
                    <br />
                    <strong>{getStatusText(step.status)}</strong>
                    {step.updatedAt && (
                      <>
                        <br />
                        <small>{formatDate(step.updatedAt)}</small>
                      </>
                    )}
                  </div>
                ))}
              </div>
              <small style={{ color: '#999' }}>
                생성: {formatDate(item.createdAt)}
                {item.updatedAt && ` | 수정: ${formatDate(item.updatedAt)}`}
              </small>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

export default AllApprovals;
