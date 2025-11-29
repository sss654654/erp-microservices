import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';

const employeeAPI = axios.create({
  baseURL: API_ENDPOINTS.EMPLOYEE,
});

export const employeeService = {
  getEmployees: () => employeeAPI.get('/employees'),
  createEmployee: (data) => employeeAPI.post('/employees', data),
  updateEmployee: (id, data) => employeeAPI.put(`/employees/${id}`, data),
  deleteEmployee: (id) => employeeAPI.delete(`/employees/${id}`),
  getEmployee: (id) => employeeAPI.get(`/employees/${id}`),
};
