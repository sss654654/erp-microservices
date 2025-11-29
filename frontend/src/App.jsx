import { useState } from 'react';
import EmployeeManagement from './components/EmployeeManagement';
import CreateApproval from './components/CreateApproval';
import ApprovalQueue from './components/ApprovalQueue';
import AllApprovals from './components/AllApprovals';
import './App.css';

function App() {
  const [approverId, setApproverId] = useState(2);
  const [refreshKey, setRefreshKey] = useState(0);

  const handleSuccess = () => {
    setRefreshKey((prev) => prev + 1);
  };

  return (
    <div className="app">
      <header className="header">
        <h1>📋 ERP 결재 시스템</h1>
        <div className="user-info">
          <label>결재자 ID:</label>
          <input
            type="number"
            value={approverId}
            onChange={(e) => setApproverId(parseInt(e.target.value) || 1)}
            min="1"
          />
        </div>
      </header>

      <main className="main-content">
        <EmployeeManagement />
        <CreateApproval onSuccess={handleSuccess} />
        <ApprovalQueue approverId={approverId} refresh={refreshKey} />
        <AllApprovals refresh={refreshKey} />
      </main>
    </div>
  );
}

export default App;
