import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';

const employeeAPI = axios.create({
  baseURL: API_ENDPOINTS.EMPLOYEE,
});

export const employeeService = {
  getEmployees: (params) => employeeAPI.get('', { params }),
  createEmployee: (data) => employeeAPI.post('', data),
  updateEmployee: (id, data) => employeeAPI.put(`/${id}`, data),
  deleteEmployee: (id) => employeeAPI.delete(`/${id}`),
  getEmployee: (id) => employeeAPI.get(`/${id}`),
};
