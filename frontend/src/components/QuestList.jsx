import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';
import './QuestList.css';

function QuestList({ user }) {
  const [quests, setQuests] = useState([]);
  const [myQuests, setMyQuests] = useState([]);
  const [activeTab, setActiveTab] = useState('available');

  useEffect(() => {
    fetchQuests();
    fetchMyQuests();
  }, []);

  const fetchQuests = async () => {
    try {
      const res = await axios.get(`${API_ENDPOINTS.EMPLOYEE}/quests/available?employeeId=${user.employeeId}`);
      setQuests(res.data);
    } catch (err) {
      console.error('퀘스트 조회 실패:', err);
      setQuests([]);
    }
  };

  const fetchMyQuests = async () => {
    try {
      const res = await axios.get(`${API_ENDPOINTS.EMPLOYEE}/quests/my-quests?employeeId=${user.employeeId}`);
      setMyQuests(res.data);
    } catch (err) {
      console.error('내 퀘스트 조회 실패:', err);
      setMyQuests([]);
    }
  };

  const handleAccept = async (questId) => {
    try {
      await axios.post(`${API_ENDPOINTS.EMPLOYEE}/quests/${questId}/accept`, { employeeId: user.employeeId });
      alert('퀘스트를 수락했습니다!');
      fetchQuests();
      fetchMyQuests();
    } catch (err) {
      alert(err.response?.data?.message || '수락 실패');
    }
  };

  const handleComplete = async (questId) => {
    try {
      await axios.post(`${API_ENDPOINTS.EMPLOYEE}/quests/${questId}/complete`, { employeeId: user.employeeId });
      alert('완료 보고했습니다! 부장 승인을 기다려주세요.');
      fetchMyQuests();
    } catch (err) {
      alert(err.response?.data?.message || '완료 실패');
    }
  };

  const handleClaim = async (questId) => {
    try {
      await axios.post(`${API_ENDPOINTS.EMPLOYEE}/quests/${questId}/claim`, { employeeId: user.employeeId });
      alert('🎉 보상을 받았습니다! 연차가 추가되었습니다.');
      fetchMyQuests();
    } catch (err) {
      alert(err.response?.data?.message || '보상 수령 실패');
    }
  };

  const getStatusBadge = (status) => {
    const badges = {
      IN_PROGRESS: { text: '진행 중', color: '#3498db' },
      WAITING_APPROVAL: { text: '승인 대기', color: '#f39c12' },
      APPROVED: { text: '승인됨', color: '#2ecc71' },
      REJECTED: { text: '반려됨', color: '#e74c3c' },
      CLAIMED: { text: '완료', color: '#95a5a6' },
    };
    const badge = badges[status] || { text: status, color: '#95a5a6' };
    return <span className="status-badge" style={{ background: badge.color }}>{badge.text}</span>;
  };

  return (
    <div className="quest-container">
      <div className="quest-tabs">
        <button
          className={activeTab === 'available' ? 'active' : ''}
          onClick={() => setActiveTab('available')}
        >
          🎯 가능한 퀘스트
        </button>
        <button
          className={activeTab === 'my' ? 'active' : ''}
          onClick={() => setActiveTab('my')}
        >
          📋 내 퀘스트
        </button>
      </div>

      <AnimatePresence mode="wait">
        {activeTab === 'available' ? (
          <motion.div
            key="available"
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 20 }}
            className="quest-list"
          >
            {quests.length === 0 ? (
              <p className="empty">현재 가능한 퀘스트가 없습니다</p>
            ) : (
              quests.map((quest) => (
                <motion.div
                  key={quest.id}
                  className="quest-card"
                  whileHover={{ scale: 1.02 }}
                  transition={{ duration: 0.2 }}
                >
                  <h3>{quest.title}</h3>
                  <p>{quest.description}</p>
                  <div className="quest-footer">
                    <span className="reward">🎁 연차 {quest.rewardDays}일</span>
                    <button onClick={() => handleAccept(quest.id)}>수락하기</button>
                  </div>
                </motion.div>
              ))
            )}
          </motion.div>
        ) : (
          <motion.div
            key="my"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="quest-list"
          >
            {myQuests.length === 0 ? (
              <p className="empty">진행 중인 퀘스트가 없습니다</p>
            ) : (
              myQuests.map((quest) => (
                <motion.div
                  key={quest.id}
                  className="quest-card"
                  whileHover={{ scale: 1.02 }}
                  transition={{ duration: 0.2 }}
                >
                  <div className="quest-header">
                    <h3>{quest.title}</h3>
                    {getStatusBadge(quest.status)}
                  </div>
                  <p>{quest.description}</p>
                  <div className="quest-footer">
                    <span className="reward">🎁 연차 {quest.rewardDays}일</span>
                    {quest.status === 'IN_PROGRESS' && (
                      <button onClick={() => handleComplete(quest.id)}>완료 보고</button>
                    )}
                    {quest.status === 'APPROVED' && (
                      <button className="claim-btn" onClick={() => handleClaim(quest.id)}>
                        보상 받기
                      </button>
                    )}
                  </div>
                </motion.div>
              ))
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default QuestList;
