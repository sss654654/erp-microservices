import axios from 'axios';

const employeeAPI = axios.create({
  baseURL: 'http://localhost:8081',
});

export const employeeService = {
  getEmployees: () => employeeAPI.get('/employees'),
  createEmployee: (data) => employeeAPI.post('/employees', data),
  updateEmployee: (id, data) => employeeAPI.put(`/employees/${id}`, data),
  deleteEmployee: (id) => employeeAPI.delete(`/employees/${id}`),
  getEmployee: (id) => employeeAPI.get(`/employees/${id}`),
};
