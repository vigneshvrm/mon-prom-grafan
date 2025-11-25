// API Service to connect React frontend to Flask backend

export interface InstallRequest {
  os: 'linux' | 'windows' | 'auto';
  target_host: string;
  target_username: string;
  target_password: string;
  prometheus_enabled?: boolean;
  prometheus_config_path?: string;
  prometheus_reload_api?: string;
}

export interface InstallResponse {
  success: boolean;
  stdout?: string;
  stderr?: string;
  error?: string;
  returncode?: number;
  prometheus_updated?: boolean;
  node_info?: any;
}

export interface PrometheusStatus {
  running: boolean;
  type: string;
  config_path: string;
  reload_api: string;
}

class ApiService {
  private baseUrl = '/api';

  async getPrometheusStatus(): Promise<PrometheusStatus> {
    const response = await fetch(`${this.baseUrl}/prometheus-status`);
    if (!response.ok) {
      throw new Error('Failed to fetch Prometheus status');
    }
    return response.json();
  }

  async installNodeExporter(data: InstallRequest): Promise<InstallResponse> {
    const response = await fetch(`${this.baseUrl}/install`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Installation failed');
    }

    return response.json();
  }

  async validateConfig(data: Partial<InstallRequest>): Promise<{ valid: boolean; error?: string; errors?: string[] }> {
    const response = await fetch(`${this.baseUrl}/validate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Validation failed');
    }

    return response.json();
  }

  async generatePasswordHash(password: string): Promise<{ success: boolean; hash?: string; error?: string }> {
    const response = await fetch(`${this.baseUrl}/generate-hash`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ password }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Hash generation failed');
    }

    return response.json();
  }
}

export const apiService = new ApiService();

