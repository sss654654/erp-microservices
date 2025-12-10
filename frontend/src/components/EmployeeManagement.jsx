import { useState, useEffect } from 'react';
import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';
import './EmployeeManagement.css';

function EmployeeManagement({ user }) {
  const [employees, setEmployees] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchEmployees();
  }, []);

  const fetchEmployees = async () => {
    try {
      const res = await axios.get(API_ENDPOINTS.EMPLOYEE);
      // 자기 부서 직원만 필터링 (중복 제거)
      const filtered = res.data
        .filter(emp => emp.department === user.department)
        .reduce((acc, emp) => {
          // ID 기준으로 중복 제거 (최신 것만 유지)
          const existing = acc.find(e => e.name === emp.name && e.position === emp.position);
          if (!existing) {
            acc.push(emp);
          } else if (emp.id > existing.id) {
            const index = acc.indexOf(existing);
            acc[index] = emp;
          }
          return acc;
        }, []);
      setEmployees(filtered);
    } catch (err) {
      console.error('직원 목록 조회 실패:', err);
      setEmployees([]);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div className="employee-management"><p>로딩 중...</p></div>;

  return (
    <div className="employee-management">
      <h2>{user.department} 직원 관리</h2>
      {employees.length === 0 ? (
        <p className="empty">직원이 없습니다</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>이름</th>
              <th>부서</th>
              <th>직급</th>
              <th>이메일</th>
            </tr>
          </thead>
          <tbody>
            {employees.map((emp) => (
              <tr key={emp.id}>
                <td>{emp.id}</td>
                <td>{emp.name}</td>
                <td>{emp.department}</td>
                <td>{emp.position === 'MANAGER' ? '부장' : '사원'}</td>
                <td>{emp.email}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

export default EmployeeManagement;
