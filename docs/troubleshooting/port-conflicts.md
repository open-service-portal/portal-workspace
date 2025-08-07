# Port Conflicts

## Default Port Allocation

| Service | Default Port | Purpose |
|---------|-------------|---------|
| Backstage Frontend | 3000 | Web UI |
| Backstage Backend | 7007 | API |
| Documentation (Docusaurus) | 3001 | Docs site (planned) |
| Template Preview | 3002 | Template testing (planned) |

## Common Issues

### Error: Port already in use
```
Error: listen EADDRINUSE: address already in use :::3000
```

**Solution:** Find and stop the process using the port:

```bash
# Find what's using port 3000
lsof -i :3000

# Kill the process (use PID from lsof output)
kill -9 <PID>

# Or use a different port
PORT=3001 yarn start
```

### Error: Backend unreachable
```
Failed to fetch from backend: ECONNREFUSED
```

**Solution:** Check if backend is running on port 7007:

```bash
# Check backend port
lsof -i :7007

# If not running, start backend
yarn start-backend
```

## Running Multiple Services

### Option 1: Use different ports

```bash
# Backstage on default ports
cd app-portal
yarn start

# Documentation on custom port
cd docs
PORT=3001 yarn start
```

### Option 2: Use environment variables

Create `.env` files in each project:

```bash
# app-portal/.env
PORT=3000
BACKEND_PORT=7007

# docs/.env  
PORT=3001
```

## Checking Port Availability

```bash
# Check specific port
lsof -i :3000

# Check all common ports
lsof -i :3000,3001,3002,7007

# Alternative with netstat
netstat -an | grep LISTEN | grep 3000
```

## Quick Reference

```bash
# Kill all node processes (nuclear option)
killall node

# Find all Node.js processes
ps aux | grep node

# Free up a specific port
lsof -ti:3000 | xargs kill -9
```