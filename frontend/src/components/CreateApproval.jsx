import { useState, useEffect } from 'react';
import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';
import './CreateApproval.css';

function CreateApproval({ onSuccess, user }) {
  const [formData, setFormData] = useState({
    type: 'EXPENSE',
    content: '',
    approverId: '',
    leaveDays: 1,
  });
  const [managers, setManagers] = useState([]);
  const [leaveBalance, setLeaveBalance] = useState(0);
  const [loading, setLoading] = useState(false);

  const types = [
    { value: 'ANNUAL_LEAVE', label: '연차', needsDays: true },
    { value: 'EXPENSE', label: '지출', needsDays: false },
    { value: 'PROJECT', label: '프로젝트', needsDays: false },
  ];

  useEffect(() => {
    fetchManagers();
    fetchLeaveBalance();
  }, []);

  const fetchManagers = async () => {
    try {
      const res = await axios.get(API_ENDPOINTS.EMPLOYEE);
      const managerList = res.data.filter(emp => emp.position === 'MANAGER');
      setManagers(managerList);
    } catch (err) {
      console.error('부장 목록 조회 실패:', err);
    }
  };

  const fetchLeaveBalance = async () => {
    try {
      const res = await axios.get(`${API_ENDPOINTS.EMPLOYEE}/${user.employeeId}`);
      setLeaveBalance(res.data.annualLeaveBalance || 0);
    } catch (err) {
      console.error('연차 조회 실패:', err);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (formData.type === 'ANNUAL_LEAVE' && formData.leaveDays > leaveBalance) {
      alert(`보유 연차(${leaveBalance}일)가 부족합니다.`);
      return;
    }

    setLoading(true);
    try {
      const payload = {
        requesterId: user.employeeId,
        title: `${types.find(t => t.value === formData.type)?.label} 신청`,
        content: formData.content,
        type: formData.type,
        steps: [{ step: 1, approverId: parseInt(formData.approverId) }],
      };

      if (formData.type === 'ANNUAL_LEAVE') {
        payload.leaveDays = formData.leaveDays;
      }

      await axios.post(API_ENDPOINTS.APPROVAL_REQUEST, payload);
      alert('결재 요청이 생성되었습니다');
      setFormData({ type: 'EXPENSE', content: '', approverId: '', leaveDays: 1 });
      fetchLeaveBalance();
      onSuccess();
    } catch (err) {
      alert(err.response?.data?.message || '생성 실패');
    } finally {
      setLoading(false);
    }
  };

  const currentType = types.find(t => t.value === formData.type);

  return (
    <div className="create-approval">
      <h2>결재 요청</h2>
      <div className="leave-info">
        <span>보유 연차: <strong>{leaveBalance}일</strong></span>
      </div>
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label>유형</label>
          <div className="type-selector">
            {types.map((type) => (
              <button
                key={type.value}
                type="button"
                className={formData.type === type.value ? 'active' : ''}
                onClick={() => setFormData({ ...formData, type: type.value })}
              >
                {type.label}
              </button>
            ))}
          </div>
        </div>

        {currentType?.needsDays && (
          <div className="form-group">
            <label>연차 일수</label>
            <input
              type="number"
              min="0.5"
              step="0.5"
              max={leaveBalance}
              value={formData.leaveDays}
              onChange={(e) => setFormData({ ...formData, leaveDays: parseFloat(e.target.value) })}
              required
            />
            <small>최대 {leaveBalance}일까지 신청 가능</small>
          </div>
        )}

        <div className="form-group">
          <label>내용</label>
          <textarea
            value={formData.content}
            onChange={(e) => setFormData({ ...formData, content: e.target.value })}
            placeholder="결재 내용을 입력하세요"
            required
          />
        </div>

        <div className="form-group">
          <label>결재자</label>
          <select
            value={formData.approverId}
            onChange={(e) => setFormData({ ...formData, approverId: e.target.value })}
            required
          >
            <option value="">결재자를 선택하세요</option>
            {managers.map((manager) => (
              <option key={manager.id} value={manager.id}>
                {manager.name} ({manager.department})
              </option>
            ))}
          </select>
        </div>

        <button type="submit" disabled={loading}>
          {loading ? '처리 중...' : '요청하기'}
        </button>
      </form>
    </div>
  );
}

export default CreateApproval;
