import { useState, useEffect } from 'react';
import { employeeService } from '../services/employeeService';

function EmployeeManagement() {
  const [employees, setEmployees] = useState([]);
  const [loading, setLoading] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    department: '',
    position: '',
  });

  const loadEmployees = async () => {
    setLoading(true);
    try {
      const response = await employeeService.getEmployees();
      setEmployees(response.data);
    } catch (error) {
      console.error('Error loading employees:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadEmployees();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await employeeService.updateEmployee(editingId, formData);
        alert('직원 정보가 수정되었습니다!');
      } else {
        await employeeService.createEmployee(formData);
        alert('직원이 생성되었습니다!');
      }
      resetForm();
      loadEmployees();
    } catch (error) {
      alert('작업 실패: ' + error.message);
    }
  };

  const handleEdit = (employee) => {
    setEditingId(employee.id);
    setFormData({
      name: employee.name,
      department: employee.department,
      position: employee.position,
    });
    setShowForm(true);
  };

  const handleDelete = async (id) => {
    if (!confirm('정말 삭제하시겠습니까?')) return;
    try {
      await employeeService.deleteEmployee(id);
      alert('직원이 삭제되었습니다!');
      loadEmployees();
    } catch (error) {
      alert('삭제 실패: ' + error.message);
    }
  };

  const resetForm = () => {
    setFormData({ name: '', department: '', position: '' });
    setEditingId(null);
    setShowForm(false);
  };

  return (
    <section className="section">
      <h2>👥 직원 관리</h2>
      
      <button 
        onClick={() => setShowForm(!showForm)} 
        className="btn btn-secondary"
      >
        {showForm ? '폼 닫기' : '직원 추가'}
      </button>

      {showForm && (
        <form onSubmit={handleSubmit} style={{ marginTop: '20px', marginBottom: '20px' }}>
          <div className="form-group">
            <label>이름</label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              required
            />
          </div>
          <div className="form-group">
            <label>부서</label>
            <input
              type="text"
              value={formData.department}
              onChange={(e) => setFormData({ ...formData, department: e.target.value })}
              required
            />
          </div>
          <div className="form-group">
            <label>직급</label>
            <input
              type="text"
              value={formData.position}
              onChange={(e) => setFormData({ ...formData, position: e.target.value })}
              required
            />
          </div>
          <div style={{ display: 'flex', gap: '10px' }}>
            <button type="submit" className="btn btn-primary">
              {editingId ? '수정' : '생성'}
            </button>
            <button type="button" onClick={resetForm} className="btn btn-secondary">
              취소
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <div className="loading">로딩 중...</div>
      ) : (
        <div className="employee-table">
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>이름</th>
                <th>부서</th>
                <th>직급</th>
                <th>작업</th>
              </tr>
            </thead>
            <tbody>
              {employees.map((emp) => (
                <tr key={emp.id}>
                  <td>{emp.id}</td>
                  <td>{emp.name}</td>
                  <td>{emp.department}</td>
                  <td>{emp.position}</td>
                  <td>
                    <button 
                      onClick={() => handleEdit(emp)} 
                      className="btn-small btn-edit"
                    >
                      수정
                    </button>
                    <button 
                      onClick={() => handleDelete(emp.id)} 
                      className="btn-small btn-delete"
                    >
                      삭제
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

export default EmployeeManagement;
