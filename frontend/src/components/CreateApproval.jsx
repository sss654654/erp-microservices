import { useState } from 'react';
import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';
import './CreateApproval.css';

function CreateApproval({ onSuccess, user }) {
  const [formData, setFormData] = useState({
    type: 'LEAVE',
    content: '',
    steps: [{ step: 1, approverId: '' }],
  });
  const [loading, setLoading] = useState(false);

  const types = [
    { value: 'LEAVE', label: '휴가' },
    { value: 'ANNUAL_LEAVE', label: '연차' },
    { value: 'EXPENSE', label: '지출' },
    { value: 'PROJECT', label: '프로젝트' },
  ];

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await axios.post(API_ENDPOINTS.APPROVAL_REQUEST, {
        requesterId: user.employeeId,
        title: formData.type,
        content: formData.content,
        steps: formData.steps,
      });
      alert('결재 요청이 생성되었습니다');
      setFormData({ type: 'LEAVE', content: '', steps: [{ step: 1, approverId: '' }] });
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
          <label>결재자 ID</label>
          <input
            type="number"
            value={formData.steps[0].approverId}
            onChange={(e) =>
              setFormData({
                ...formData,
                steps: [{ step: 1, approverId: parseInt(e.target.value) }],
              })
            }
            placeholder="결재자 ID"
            required
          />
        </div>

        <button type="submit" disabled={loading}>
          {loading ? '처리 중...' : '요청하기'}
        </button>
      </form>
    </div>
  );
}

export default CreateApproval;
