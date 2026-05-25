# Docker Setup

This setup includes:
- **PostgreSQL** (port 5432) - Main database
- **PgBouncer** (port 6432) - Connection pooler
- **Adminer** (port 8080) - Database management UI
- **Backend** (port 3001) - Go backend API

## Quick Start

```bash
# Copy environment file
cp .env.example .env

# Start all services
docker-compose up -d

# Or with Makefile
make up
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| PostgreSQL | 5432 | Main database (direct access) |
| PgBouncer | 6432 | Connection pooler (use this for apps) |
| Adminer | 8080 | Database web UI |
| Backend | 3001 | Go API server |

## Access Adminer

Open http://localhost:8080
- System: PostgreSQL
- Server: pgbouncer
- Username: postgres
- Password: postgres
- Database: cafe

## Useful Commands

```bash
# View logs
make logs
make logs-backend
make logs-db

# Restart services
make restart
make restart-backend

# Stop everything
make down

# Stop and remove volumes (DELETES DATA)
make down-volumes

# Check health
curl http://localhost:3001/api/health

# Database shell
make db-shell
```

## Environment Variables

Copy `.env.example` to `.env` and customize:

```env
DB_PASSWORD=secure_password
JWT_SECRET=your-secret-key
SUPERADMIN_PASSWORD=admin_password
```

## Production Deployment

```bash
# Pull latest images and rebuild
docker-compose pull
docker-compose up -d --build

# View production logs
docker-compose logs -f
```
