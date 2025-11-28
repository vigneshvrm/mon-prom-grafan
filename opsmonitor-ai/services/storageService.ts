import { MonitoredServer, ServerStatus } from '../types';

const STORAGE_KEY = 'opsmonitor_db_v1';

// Initial seed data to populate DB on first run
const SEED_DATA: MonitoredServer[] = [
  {
    id: '1',
    name: 'Primary Database',
    ip: '10.0.0.5',
    port: 22,
    os: 'Linux',
    sshUser: 'admin',
    status: ServerStatus.ONLINE,
    metrics: {
      cpu: [],
      memory: [],
      timestamps: []
    }
  }
];

export const storageService = {
  /**
   * Load servers from persistence. 
   * If DB is empty, initializes it with SEED_DATA.
   */
  getServers: (): MonitoredServer[] => {
    try {
      const storedData = localStorage.getItem(STORAGE_KEY);
      if (!storedData) {
        console.log('Initializing Database with Seed Data...');
        localStorage.setItem(STORAGE_KEY, JSON.stringify(SEED_DATA));
        return SEED_DATA;
      }
      return JSON.parse(storedData);
    } catch (error) {
      console.error('Failed to load database:', error);
      return SEED_DATA;
    }
  },

  /**
   * Add a single server and persist to DB.
   */
  addServer: (server: MonitoredServer): MonitoredServer[] => {
    const current = storageService.getServers();
    const updated = [...current, server];
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
    return updated;
  },

  /**
   * Update a single server and persist to DB.
   */
  updateServer: (updatedServer: MonitoredServer): MonitoredServer[] => {
    const current = storageService.getServers();
    const updatedList = current.map(s => s.id === updatedServer.id ? updatedServer : s);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updatedList));
    return updatedList;
  },

  /**
   * Remove a server by ID.
   */
  removeServer: (id: string): MonitoredServer[] => {
    const current = storageService.getServers();
    const updated = current.filter(s => s.id !== id);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
    return updated;
  },

  /**
   * Update entire server list (for deletion or bulk updates).
   */
  saveAll: (servers: MonitoredServer[]) => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(servers));
  },

  /**
   * Clear database and restore seed data.
   */
  resetDatabase: (): MonitoredServer[] => {
    localStorage.removeItem(STORAGE_KEY);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(SEED_DATA));
    return SEED_DATA;
  }
};