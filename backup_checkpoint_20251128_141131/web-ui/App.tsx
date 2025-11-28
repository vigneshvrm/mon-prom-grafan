import React, { useState, useEffect } from 'react';
import { HashRouter, Routes, Route, Link, useLocation } from 'react-router-dom';
import { BootSequence } from './components/BootSequence';
import { ServerCard } from './components/ServerCard';
import { AddServerModal } from './components/AddServerModal';
import { MonitoredServer, ServerStatus } from './types';
import { apiService, PrometheusStatus, PodmanStatus } from './services/apiService';
import { LayoutDashboard, Plus, Settings, Activity, TrendingUp, AlertCircle } from 'lucide-react';

const SidebarItem = ({ to, icon: Icon, label }: { to: string, icon: any, label: string }) => {
  const location = useLocation();
  const isActive = location.pathname === to;
  return (
    <Link 
      to={to} 
      className={`group relative flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 ${
        isActive 
          ? 'bg-gradient-to-r from-blue-600/20 to-blue-500/10 text-blue-400 border border-blue-500/30 shadow-lg shadow-blue-500/10' 
          : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800/50 hover:translate-x-1'
      }`}
    >
      <Icon className={`w-5 h-5 transition-transform ${isActive ? 'scale-110' : 'group-hover:scale-110'}`} />
      <span className="font-semibold text-sm">{label}</span>
      {isActive && (
        <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-6 bg-gradient-to-b from-blue-400 to-blue-600 rounded-r-full" />
      )}
    </Link>
  );
};

const DashboardContent: React.FC<{ 
  servers: MonitoredServer[], 
  onAddClick: () => void 
}> = ({ servers, onAddClick }) => {
  const onlineCount = servers.filter(s => s.status === ServerStatus.ONLINE).length;
  const errorCount = servers.filter(s => s.status === ServerStatus.ERROR).length;
  
  return (
    <div className="space-y-8 fade-in">
      {/* Header Section */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="space-y-1">
          <h1 className="text-3xl font-bold bg-gradient-to-r from-slate-100 to-slate-300 bg-clip-text text-transparent">
            Infrastructure Overview
          </h1>
          <p className="text-slate-400 text-sm">Real-time monitoring and analytics dashboard</p>
        </div>
        <button 
          onClick={onAddClick}
          className="group flex items-center gap-2 bg-gradient-to-r from-blue-600 to-blue-500 hover:from-blue-500 hover:to-blue-400 text-white px-6 py-3 rounded-xl font-semibold transition-all duration-200 shadow-lg shadow-blue-600/30 hover:shadow-xl hover:shadow-blue-600/40 hover:scale-105 active:scale-95"
        >
          <Plus className="w-5 h-5 group-hover:rotate-90 transition-transform duration-200" />
          Add Node
        </button>
      </div>

      {/* Global Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-5">
        <div className="group bg-gradient-to-br from-slate-800 to-slate-800/50 p-6 rounded-2xl border border-slate-700/50 hover:border-slate-600 transition-all duration-300 hover:shadow-xl hover:shadow-slate-900/50 hover:-translate-y-1">
          <div className="flex items-center justify-between mb-3">
            <div className="text-slate-400 text-sm font-semibold uppercase tracking-wider">Total Nodes</div>
            <Activity className="w-5 h-5 text-slate-500 group-hover:text-blue-400 transition-colors" />
          </div>
          <div className="text-4xl font-bold text-slate-100 mb-1">{servers.length}</div>
          <div className="text-xs text-slate-500 font-medium">Active infrastructure</div>
        </div>
        
        <div className="group bg-gradient-to-br from-emerald-900/20 to-emerald-800/10 p-6 rounded-2xl border border-emerald-700/30 hover:border-emerald-600/50 transition-all duration-300 hover:shadow-xl hover:shadow-emerald-900/30 hover:-translate-y-1">
          <div className="flex items-center justify-between mb-3">
            <div className="text-emerald-400 text-sm font-semibold uppercase tracking-wider">Healthy</div>
            <TrendingUp className="w-5 h-5 text-emerald-500 group-hover:scale-110 transition-transform" />
          </div>
          <div className="text-4xl font-bold text-emerald-400 mb-1">{onlineCount}</div>
          <div className="text-xs text-emerald-500/70 font-medium">
            {servers.length > 0 ? `${Math.round((onlineCount / servers.length) * 100)}% uptime` : 'No data'}
          </div>
        </div>
        
        <div className="group bg-gradient-to-br from-red-900/20 to-red-800/10 p-6 rounded-2xl border border-red-700/30 hover:border-red-600/50 transition-all duration-300 hover:shadow-xl hover:shadow-red-900/30 hover:-translate-y-1">
          <div className="flex items-center justify-between mb-3">
            <div className="text-red-400 text-sm font-semibold uppercase tracking-wider">Issues</div>
            <AlertCircle className="w-5 h-5 text-red-500 group-hover:scale-110 transition-transform" />
          </div>
          <div className="text-4xl font-bold text-red-400 mb-1">{errorCount}</div>
          <div className="text-xs text-red-500/70 font-medium">Requires attention</div>
        </div>
        
        <div className="group bg-gradient-to-br from-blue-900/20 to-blue-800/10 p-6 rounded-2xl border border-blue-700/30 hover:border-blue-600/50 transition-all duration-300 hover:shadow-xl hover:shadow-blue-900/30 hover:-translate-y-1">
          <div className="flex items-center justify-between mb-3">
            <div className="text-blue-400 text-sm font-semibold uppercase tracking-wider">Prometheus</div>
            <div className="w-3 h-3 rounded-full bg-blue-400 animate-pulse shadow-lg shadow-blue-400/50"></div>
          </div>
          <div className="text-lg font-bold text-blue-400 mb-1 flex items-center gap-2">
            <span>Active</span>
          </div>
          <div className="text-xs text-blue-500/70 font-medium">Container running</div>
        </div>
      </div>

      {/* Server List */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-semibold text-slate-200">Monitored Servers</h2>
          <span className="text-sm text-slate-500 font-medium">{servers.length} {servers.length === 1 ? 'server' : 'servers'}</span>
        </div>
        
        <div className="grid grid-cols-1 gap-4">
          {servers.map(server => (
            <ServerCard key={server.id} server={server} />
          ))}
          
          {servers.length === 0 && (
            <div className="py-24 flex flex-col items-center justify-center text-slate-500 border-2 border-dashed border-slate-700/50 rounded-2xl bg-slate-800/30 backdrop-blur-sm">
              <div className="p-4 bg-slate-700/30 rounded-full mb-4">
                <Activity className="w-12 h-12 opacity-50" />
              </div>
              <h3 className="text-xl font-semibold text-slate-300 mb-2">No Servers Monitored</h3>
              <p className="max-w-md text-center text-slate-400 mb-6">
                Get started by adding your first server to install the monitoring agent and begin tracking metrics.
              </p>
              <button
                onClick={onAddClick}
                className="px-6 py-3 bg-blue-600 hover:bg-blue-500 text-white rounded-xl font-semibold transition-all duration-200 shadow-lg shadow-blue-600/20 hover:shadow-xl hover:shadow-blue-600/30"
              >
                Add Your First Server
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

const SettingsContent: React.FC<{
  podmanStatus: PodmanStatus | null;
  prometheusStatus: PrometheusStatus | null;
}> = ({ podmanStatus, prometheusStatus }) => {
  const podmanInstalled = podmanStatus?.installed;
  const podmanVersionMatch = podmanStatus?.version?.match(/([0-9]+(\.[0-9]+){0,2})/);
  const podmanVersionLabel = podmanVersionMatch ? `v${podmanVersionMatch[1]}` : podmanStatus?.version || 'Unavailable';
  const podmanBadgeClasses = podmanInstalled
    ? 'px-4 py-2 bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 rounded-full text-sm font-semibold flex items-center gap-2'
    : 'px-4 py-2 bg-rose-500/10 text-rose-400 border border-rose-500/30 rounded-full text-sm font-semibold flex items-center gap-2';

  const promRunning = prometheusStatus?.running;
  const promStatusLabel = promRunning ? 'Running' : 'Not Running';
  const promStatusSubtext = promRunning
    ? `Source: ${prometheusStatus?.type || 'unknown'}`
    : 'Run ./start-application.sh to deploy Prometheus';
  const promBadgeClasses = promRunning
    ? 'px-4 py-2 bg-blue-500/10 text-blue-400 border border-blue-500/30 rounded-full text-sm font-semibold flex items-center gap-2'
    : 'px-4 py-2 bg-rose-500/10 text-rose-400 border border-rose-500/30 rounded-full text-sm font-semibold flex items-center gap-2';

  return (
    <div className="max-w-3xl space-y-8 fade-in">
      <div className="space-y-1">
        <h1 className="text-3xl font-bold bg-gradient-to-r from-slate-100 to-slate-300 bg-clip-text text-transparent">
          System Settings
        </h1>
        <p className="text-slate-400 text-sm">Configure monitoring infrastructure and runtime settings</p>
      </div>
      
      <div className="bg-gradient-to-br from-slate-800 to-slate-800/50 rounded-2xl border border-slate-700/50 p-8 space-y-8 shadow-xl">
        {/* Container Runtime Section */}
        <div className="space-y-4">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 bg-blue-500/10 rounded-lg">
              <Activity className="w-5 h-5 text-blue-400" />
            </div>
            <h3 className="text-xl font-semibold text-slate-200">Container Runtime</h3>
          </div>
          
          <div className="flex items-center justify-between p-5 bg-slate-900/50 rounded-xl border border-slate-700/50 hover:border-slate-600 transition-all duration-200">
            <div className="space-y-1">
              <div className="font-semibold text-slate-200 flex items-center gap-2">
                Podman Runtime
                <span className="text-xs font-normal text-slate-500">
                  {podmanStatus ? podmanVersionLabel : 'Detecting...'}
                </span>
              </div>
              <div className="text-sm text-slate-400">
                {podmanStatus?.version || 'Container orchestration engine'}
              </div>
            </div>
            <span className={podmanBadgeClasses}>
              <div className={`w-2 h-2 rounded-full ${podmanInstalled ? 'bg-emerald-400 animate-pulse' : 'bg-rose-400'}`}></div>
              {podmanInstalled ? 'Installed' : 'Not Detected'}
            </span>
          </div>
        </div>

        {/* Prometheus Configuration Section */}
        <div className="space-y-4 pt-4 border-t border-slate-700/50">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 bg-purple-500/10 rounded-lg">
              <Settings className="w-5 h-5 text-purple-400" />
            </div>
            <h3 className="text-xl font-semibold text-slate-200">Prometheus Configuration</h3>
          </div>
          
          <div className="flex items-center justify-between p-5 bg-slate-900/50 rounded-xl border border-slate-700/50 hover:border-slate-600 transition-all duration-200 mb-4">
            <div className="space-y-1">
              <div className="font-semibold text-slate-200">Service Status</div>
              <div className="text-sm text-slate-400">{promStatusSubtext}</div>
            </div>
            <span className={promBadgeClasses}>
              <div className={`w-2 h-2 rounded-full ${promRunning ? 'bg-blue-400 animate-pulse' : 'bg-rose-400'}`}></div>
              {prometheusStatus ? promStatusLabel : 'Checking...'}
            </span>
          </div>
          
          <div className="space-y-2">
            <label className="block text-sm font-semibold text-slate-300 uppercase tracking-wider">
              Scrape Interval
            </label>
            <select className="bg-slate-900 border border-slate-700 text-slate-200 rounded-xl px-4 py-3 w-full max-w-xs focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200 font-medium">
              <option>15s (Default)</option>
              <option>30s</option>
              <option>1m</option>
              <option>5m</option>
            </select>
            <p className="text-xs text-slate-500 mt-1">Frequency of metric collection from targets</p>
          </div>
        </div>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  const [isBooted, setIsBooted] = useState(false);
  const [servers, setServers] = useState<MonitoredServer[]>([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [prometheusStatus, setPrometheusStatus] = useState<PrometheusStatus | null>(null);
  const [podmanStatus, setPodmanStatus] = useState<PodmanStatus | null>(null);

  // Fetch infrastructure status and servers on mount
  useEffect(() => {
    const fetchData = async () => {
      try {
        const [promStatus, podStatus, serversData] = await Promise.all([
          apiService.getPrometheusStatus(),
          apiService.getPodmanStatus(),
          apiService.getServers().catch(() => []) // Load servers, fallback to empty array on error
        ]);
        setPrometheusStatus(promStatus);
        setPodmanStatus(podStatus);
        setServers(serversData);
      } catch (error) {
        console.error('Failed to fetch data:', error);
      }
    };
    fetchData();

    // Periodic health check for all servers (every 30 seconds)
    const healthCheckInterval = setInterval(async () => {
      try {
        await apiService.checkAllServersHealth();
        // Refresh server list to get updated statuses
        const serversData = await apiService.getServers().catch(() => []);
        setServers(serversData);
      } catch (error) {
        console.error('Health check failed:', error);
      }
    }, 30000); // Check every 30 seconds

    return () => clearInterval(healthCheckInterval);
  }, []);

  const handleAddServer = async (server: MonitoredServer) => {
    try {
      // Save to database via API
      const savedServer = await apiService.addServer(server);
      // Update local state with saved server
      setServers(prev => [...prev, savedServer]);
    } catch (error) {
      console.error('Failed to save server:', error);
      // Still add to local state for immediate UI feedback
      setServers(prev => [...prev, server]);
      // Show error to user (you can add a toast notification here)
      alert('Failed to save server to database: ' + (error instanceof Error ? error.message : 'Unknown error'));
    }
  };

  if (!isBooted) {
    return <BootSequence onComplete={() => setIsBooted(true)} />;
  }

  return (
    <HashRouter>
      <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 flex text-slate-200 font-sans">
        {/* Sidebar */}
        <aside className="w-72 border-r border-slate-800/50 bg-gradient-to-b from-slate-900/95 to-slate-900/90 backdrop-blur-sm hidden md:flex flex-col fixed h-full z-10 shadow-2xl">
          <div className="p-6 border-b border-slate-800/50">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-gradient-to-br from-blue-500 to-purple-600 rounded-xl shadow-lg shadow-blue-500/20">
                <Activity className="w-6 h-6 text-white" />
              </div>
              <div>
                <span className="text-xl font-bold tracking-tight text-slate-100 block">InfraMonitor</span>
                <span className="text-xs text-slate-500 font-medium">Infrastructure</span>
              </div>
            </div>
          </div>
          
          <nav className="flex-1 p-4 space-y-2 mt-4">
            <SidebarItem to="/" icon={LayoutDashboard} label="Dashboard" />
            <SidebarItem to="/settings" icon={Settings} label="System Settings" />
          </nav>

          <div className="p-4 border-t border-slate-800/50 bg-slate-900/50">
            <div className="flex items-center gap-3 p-3 rounded-xl bg-slate-800/50 border border-slate-700/50">
              <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-blue-500 via-purple-500 to-pink-500 flex items-center justify-center font-bold text-sm text-white shadow-lg">
                OP
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-semibold text-slate-200 truncate">Ops Engineer</div>
                <div className="text-xs text-slate-500 truncate">admin@local</div>
              </div>
            </div>
          </div>
        </aside>

        {/* Main Content */}
        <main className="flex-1 md:ml-72 p-6 md:p-10 overflow-x-hidden">
          <Routes>
            <Route path="/" element={<DashboardContent servers={servers} onAddClick={() => setIsModalOpen(true)} />} />
            <Route 
              path="/settings" 
              element={<SettingsContent podmanStatus={podmanStatus} prometheusStatus={prometheusStatus} />} 
            />
          </Routes>
        </main>

        <AddServerModal 
          isOpen={isModalOpen} 
          onClose={() => setIsModalOpen(false)} 
          onAdd={handleAddServer}
        />
      </div>
    </HashRouter>
  );
};

export default App;