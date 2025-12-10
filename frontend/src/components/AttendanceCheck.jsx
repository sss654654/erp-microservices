import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';
import './AttendanceCheck.css';

function AttendanceCheck({ user }) {
  const [progress, setProgress] = useState({ attendanceCount: 0, progress: 0, nextRewardAt: 30 });
  const [leaveBalance, setLeaveBalance] = useState(0);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchProgress();
    fetchLeaveBalance();
  }, []);

  const fetchProgress = async () => {
    try {
      const res = await axios.get(`${API_ENDPOINTS.ATTENDANCE}/progress/${user.employeeId}`);
      setProgress(res.data);
    } catch (err) {
      console.error('진행률 조회 실패:', err);
      setProgress({ attendanceCount: 0, progress: 0, nextRewardAt: 30 });
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

  const handleCheckIn = async () => {
    setLoading(true);
    try {
      const res = await axios.post(`${API_ENDPOINTS.ATTENDANCE}/check-in/${user.employeeId}`);
      setProgress({
        attendanceCount: res.data.attendanceCount,
        progress: (res.data.attendanceCount % 30) / 30 * 100,
        nextRewardAt: 30 - (res.data.attendanceCount % 30),
      });
      if (res.data.rewardEarned) {
        alert('30일 출석 달성! 연차 1일이 지급되었습니다!');
        fetchLeaveBalance();
      }
    } catch (err) {
      alert(err.response?.data?.message || '출근 처리 실패');
    } finally {
      setLoading(false);
    }
  };

  return (
    <motion.div
      className="attendance-card"
      initial={{ opacity: 0, scale: 0.9 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.3 }}
    >
      <h2>출석 체크</h2>
      <div className="leave-info">
        <span>보유 연차</span>
        <span className="leave-count">{leaveBalance}일</span>
      </div>
      <div className="progress-container">
        <div className="progress-text">
          <span className="count">{progress.attendanceCount % 30} / 30일</span>
          <span className="reward">다음 보상까지 {progress.nextRewardAt}일</span>
        </div>
        <div className="progress-bar">
          <motion.div
            className="progress-fill"
            initial={{ width: 0 }}
            animate={{ width: `${progress.progress}%` }}
            transition={{ duration: 0.5 }}
          />
        </div>
      </div>
      <button onClick={handleCheckIn} disabled={loading} className="check-in-btn">
        {loading ? '처리 중...' : '출근하기'}
      </button>
      <p className="info">30일 출석 시 연차 1일 자동 지급</p>
    </motion.div>
  );
}

export default AttendanceCheck;
