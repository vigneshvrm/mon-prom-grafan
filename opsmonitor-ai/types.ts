export enum OsFamily {
  WINDOWS = 'Windows',
  LINUX = 'Linux'
}

export enum ServerStatus {
  PENDING = 'PENDING',
  CONFIGURING = 'CONFIGURING',
  ONLINE = 'ONLINE',
  ERROR = 'ERROR'
}

export interface MonitoredServer {
  id: string;
  name: string;
  ip: string;
  port: number;
  os: string;
  sshUser: string;
  status: ServerStatus;
  metrics: {
    cpu: number[];
    memory: number[];
    timestamps: string[];
  };
  ansiblePlaybook?: string;
  prometheusConfig?: string;
}

export interface BootStep {
  id: number;
  message: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  details?: string;
}