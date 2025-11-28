import { MonitoredServer, ServerStatus, OsFamily } from '../types';
import { storageService } from './storageService';
import { generateAnsiblePlaybook, generatePrometheusConfig } from './geminiService';

/**
 * ==============================================================================
 * API CONNECTOR
 * ==============================================================================
 * This file acts as the bridge between the Frontend UI and your Backend.
 * Currently, it simulates responses using LocalStorage and Gemini AI.
 * 
 * TO CONNECT YOUR BACKEND:
 * 1. Replace the code inside these functions with real fetch() or axios calls.
 * 2. Ensure your backend returns data matching the return types defined here.
 * ==============================================================================
 */

export const api = {

  // ----------------------------------------------------------------------------
  // 1. SYSTEM BOOT & HEALTH
  // ----------------------------------------------------------------------------
  
  /**
   * Checks the health of the host system (Podman, Prometheus, etc.)
   * Endpoint idea: GET /api/health/system-check
   */
  systemCheck: async (): Promise<{ status: 'ok' | 'error'; error?: string }> => {
    // SIMULATION: Simulate a network delay
    await new Promise(resolve => setTimeout(resolve, 800));
    
    // In real app: return await axios.get('/api/health/system-check');
    return { status: 'ok' };
  },

  // ----------------------------------------------------------------------------
  // 2. NODE MANAGEMENT (CRUD)
  // ----------------------------------------------------------------------------

  /**
   * Fetch all monitored nodes.
   * Endpoint idea: GET /api/nodes
   */
  getNodes: async (): Promise<MonitoredServer[]> => {
    // SIMULATION
    return storageService.getServers();
  },

  /**
   * Create a new node and trigger Ansible deployment.
   * Endpoint idea: POST /api/nodes
   */
  createNode: async (payload: {
    name: string;
    ip: string;
    port: number;
    sshUser: string;
    password?: string;
    os: OsFamily;
    configs: { ansible: string; prometheus: string };
  }): Promise<MonitoredServer> => {
    
    // SIMULATION: Simulate deployment latency
    await new Promise(resolve => setTimeout(resolve, 2000));

    const newServer: MonitoredServer = {
      id: Date.now().toString(),
      name: payload.name,
      ip: payload.ip,
      port: payload.port,
      os: payload.os,
      sshUser: payload.sshUser,
      status: ServerStatus.ONLINE, // In real app, might start as PENDING
      metrics: { cpu: [], memory: [], timestamps: [] },
      ansiblePlaybook: payload.configs.ansible,
      prometheusConfig: payload.configs.prometheus
    };

    // In real app: return await axios.post('/api/nodes', payload);
    storageService.addServer(newServer);
    return newServer;
  },

  /**
   * Update an existing node (e.g., changing scrape config).
   * Endpoint idea: PUT /api/nodes/:id
   */
  updateNode: async (server: MonitoredServer): Promise<MonitoredServer> => {
    // SIMULATION
    storageService.updateServer(server);
    return server;
  },

  /**
   * Delete a node.
   * Endpoint idea: DELETE /api/nodes/:id
   */
  deleteNode: async (id: string): Promise<void> => {
    // SIMULATION
    storageService.removeServer(id);
  },

  // ----------------------------------------------------------------------------
  // 3. AI CONFIG GENERATION
  // ----------------------------------------------------------------------------

  /**
   * Generate Ansible and Prometheus configs via AI.
   * Endpoint idea: POST /api/generate-config
   */
  generateConfigs: async (
    os: OsFamily, 
    ip: string, 
    port: string, 
    user: string,
    name: string
  ): Promise<{ ansible: string; prometheus: string }> => {
    
    // In real app, the backend should handle the API key and LLM call.
    const [ansible, prometheus] = await Promise.all([
      generateAnsiblePlaybook(os, ip, port, user),
      generatePrometheusConfig(ip, port, name)
    ]);

    return { ansible, prometheus };
  },

  // ----------------------------------------------------------------------------
  // 4. METRICS & TELEMETRY
  // ----------------------------------------------------------------------------

  /**
   * Fetch time-series metrics for a specific node.
   * Endpoint idea: GET /api/metrics/:nodeId?range=1h
   */
  getMetrics: async (nodeId: string): Promise<{
    cpu: any[];
    memory: any[];
    disk: any[];
    network: any[];
  }> => {
    // SIMULATION: Generate random data
    const generate = (min: number, max: number) => {
      const data = [];
      const now = new Date();
      for (let i = 30; i >= 0; i--) {
        const time = new Date(now.getTime() - i * 60000);
        let value = Math.floor(Math.random() * (max - min + 1) + min);
        data.push({
            timestamp: time.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
            value: value
        });
      }
      return data;
    };

    // Simulate Network Latency
    await new Promise(resolve => setTimeout(resolve, 600));

    return {
      cpu: generate(5, 95),
      memory: generate(40, 85),
      disk: generate(60, 70),
      network: generate(10, 500)
    };
  }
};