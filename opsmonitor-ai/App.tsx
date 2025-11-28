import React, { useState, useEffect } from 'react';
import { HashRouter, Routes, Route, Link, useLocation } from 'react-router-dom';
import { BootSequence } from './components/BootSequence';
import { ServerCard } from './components/ServerCard';
import { AddServerModal } from './components/AddServerModal';
import { GraphiteModal } from './components/GraphiteModal';
import { MonitoredServer, ServerStatus } from './types';
import { api } from './services/apiConnector';
import { storageService } from './services/storageService';
import { LayoutDashboard, Plus, Settings, Activity, Database, Trash2, RefreshCw, PanelLeftClose, Menu, X } from 'lucide-react';

const SidebarItem = ({ to, icon: Icon, label }: { to: string, icon: any, label: string }) => {
  const location = useLocation();
  const isActive = location.pathname === to;
  return (
    <Link 
      to={to} 
      className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
        isActive ? 'bg-blue-600/10 text-blue-400 border border-blue-600/20' : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800'
      }`}
    >
      <Icon className="w-5 h-5" />
      <span className="font-medium whitespace-nowrap overflow-hidden transition-all">{label}</span>
    </Link>
  );
};

const DashboardContent: React.FC<{ 
  servers: MonitoredServer[], 
  onAddClick: () => void,
  onDeleteServer: (id: string) => void,
  onViewMetrics: (server: MonitoredServer) => void,
  isLoading: boolean
}> = ({ servers, onAddClick, onDeleteServer, onViewMetrics, isLoading }) => (
  <div className="space-y-6">
    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 className="text-2xl font-bold text-slate-100">Infrastructure Overview</h1>
        <p className="text-slate-400 mt-1">Real-time node status</p>
      </div>
      <button 
        onClick={onAddClick}
        className="w-full sm:w-auto flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-500 text-white px-4 py-2 rounded-lg font-medium transition-colors shadow-lg shadow-blue-600/20"
      >
        <Plus className="w-5 h-5" />
        Add Node
      </button>
    </div>

    {/* Global Stats */}
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-2">
        <div className="bg-slate-800 p-4 rounded-xl border border-slate-700">
            <div className="text-slate-400 text-sm font-medium">Total Nodes</div>
            <div className="text-3xl font-bold text-slate-100 mt-1">{servers.length}</div>
        </div>
        <div className="bg-slate-800 p-4 rounded-xl border border-slate-700">
            <div className="text-slate-400 text-sm font-medium">Healthy</div>
            <div className="text-3xl font-bold text-emerald-400 mt-1">
            {servers.filter(s => s.status === ServerStatus.ONLINE).length}
            </div>
        </div>
        <div className="bg-slate-800 p-4 rounded-xl border border-slate-700">
            <div className="text-slate-400 text-sm font-medium">Prometheus Status</div>
            <div className="text-lg font-bold text-blue-400 mt-2 flex items-center gap-2">
            <div className="w-2.5 h-2.5 rounded-full bg-blue-400 animate-pulse"></div>
            Active (Container)
            </div>
        </div>
    </div>

    {/* Server List */}
    <div className="grid grid-cols-1 gap-4">
      {isLoading ? (
          <div className="py-20 text-center text-slate-500">Loading infrastructure...</div>
      ) : (
          servers.map(server => (
            <ServerCard 
                key={server.id} 
                server={server} 
                onDelete={onDeleteServer}
                onViewMetrics={onViewMetrics}
            />
          ))
      )}
      
      {!isLoading && servers.length === 0 && (
        <div className="py-20 flex flex-col items-center justify-center text-slate-500 border-2 border-dashed border-slate-700 rounded-xl">
          <Activity className="w-12 h-12 mb-4 opacity-50" />
          <h3 className="text-lg font-medium text-slate-300">No Servers Monitored</h3>
          <p className="max-w-md text-center mt-2">Add a new server to install the agent and start monitoring.</p>
        </div>
      )}
    </div>
  </div>
);

const SettingsContent: React.FC<{ onReset: () => void }> = ({ onReset }) => (
  <div className="max-w-2xl space-y-8">
    
    {/* System Status */}
    <div className="space-y-4">
        <h1 className="text-2xl font-bold text-slate-100">System Settings</h1>
        <div className="bg-slate-800 rounded-xl border border-slate-700 p-6 space-y-6">
        <div>
            <h3 className="text-lg font-semibold text-slate-200 mb-4">Container Runtime</h3>
            <div className="flex items-center justify-between p-4 bg-slate-900 rounded-lg border border-slate-700">
                <div>
                <div className="font-medium text-slate-200">Podman Status</div>
                <div className="text-sm text-slate-500">Version 4.5.1</div>
                </div>
                <span className="px-3 py-1 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 rounded-full text-sm">Installed</span>
            </div>
        </div>
        <div>
            <h3 className="text-lg font-semibold text-slate-200 mb-4">Prometheus Configuration</h3>
            <div className="flex items-center justify-between p-4 bg-slate-900 rounded-lg border border-slate-700">
                <div>
                <div className="font-medium text-slate-200">Service Status</div>
                <div className="text-sm text-slate-500">Port 9090</div>
                </div>
                <span className="px-3 py-1 bg-blue-500/10 text-blue-400 border border-blue-500/20 rounded-full text-sm">Running</span>
            </div>
        </div>
        </div>
    </div>

    {/* Database Management */}
    <div className="space-y-4">
        <h2 className="text-xl font-bold text-slate-100 flex items-center gap-2">
            <Database className="w-6 h-6 text-purple-400" />
            Persistence Layer
        </h2>
        <div className="bg-slate-800 rounded-xl border border-slate-700 p-6">
            <p className="text-slate-400 text-sm mb-6">
                The application state is persisted in the local browser database. 
                Resetting the database will remove all custom added nodes and restore defaults.
            </p>
            <div className="flex items-center gap-4">
                <button 
                    onClick={onReset}
                    className="flex items-center gap-2 px-4 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/20 rounded-lg transition-colors"
                >
                    <RefreshCw className="w-4 h-4" />
                    Reset Database
                </button>
            </div>
        </div>
    </div>
  </div>
);

const App: React.FC = () => {
  const [isBooted, setIsBooted] = useState(false);
  const [servers, setServers] = useState<MonitoredServer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedMetricsServer, setSelectedMetricsServer] = useState<MonitoredServer | null>(null);
  const [sidebarOpen, setSidebarOpen] = useState(true);

  // Load Data on Boot
  useEffect(() => {
    if (isBooted) {
      loadData();
    }
  }, [isBooted]);

  const loadData = async () => {
    setIsLoading(true);
    try {
      const data = await api.getNodes();
      setServers(data);
    } catch (e) {
      console.error(e);
    } finally {
      setIsLoading(false);
    }
  };

  // Auto-collapse sidebar on mobile
  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth < 768) {
        setSidebarOpen(false);
      } else {
        setSidebarOpen(true);
      }
    };
    handleResize(); // Init
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const handleAddServer = async (server: MonitoredServer) => {
    // Optimistic update or refresh
    await loadData();
  };

  const handleDeleteServer = async (id: string) => {
      await api.deleteNode(id);
      await loadData();
      if (selectedMetricsServer?.id === id) {
          setSelectedMetricsServer(null);
      }
  };

  const handleUpdateServer = async (updatedServer: MonitoredServer) => {
      await api.updateNode(updatedServer);
      await loadData();
      if (selectedMetricsServer?.id === updatedServer.id) {
          setSelectedMetricsServer(updatedServer);
      }
  };

  const handleResetDb = () => {
    if (window.confirm("Are you sure you want to reset the database? All custom nodes will be lost.")) {
        storageService.resetDatabase();
        loadData();
    }
  };

  if (!isBooted) {
    return <BootSequence onComplete={() => setIsBooted(true)} />;
  }

  return (
    <HashRouter>
      <div className="flex h-screen bg-slate-900 text-slate-200 font-sans overflow-hidden">
        
        {/* Mobile Sidebar Backdrop */}
        {!sidebarOpen ? null : (
             <div className="fixed inset-0 bg-slate-900/80 z-30 md:hidden" onClick={() => setSidebarOpen(false)}></div>
        )}

        {/* Sidebar */}
        <aside className={`
            fixed md:relative z-40 h-full bg-slate-900 border-r border-slate-800 flex flex-col transition-all duration-300 ease-in-out overflow-hidden
            ${sidebarOpen ? 'w-64 translate-x-0' : 'w-0 -translate-x-full md:w-0 md:translate-x-0'}
        `}>
          <div className="w-64 flex flex-col h-full"> {/* Inner Container to maintain width when collapsing */}
            <div className="p-6 border-b border-slate-800 flex items-center justify-between">
                <div className="flex items-center gap-2 text-blue-500">
                    <Activity className="w-8 h-8" />
                    <span className="text-xl font-bold tracking-tight text-slate-100">OpsMonitor AI</span>
                </div>
                <button 
                  onClick={() => setSidebarOpen(false)}
                  className="md:hidden text-slate-400 hover:text-white transition-colors p-1"
                >
                  <X className="w-6 h-6" />
                </button>
            </div>
            
            <nav className="flex-1 p-4 space-y-2">
                <SidebarItem to="/" icon={LayoutDashboard} label="Dashboard" />
                <SidebarItem to="/settings" icon={Settings} label="System Settings" />
            </nav>

            <div className="p-4 border-t border-slate-800">
                <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-blue-500 to-purple-500 flex items-center justify-center font-bold text-xs text-white">
                    OP
                </div>
                <div>
                    <div className="text-sm font-medium text-slate-200">Ops Engineer</div>
                    <div className="text-xs text-slate-500">admin@local</div>
                </div>
                </div>
            </div>
          </div>
        </aside>

        {/* Main Content Area */}
        <div className="flex-1 flex flex-col h-full overflow-hidden">
            {/* Header */}
            <header className="h-16 border-b border-slate-800 bg-slate-900/80 backdrop-blur-md flex items-center gap-4 px-4 md:px-8 z-20">
                <button 
                  onClick={() => setSidebarOpen(!sidebarOpen)}
                  className="p-2 text-slate-400 hover:text-slate-200 rounded-lg hover:bg-slate-800 transition-colors"
                  aria-label="Toggle Sidebar"
                >
                    {sidebarOpen ? <PanelLeftClose className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
                </button>
                {/* Show Title in Header when Sidebar is closed on Desktop to fill empty space */}
                {!sidebarOpen && (
                   <div className="hidden md:flex items-center gap-2 text-blue-500 animate-in fade-in duration-300">
                      <Activity className="w-6 h-6" />
                      <span className="text-lg font-bold tracking-tight text-slate-100">OpsMonitor AI</span>
                   </div>
                )}
            </header>

            {/* Scrollable Main View */}
            <main className="flex-1 overflow-auto p-4 md:p-8">
                <Routes>
                    <Route 
                        path="/" 
                        element={
                            <DashboardContent 
                                servers={servers} 
                                onAddClick={() => setIsModalOpen(true)} 
                                onDeleteServer={handleDeleteServer}
                                onViewMetrics={(server) => setSelectedMetricsServer(server)}
                                isLoading={isLoading}
                            />
                        } 
                    />
                    <Route path="/settings" element={<SettingsContent onReset={handleResetDb} />} />
                </Routes>
            </main>
        </div>

        <AddServerModal 
          isOpen={isModalOpen} 
          onClose={() => setIsModalOpen(false)} 
          onAdd={handleAddServer}
        />

        <GraphiteModal 
          server={selectedMetricsServer} 
          onClose={() => setSelectedMetricsServer(null)} 
          onUpdate={handleUpdateServer}
        />
      </div>
    </HashRouter>
  );
};

export default App;