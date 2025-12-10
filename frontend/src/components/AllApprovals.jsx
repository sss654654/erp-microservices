import { useState, useEffect } from 'react';
import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';
import './AllApprovals.css';

function AllApprovals({ refresh }) {
  const [approvals, setApprovals] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchApprovals();
  }, [refresh]);

  const fetchApprovals = async () => {
    try {
      const res = await axios.get(API_ENDPOINTS.APPROVAL_REQUEST);
      setApprovals(res.data);
    } catch (err) {
      console.error('결재 목록 조회 실패:', err);
      setApprovals([]);
    } finally {
      setLoading(false);
    }
  };

  const getStatusText = (status) => {
    const statusMap = {
      PENDING: '⏳ 대기',
      APPROVED: '✓ 승인',
      REJECTED: '✗ 반려',
    };
    return statusMap[status] || status;
  };

  if (loading) return <div className="all-approvals"><p>로딩 중...</p></div>;

  return (
    <div className="all-approvals">
      <h2>📊 전체 결재 내역</h2>
      {approvals.length === 0 ? (
        <p className="empty">결재 내역이 없습니다</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>유형</th>
              <th>내용</th>
              <th>요청자</th>
              <th>연차일수</th>
              <th>상태</th>
            </tr>
          </thead>
          <tbody>
            {approvals.map((approval) => (
              <tr key={approval.id}>
                <td>{approval.id}</td>
                <td>
                  <span className={`type-badge ${approval.type?.toLowerCase()}`}>
                    {approval.title}
                  </span>
                </td>
                <td className="content-cell">{approval.content}</td>
                <td>{approval.requesterId}</td>
                <td>
                  {approval.type === 'ANNUAL_LEAVE' && approval.leaveDays 
                    ? `${approval.leaveDays}일` 
                    : '-'}
                </td>
                <td>
                  <span className={`status ${approval.status?.toLowerCase()}`}>
                    {getStatusText(approval.status)}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

export default AllApprovals;

