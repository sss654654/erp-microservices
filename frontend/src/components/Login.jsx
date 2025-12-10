import { useState } from 'react';
import { motion } from 'framer-motion';
import { authService } from '../services/authService';
import './Login.css';

function Login({ onLogin }) {
  const [isSignUp, setIsSignUp] = useState(false);
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    name: '',
    position: 'STAFF',
    department: 'DEVELOPMENT',
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (isSignUp) {
        await authService.signUp(
          formData.email,
          formData.password,
          formData.name,
          formData.position,
          formData.department
        );
        alert('회원가입 성공! 이메일을 확인해주세요.');
        setIsSignUp(false);
      } else {
        const result = await authService.signIn(formData.email, formData.password);
        onLogin(result);
      }
    } catch (err) {
      setError(err.message || '오류가 발생했습니다');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container">
      <motion.div
        className="login-box"
        initial={{ opacity: 0, y: -50 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <h1>🏢 ERP 시스템</h1>
        <h2>{isSignUp ? '회원가입' : '로그인'}</h2>

        <form onSubmit={handleSubmit}>
          <input
            type="email"
            placeholder="이메일"
            value={formData.email}
            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
            required
          />
          <input
            type="password"
            placeholder="비밀번호"
            value={formData.password}
            onChange={(e) => setFormData({ ...formData, password: e.target.value })}
            required
          />

          {isSignUp && (
            <>
              <input
                type="text"
                placeholder="이름"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                required
              />
              <select
                value={formData.position}
                onChange={(e) => setFormData({ ...formData, position: e.target.value })}
              >
                <option value="STAFF">사원</option>
                <option value="MANAGER">부장</option>
              </select>
              <select
                value={formData.department}
                onChange={(e) => setFormData({ ...formData, department: e.target.value })}
              >
                <option value="DEVELOPMENT">개발팀</option>
                <option value="SALES">영업팀</option>
                <option value="HR">인사팀</option>
                <option value="FINANCE">재무팀</option>
              </select>
            </>
          )}

          {error && <div className="error">{error}</div>}

          <button type="submit" disabled={loading}>
            {loading ? '처리 중...' : isSignUp ? '가입하기' : '로그인'}
          </button>
        </form>

        <button className="toggle-btn" onClick={() => setIsSignUp(!isSignUp)}>
          {isSignUp ? '이미 계정이 있으신가요? 로그인' : '계정이 없으신가요? 회원가입'}
        </button>
      </motion.div>
    </div>
  );
}

export default Login;
