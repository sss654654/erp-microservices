import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { authService } from './services/authService';
import Login from './components/Login';
import AttendanceCheck from './components/AttendanceCheck';
import QuestList from './components/QuestList';
import ManagerQuests from './components/ManagerQuests';
import EmployeeManagement from './components/EmployeeManagement';
import CreateApproval from './components/CreateApproval';
import ApprovalQueue from './components/ApprovalQueue';
import AllApprovals from './components/AllApprovals';
import Notifications from './components/Notifications';
import './App.css';

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    checkAuth();
  }, []);

  const checkAuth = async () => {
    try {
      const result = await authService.getCurrentUser();
      setUser(result.user);
    } catch (err) {
      console.log('Not logged in');
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = (result) => {
    setUser(result.user);
  };

  const handleLogout = () => {
    authService.signOut();
    setUser(null);
  };

  const handleSuccess = () => {
    setRefreshKey((prev) => prev + 1);
  };

  if (loading) {
    return (
      <div className="loading-screen">
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
          className="spinner"
        >
          ⚙️
        </motion.div>
      </div>
    );
  }

  if (!user) {
    return <Login onLogin={handleLogin} />;
  }

  const isManager = user.position === 'MANAGER';

  return (
    <div className="app">
      <header className="header">
        <h1>🏢 ERP 시스템</h1>
        <div className="user-info">
          <span className="user-name">{user.name}</span>
          <span className="user-position">{user.position === 'MANAGER' ? '부장' : '사원'}</span>
          <span className="user-department">{user.department}</span>
          <button onClick={handleLogout} className="logout-btn">
            로그아웃
          </button>
        </div>
      </header>

      <nav className="nav-tabs">
        <button
          className={activeTab === 'dashboard' ? 'active' : ''}
          onClick={() => setActiveTab('dashboard')}
        >
          📊 대시보드
        </button>
        <button
          className={activeTab === 'approval' ? 'active' : ''}
          onClick={() => setActiveTab('approval')}
        >
          📋 결재
        </button>
        {isManager && (
          <button
            className={activeTab === 'manage' ? 'active' : ''}
            onClick={() => setActiveTab('manage')}
          >
            👥 관리
          </button>
        )}
      </nav>

      <main className="main-content">
        <Notifications />

        <AnimatePresence mode="wait">
          {activeTab === 'dashboard' && (
            <motion.div
              key="dashboard"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              className="dashboard"
            >
              <div className="grid">
                <AttendanceCheck user={user} />
                {isManager ? <ManagerQuests user={user} /> : <QuestList user={user} />}
              </div>
            </motion.div>
          )}

          {activeTab === 'approval' && (
            <motion.div
              key="approval"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              className="approval-section"
            >
              <CreateApproval onSuccess={handleSuccess} />
              <ApprovalQueue approverId={user.employeeId} refresh={refreshKey} />
              <AllApprovals refresh={refreshKey} />
            </motion.div>
          )}

          {activeTab === 'manage' && isManager && (
            <motion.div
              key="manage"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
            >
              <EmployeeManagement />
            </motion.div>
          )}
        </AnimatePresence>
      </main>
    </div>
  );
}

export default App;
