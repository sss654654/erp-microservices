import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';
import './ManagerQuests.css';

function ManagerQuests({ user }) {
  const [quests, setQuests] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    rewardDays: 0.5,
  });

  useEffect(() => {
    fetchMyQuests();
  }, []);

  const fetchMyQuests = async () => {
    try {
      const res = await axios.get(`${API_ENDPOINTS.EMPLOYEE}/quests/my-created?managerId=${user.employeeId}`);
      setQuests(res.data);
    } catch (err) {
      console.error('퀘스트 조회 실패:', err);
      setQuests([]);
    }
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    try {
      await axios.post(`${API_ENDPOINTS.EMPLOYEE}/quests`, {
        ...formData,
        department: user.department,
        createdBy: user.employeeId,
      });
      alert('퀘스트를 생성했습니다!');
      setShowForm(false);
      setFormData({ title: '', description: '', rewardDays: 0.5 });
      fetchMyQuests();
    } catch (err) {
      alert(err.response?.data?.message || '생성 실패');
    }
  };

  const handleApprove = async (questId) => {
    try {
      await axios.put(`${API_ENDPOINTS.EMPLOYEE}/quests/${questId}/approve`, { managerId: user.employeeId });
      alert('승인했습니다!');
      fetchMyQuests();
    } catch (err) {
      alert(err.response?.data?.message || '승인 실패');
    }
  };

  const handleReject = async (questId) => {
    const reason = prompt('반려 사유를 입력하세요:');
    if (!reason) return;
    try {
      await axios.put(`${API_ENDPOINTS.EMPLOYEE}/quests/${questId}/reject`, {
        managerId: user.employeeId,
        reason,
      });
      alert('반려했습니다.');
      fetchMyQuests();
    } catch (err) {
      alert(err.response?.data?.message || '반려 실패');
    }
  };

  const handleDelete = async (questId) => {
    if (!confirm('정말 삭제하시겠습니까?')) return;
    try {
      await axios.delete(`${API_ENDPOINTS.EMPLOYEE}/quests/${questId}`);
      alert('삭제했습니다.');
      fetchMyQuests();
    } catch (err) {
      alert(err.response?.data?.message || '삭제 실패');
    }
  };

  return (
    <div className="manager-quests">
      <div className="header">
        <h2>🎯 퀘스트 관리</h2>
        <button className="create-btn" onClick={() => setShowForm(!showForm)}>
          {showForm ? '취소' : '+ 새 퀘스트'}
        </button>
      </div>

      {showForm && (
        <motion.form
          className="quest-form"
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          exit={{ opacity: 0, height: 0 }}
          onSubmit={handleCreate}
        >
          <input
            type="text"
            placeholder="퀘스트 제목"
            value={formData.title}
            onChange={(e) => setFormData({ ...formData, title: e.target.value })}
            required
          />
          <textarea
            placeholder="퀘스트 설명"
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            required
          />
          <div className="reward-input">
            <label>보상 연차:</label>
            <input
              type="number"
              step="0.5"
              min="0.5"
              max="5"
              value={formData.rewardDays}
              onChange={(e) => setFormData({ ...formData, rewardDays: parseFloat(e.target.value) })}
              required
            />
            <span>일</span>
          </div>
          <button type="submit">생성하기</button>
        </motion.form>
      )}

      <div className="quest-list">
        {quests.length === 0 ? (
          <p className="empty">생성한 퀘스트가 없습니다</p>
        ) : (
          quests.map((quest) => (
            <motion.div
              key={quest.id}
              className="manager-quest-card"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
            >
              <div className="quest-info">
                <h3>{quest.title}</h3>
                <p>{quest.description}</p>
                <span className="reward">🎁 보상: {quest.rewardDays}일</span>
              </div>
              {quest.progressList && quest.progressList.length > 0 && (
                <div className="progress-list">
                  <h4>진행 현황:</h4>
                  {quest.progressList.map((progress) => (
                    <div key={progress.id} className="progress-item">
                      <span>{progress.employeeName}</span>
                      <span className={`status ${progress.status.toLowerCase()}`}>
                        {progress.status}
                      </span>
                      {progress.status === 'WAITING_APPROVAL' && (
                        <div className="actions">
                          <button className="approve" onClick={() => handleApprove(quest.id)}>
                            승인
                          </button>
                          <button className="reject" onClick={() => handleReject(quest.id)}>
                            반려
                          </button>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
              <button className="delete-btn" onClick={() => handleDelete(quest.id)}>
                삭제
              </button>
            </motion.div>
          ))
        )}
      </div>
    </div>
  );
}

export default ManagerQuests;
