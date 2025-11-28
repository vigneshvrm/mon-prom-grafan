# Backend Integration Guide

This document outlines the workflow for connecting the OpsMonitor AI frontend to your backend API. All frontend-to-backend communication is centralized in `services/apiConnector.ts`.

To connect your backend, open `services/apiConnector.ts` and replace the simulated logic with HTTP calls (e.g., `fetch` or `axios`).

---

## 1. Boot Sequence (System Check)

**Trigger:** App startup (BootSequence.tsx)  
**Function:** `api.systemCheck()`  
**Mock Behavior:** Returns `{ status: 'ok' }` after 800ms.

**Backend Requirement:**
- **Endpoint:** `GET /api/system/health`
- **Logic:** Check if Podman is installed/running, if Prometheus container is active.
- **Response:**
  ```json
  {
    "status": "ok" // or "error"
  }
  ```

---

## 2. Dashboard (Load Nodes)

**Trigger:** Dashboard Load (App.tsx)  
**Function:** `api.getNodes()`  
**Mock Behavior:** Reads from browser LocalStorage.

**Backend Requirement:**
- **Endpoint:** `GET /api/nodes`
- **Logic:** Query database for list of monitored servers.
- **Response:** Array of `MonitoredServer` objects.

---

## 3. Add Node (Generate Configs)

**Trigger:** "Install Agent & Monitor" Button (AddServerModal.tsx) -> Phase 1  
**Function:** `api.generateConfigs(os, ip, port, user, name)`  
**Mock Behavior:** Calls Google Gemini API directly from browser.

**Backend Requirement:**
- **Endpoint:** `POST /api/ai/generate`
- **Payload:** `{ os: "Linux", ip: "10.0.0.1", ... }`
- **Logic:** Backend calls Gemini/OpenAI to generate Ansible YAML and Prometheus YAML.
- **Response:**
  ```json
  {
    "ansible": "...", 
    "prometheus": "..."
  }
  ```

---

## 4. Add Node (Deploy & Save)

**Trigger:** "Install Agent & Monitor" Button (AddServerModal.tsx) -> Phase 2  
**Function:** `api.createNode(payload)`  
**Mock Behavior:** Saves to LocalStorage.

**Backend Requirement:**
- **Endpoint:** `POST /api/nodes`
- **Payload:** Server details + Configs generated in step 3 + Password.
- **Logic:** 
  1. Save node to DB.
  2. Trigger Ansible Runner to execute playbook against target IP.
  3. Reload Prometheus config.
- **Response:** The created `MonitoredServer` object.

---

## 5. View Metrics (Graphite)

**Trigger:** "Graphite" Button / Auto-Refresh (GraphiteModal.tsx)  
**Function:** `api.getMetrics(nodeId)`  
**Mock Behavior:** Generates random numbers on the fly.

**Backend Requirement:**
- **Endpoint:** `GET /api/metrics/:nodeId`
- **Logic:** Query Prometheus API (e.g., `http://localhost:9090/api/v1/query_range`).
- **Response:**
  ```json
  {
    "cpu": [{ "timestamp": "10:00", "value": 45 }, ...],
    "memory": [...],
    "disk": [...],
    "network": [...]
  }
  ```

---

## 6. Update Configuration (Scrape Interval)

**Trigger:** "scrape_interval" dropdown (GraphiteModal.tsx)  
**Function:** `api.updateNode(server)`  
**Mock Behavior:** Updates LocalStorage.

**Backend Requirement:**
- **Endpoint:** `PUT /api/nodes/:id`
- **Payload:** The full server object or just the config field.
- **Logic:** Update DB, rewrite `prometheus.yml`, and reload Prometheus service.

---

## 7. Delete Node

**Trigger:** Trash Icon (ServerCard.tsx)  
**Function:** `api.deleteNode(id)`  
**Mock Behavior:** Removes from LocalStorage.

**Backend Requirement:**
- **Endpoint:** `DELETE /api/nodes/:id`
- **Logic:** Remove from DB, remove from `prometheus.yml`.
