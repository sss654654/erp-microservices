import { useState, useEffect } from 'react';
import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';
import './ApprovalQueue.css';

function ApprovalQueue({ approverId, refresh }) {
  const [queue, setQueue] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (approverId) {
      fetchQueue();
    }
  }, [approverId, refresh]);

  const fetchQueue = async () => {
    try {
      const res = await axios.get(`${API_ENDPOINTS.APPROVAL_REQUEST}/pending/${approverId}`);
      setQueue(res.data);
    } catch (err) {
      console.error('대기 목록 조회 실패:', err);
      setQueue([]);
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (requestId) => {
    try {
      await axios.put(`${API_ENDPOINTS.APPROVAL_REQUEST}/${requestId}/approve`, {
        approverId: approverId,
      });
      alert('승인되었습니다');
      fetchQueue();
    } catch (err) {
      alert(err.response?.data?.message || '승인 실패');
    }
  };

  const handleReject = async (requestId) => {
    const reason = prompt('반려 사유를 입력하세요:');
    if (!reason) return;
    
    try {
      await axios.put(`${API_ENDPOINTS.APPROVAL_REQUEST}/${requestId}/reject`, {
        approverId: approverId,
        reason: reason,
      });
      alert('반려되었습니다');
      fetchQueue();
    } catch (err) {
      alert(err.response?.data?.message || '반려 실패');
    }
  };

  if (loading) return <div className="approval-queue"><p>로딩 중...</p></div>;

  return (
    <div className="approval-queue">
      <h2>📋 결재 대기 ({queue.length})</h2>
      {queue.length === 0 ? (
        <p className="empty">대기 중인 결재가 없습니다</p>
      ) : (
        <div className="queue-list">
          {queue.map((item) => (
            <div key={item.id} className="queue-item">
              <div className="item-header">
                <span className="type">{item.title}</span>
                <span className="requester">요청자 ID: {item.requesterId}</span>
              </div>
              <p className="content">{item.content}</p>
              {item.type === 'ANNUAL_LEAVE' && item.leaveDays && (
                <p className="leave-days">📅 연차 일수: {item.leaveDays}일</p>
              )}
              <div className="actions">
                <button className="approve" onClick={() => handleApprove(item.id)}>
                  ✓ 승인
                </button>
                <button className="reject" onClick={() => handleReject(item.id)}>
                  ✗ 반려
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default ApprovalQueue;

