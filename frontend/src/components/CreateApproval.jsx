import { useState } from 'react';
import { approvalService } from '../services/approvalService';

function CreateApproval({ onSuccess }) {
  const [formData, setFormData] = useState({
    requesterId: '',
    title: '',
    content: '',
    approver1: '',
    approver2: '',
  });

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    const data = {
      requesterId: parseInt(formData.requesterId),
      title: formData.title,
      content: formData.content,
      steps: [
        { step: 1, approverId: parseInt(formData.approver1) },
        { step: 2, approverId: parseInt(formData.approver2) },
      ],
    };

    try {
      const response = await approvalService.createApproval(data);
      alert(`결재 요청이 생성되었습니다! (ID: ${response.data.requestId})`);
      setFormData({
        requesterId: '',
        title: '',
        content: '',
        approver1: '',
        approver2: '',
      });
      onSuccess();
    } catch (error) {
      alert('결재 요청 생성 실패: ' + error.message);
    }
  };

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  return (
    <section className="section">
      <h2>📝 결재 요청 생성</h2>
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label>요청자 ID</label>
          <input
            type="number"
            name="requesterId"
            value={formData.requesterId}
            onChange={handleChange}
            required
            min="1"
          />
        </div>
        <div className="form-group">
          <label>제목</label>
          <input
            type="text"
            name="title"
            value={formData.title}
            onChange={handleChange}
            required
          />
        </div>
        <div className="form-group">
          <label>내용</label>
          <textarea
            name="content"
            value={formData.content}
            onChange={handleChange}
            required
            rows="3"
          />
        </div>
        <div className="form-group">
          <label>1단계 결재자 ID</label>
          <input
            type="number"
            name="approver1"
            value={formData.approver1}
            onChange={handleChange}
            required
            min="1"
          />
        </div>
        <div className="form-group">
          <label>2단계 결재자 ID</label>
          <input
            type="number"
            name="approver2"
            value={formData.approver2}
            onChange={handleChange}
            required
            min="1"
          />
        </div>
        <button type="submit" className="btn btn-primary">
          결재 요청 생성
        </button>
      </form>
    </section>
  );
}

export default CreateApproval;
