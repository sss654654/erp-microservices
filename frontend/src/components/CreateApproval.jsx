import { useState, useEffect } from 'react';
import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';
import './CreateApproval.css';

function CreateApproval({ onSuccess, user }) {
  const [formData, setFormData] = useState({
    type: 'LEAVE',
    content: '',
    approverId: '',
  });
  const [managers, setManagers] = useState([]);
  const [loading, setLoading] = useState(false);

  const types = [
    { value: 'LEAVE', label: '휴가' },
    { value: 'ANNUAL_LEAVE', label: '연차' },
    { value: 'EXPENSE', label: '지출' },
    { value: 'PROJECT', label: '프로젝트' },
  ];

  useEffect(() => {
    fetchManagers();
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

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await axios.post(API_ENDPOINTS.APPROVAL_REQUEST, {
        requesterId: user.employeeId,
        title: formData.type,
        content: formData.content,
        steps: [{ step: 1, approverId: parseInt(formData.approverId) }],
      });
      alert('결재 요청이 생성되었습니다');
      setFormData({ type: 'LEAVE', content: '', approverId: '' });
      onSuccess();
    } catch (err) {
      alert(err.response?.data?.message || '생성 실패');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="create-approval">
      <h2>결재 요청</h2>
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
