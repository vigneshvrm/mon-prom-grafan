# React UI Setup and Build Guide

The modern React UI has been integrated into the web-ui directory. This guide explains how to build and use it.

## Structure

```
web-ui/
├── app.py                    # Flask backend (serves React build)
├── static/                   # React build output (generated)
├── components/               # React components
├── services/                 # API services
├── package.json              # Node.js dependencies
├── vite.config.ts            # Vite build configuration
└── index.html               # React entry point
```

## Building the UI

### Automatic Build (Recommended)

The `start-application.sh` script automatically builds the React UI (and installs Node.js 20.x if needed):

```bash
./start-application.sh
```

This will:
1. Check for Node.js/npm
2. Install npm dependencies if needed
3. Build the React app to `web-ui/static/`
4. Start Flask server (which serves the React build)

### Manual Build

If you want to build manually (Node.js **20+** required):

```bash
cd web-ui

# Install dependencies (first time only)
npm install

# Build for production
npm run build

# The build output will be in web-ui/static/
```

> **Need Node.js 20?** On Debian/Ubuntu run:
> ```
> curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
> sudo apt-get install -y nodejs
> ```

### Development Mode

For development with hot reload:

```bash
cd web-ui
npm install
npm run dev
```

This starts Vite dev server on port 3000 with proxy to Flask API on port 5000.

## How It Works

1. **Build Process**: `npm run build` compiles React app to `web-ui/static/`
2. **Flask Serving**: Flask app serves static files from `static/` directory
3. **API Integration**: React app calls Flask APIs at `/api/*` endpoints
4. **Boot Sequence**: Shows real system status (Podman, Prometheus checks)

## API Endpoints Used

- `GET /api/prometheus-status` - Get Prometheus running status
- `GET /api/system/check-podman` - Check if Podman is installed
- `POST /api/install` - Install Node Exporter on target server
- `POST /api/validate` - Validate installation configuration
- `POST /api/generate-hash` - Generate password hash

## Features

- **System Boot Protocol**: Animated boot sequence showing system checks
- **Dashboard**: Real-time infrastructure overview with stats
- **Add Server Modal**: Professional form to add and monitor servers
- **Settings Page**: System configuration and status
- **Responsive Design**: Works on desktop and mobile
- **Modern UI**: Professional gradients, animations, and styling

## Troubleshooting

### Build Fails

If `npm run build` fails:
1. Check Node.js version: `node --version` (must be **>=20**)
2. Delete `node_modules` and `package-lock.json`, then `npm install` again
3. Ensure dependencies finished installing (no `npm ERR!` in logs)
4. Check for TypeScript errors: `npm run build` will show them

### UI Not Loading

If the React UI doesn't load:
1. Check if `web-ui/static/index.html` exists (build was successful)
2. Check Flask logs for errors
3. Try accessing `http://localhost:5000` directly
4. Check browser console for errors

### API Errors

If API calls fail:
1. Check Flask is running: `curl http://localhost:5000/api/prometheus-status`
2. Check CORS if accessing from different origin
3. Check browser network tab for failed requests

## Fallback

If React build fails or Node.js is not available, Flask will serve the old template from `templates/index.html` as a fallback.

