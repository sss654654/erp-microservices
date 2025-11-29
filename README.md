# ERP Approval System

Microservices-based ERP approval workflow system with React frontend.

## Architecture
- **Frontend**: React + Vite (Port 3000)
- **Backend Services**:
  - Employee Service (Port 8081) - MySQL
  - Approval Request Service (Port 8082, gRPC 9091) - MongoDB
  - Approval Processing Service (Port 8083, gRPC 9090)
  - Notification Service (Port 8084)

## Quick Start

### Prerequisites
- Docker
- Docker Compose

### Deployment

```bash
# Clone repository
git clone <your-repo-url>
cd erp-approval-system

# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

### Access
- Frontend: http://localhost:3000
- Backend APIs: http://localhost:808X

### Stop Services
```bash
docker-compose down

# Remove volumes (clean database)
docker-compose down -v
```

## Development

### Backend Only
```bash
cd backend
docker-compose up -d
```

### Frontend Only
```bash
cd frontend
npm install
npm run dev
```
