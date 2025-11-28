import React, { useState, useEffect, useCallback } from 'react';
import { MonitoredServer } from '../types';
import { MetricsChart } from './MetricsChart';
import { api } from '../services/apiConnector';
import { X, Activity, Cpu, HardDrive, Network, RefreshCw, BarChart3, Database, Plus, Save, Trash2, Check, Pencil, Clock } from 'lucide-react';

interface GraphiteModalProps {
  server: MonitoredServer | null;
  onClose: () => void;
  onUpdate: (server: MonitoredServer) => void;
}

interface CustomChart {
  id: string;
  name: string;
  query: string;
  unit: string;
  data: { timestamp: string; value: number }[];
  color: string;
}

const COMMON_METRICS = [
  { label: 'System Load (1m)', query: 'node_load1', unit: 'load' },
  { label: 'Active Processes', query: 'node_procs_running', unit: '' },
  { label: 'Open File Descriptors', query: 'node_filefd_allocated', unit: '' },
  { label: 'Context Switches', query: 'node_context_switches_total', unit: '/s' },
  { label: 'Goroutines', query: 'go_goroutines', unit: '' },
];

const SCRAPE_INTERVALS = ['15s', '30s', '1m', '5m'];
const REFRESH_RATES = [
    { label: 'Off', value: 0 },
    { label: '5s', value: 5000 },
    { label: '10s', value: 10000 },
    { label: '30s', value: 30000 },
    { label: '1m', value: 60000 },
];

export const GraphiteModal: React.FC<GraphiteModalProps> = ({ server, onClose, onUpdate }) => {
  const [cpuData, setCpuData] = useState<{ timestamp: string; value: number }[]>([]);
  const [memData, setMemData] = useState<{ timestamp: string; value: number }[]>([]);
  const [diskData, setDiskData] = useState<{ timestamp: string; value: number }[]>([]);
  const [netData, setNetData] = useState<{ timestamp: string; value: number }[]>([]);
  
  const [customCharts, setCustomCharts] = useState<CustomChart[]>([]);
  const [isAddingMetric, setIsAddingMetric] = useState(false);
  const [newMetric, setNewMetric] = useState({ name: '', query: '', unit: '' });
  
  const [editingChartId, setEditingChartId] = useState<string | null>(null);
  const [editFormData, setEditFormData] = useState({ name: '', query: '', unit: '', color: '' });
  
  const [scrapeInterval, setScrapeInterval] = useState('15s');
  const [autoRefreshInterval, setAutoRefreshInterval] = useState<number>(0);
  const [isConfigSaved, setIsConfigSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  const refreshMetrics = useCallback(async () => {
    if (!server) return;
    setLoading(true);
    
    try {
        // Fetch real-time (simulated) metrics via API
        const metrics = await api.getMetrics(server.id);

        setCpuData(metrics.cpu);
        setMemData(metrics.memory);
        setDiskData(metrics.disk);
        setNetData(metrics.network);

        // Update Custom Charts (For now, just mocking data for them too via the same API call structure conceptually)
        // In a real app, you would pass `customCharts` queries to `api.getMetrics`
        const dummyCustomData = metrics.cpu; 

        setCustomCharts(prev => prev.map(chart => ({
            ...chart,
            data: dummyCustomData.map(d => ({ ...d, value: Math.floor(Math.random() * 100) })) // Randomized for visual distinction
        })));

    } catch (e) {
        console.error("Failed to fetch metrics", e);
    } finally {
        setLoading(false);
    }
  }, [server]);

  // Initialize data and config
  useEffect(() => {
    if (server) {
      refreshMetrics();
      // Extract existing interval from config or default to 15s
      const match = server.prometheusConfig?.match(/scrape_interval:\s*(\w+)/);
      if (match && match[1]) {
        setScrapeInterval(match[1]);
      } else {
        setScrapeInterval('15s');
      }
    }
  }, [server, refreshMetrics]);

  // Auto Refresh Effect
  useEffect(() => {
    if (autoRefreshInterval > 0) {
        const intervalId = setInterval(refreshMetrics, autoRefreshInterval);
        return () => clearInterval(intervalId);
    }
  }, [autoRefreshInterval, refreshMetrics]);

  const handleAddCustomMetric = () => {
    if (!newMetric.name) return;

    const newChart: CustomChart = {
      id: Date.now().toString(),
      name: newMetric.name,
      query: newMetric.query,
      unit: newMetric.unit,
      data: [], // Will be populated on next refresh
      color: '#' + Math.floor(Math.random()*16777215).toString(16)
    };

    setCustomCharts([...customCharts, newChart]);
    setNewMetric({ name: '', query: '', unit: '' });
    setIsAddingMetric(false);
    
    // Trigger immediate refresh to populate data
    setTimeout(refreshMetrics, 100);
  };

  const handleRemoveCustomMetric = (id: string) => {
    setCustomCharts(prev => prev.filter(c => c.id !== id));
  };
  
  const handleEditClick = (chart: CustomChart) => {
    setEditingChartId(chart.id);
    setEditFormData({ name: chart.name, query: chart.query, unit: chart.unit, color: chart.color });
  };
  
  const handleCancelEdit = () => {
    setEditingChartId(null);
    setEditFormData({ name: '', query: '', unit: '', color: '' });
  };

  const handleSaveEdit = () => {
    if (!editingChartId) return;
    
    setCustomCharts(prev => prev.map(c => {
        if (c.id === editingChartId) {
            return {
                ...c,
                name: editFormData.name,
                query: editFormData.query,
                unit: editFormData.unit,
                color: editFormData.color
            };
        }
        return c;
    }));
    setEditingChartId(null);
  };

  const handlePresetSelect = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const selected = COMMON_METRICS.find(m => m.query === e.target.value);
    if (selected) {
      setNewMetric({ name: selected.label, query: selected.query, unit: selected.unit });
    } else {
      setNewMetric({ ...newMetric, query: e.target.value });
    }
  };

  const handleIntervalChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    if (!server) return;
    
    const newInterval = e.target.value;
    setScrapeInterval(newInterval);
    setIsConfigSaved(true);

    let newConfig = server.prometheusConfig || '';
    
    // Update or insert scrape_interval in the YAML config
    if (newConfig.includes('scrape_interval:')) {
        newConfig = newConfig.replace(/scrape_interval:\s*\w+/, `scrape_interval: ${newInterval}`);
    } else {
        // Try to insert it into the job definition
        if (newConfig.includes('job_name:')) {
             newConfig = newConfig.replace(/(job_name:.*)/, `$1\n    scrape_interval: ${newInterval}`);
        } else {
             newConfig = `scrape_interval: ${newInterval}\n${newConfig}`;
        }
    }
    
    const updatedServer = { ...server, prometheusConfig: newConfig };
    onUpdate(updatedServer);

    // Hide saved indicator after 2s
    setTimeout(() => setIsConfigSaved(false), 2000);
  };

  const getTimeLabel = () => {
      if (autoRefreshInterval === 0) return "Snapshot (30m)";
      return `Live (${autoRefreshInterval / 1000}s rate)`;
  };

  if (!server) return null;

  return (
    <div className="fixed inset-0 bg-slate-900/90 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-slate-800 w-full max-w-5xl rounded-xl border border-slate-700 shadow-2xl flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-700 bg-slate-800 rounded-t-xl">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-slate-700/50 rounded-lg">
                <BarChart3 className="w-6 h-6 text-orange-400" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                System Performance Telemetry
              </h2>
              <div className="flex items-center gap-2 text-sm text-slate-400 font-mono mt-0.5">
                <span className="text-slate-500">Target:</span> 
                {server.name} 
                <span className="text-slate-600">|</span> 
                {server.ip}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-3">
             
             {/* Auto Refresh Control */}
             <div className="flex items-center bg-slate-900 rounded-lg border border-slate-700 p-1">
                <div className="px-2 flex items-center gap-2 text-xs text-slate-400 font-medium">
                    <Clock className="w-3.5 h-3.5" />
                    <span className="hidden sm:inline">Refresh:</span>
                </div>
                <select 
                    value={autoRefreshInterval}
                    onChange={(e) => setAutoRefreshInterval(Number(e.target.value))}
                    className="bg-slate-800 text-slate-200 text-xs border-none rounded py-1 px-2 focus:ring-0 cursor-pointer"
                >
                    {REFRESH_RATES.map(rate => (
                        <option key={rate.label} value={rate.value}>{rate.label}</option>
                    ))}
                </select>
             </div>

             <div className="h-6 w-px bg-slate-700"></div>

             <button 
                onClick={refreshMetrics}
                className={`p-2 text-slate-400 hover:text-blue-400 hover:bg-slate-700 rounded-lg transition-all ${loading ? 'animate-spin text-blue-400' : ''}`}
                title="Refresh Metrics Now"
             >
                <RefreshCw className="w-5 h-5" />
             </button>
             
             <div className="h-6 w-px bg-slate-700"></div>
             
             <button onClick={onClose} className="text-slate-400 hover:text-slate-200 transition-colors">
                <X className="w-6 h-6" />
             </button>
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6 bg-slate-950/30">
            {/* Default Metrics Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
                
                {/* CPU Metrics */}
                <div className="col-span-1">
                    <div className="flex items-center gap-2 mb-3 px-1">
                        <Cpu className="w-4 h-4 text-emerald-400" />
                        <h3 className="text-sm font-semibold text-slate-200">CPU Usage</h3>
                    </div>
                    <MetricsChart 
                        data={cpuData} 
                        color="#34d399" 
                        name="CPU Load" 
                        unit="%"
                        timeLabel={getTimeLabel()}
                    />
                </div>

                {/* Memory Metrics */}
                <div className="col-span-1">
                    <div className="flex items-center gap-2 mb-3 px-1">
                        <Activity className="w-4 h-4 text-purple-400" />
                        <h3 className="text-sm font-semibold text-slate-200">Memory Usage</h3>
                    </div>
                    <MetricsChart 
                        data={memData} 
                        color="#a78bfa" 
                        name="RAM Usage" 
                        unit="%" 
                        timeLabel={getTimeLabel()}
                    />
                </div>

                {/* Disk Metrics */}
                <div className="col-span-1">
                    <div className="flex items-center gap-2 mb-3 px-1">
                        <HardDrive className="w-4 h-4 text-amber-400" />
                        <h3 className="text-sm font-semibold text-slate-200">Disk Usage (/)</h3>
                    </div>
                    <MetricsChart 
                        data={diskData} 
                        color="#fbbf24" 
                        name="Disk Used" 
                        unit="%"
                        domain={[0, 100]}
                        timeLabel={getTimeLabel()}
                    />
                </div>

                {/* Network Metrics */}
                <div className="col-span-1">
                    <div className="flex items-center gap-2 mb-3 px-1">
                        <Network className="w-4 h-4 text-blue-400" />
                        <h3 className="text-sm font-semibold text-slate-200">Network Traffic (eth0)</h3>
                    </div>
                    <MetricsChart 
                        data={netData} 
                        color="#60a5fa" 
                        name="Throughput" 
                        unit="Mb"
                        domain={[0, 600]}
                        timeLabel={getTimeLabel()}
                    />
                </div>

                {/* Custom Charts */}
                {customCharts.map(chart => (
                  <div key={chart.id} className="col-span-1 relative group">
                    {editingChartId === chart.id ? (
                        <div className="h-[296px] w-full bg-slate-900 rounded-xl border border-blue-500 p-6 flex flex-col justify-center gap-4 shadow-xl">
                            <h4 className="text-sm font-bold text-blue-400 flex items-center gap-2">
                                <Pencil className="w-4 h-4" />
                                Edit Metric Configuration
                            </h4>
                            <div>
                                <label className="block text-xs font-medium text-slate-400 mb-1">Raw Query</label>
                                <input 
                                    className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-sm text-slate-200 focus:outline-none focus:border-blue-500 font-mono"
                                    value={editFormData.query}
                                    onChange={e => setEditFormData({...editFormData, query: e.target.value})}
                                />
                            </div>
                            <div className="grid grid-cols-12 gap-3">
                                <div className="col-span-6">
                                    <label className="block text-xs font-medium text-slate-400 mb-1">Name</label>
                                    <input 
                                        className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-sm text-slate-200 focus:outline-none focus:border-blue-500"
                                        value={editFormData.name}
                                        onChange={e => setEditFormData({...editFormData, name: e.target.value})}
                                    />
                                </div>
                                <div className="col-span-3">
                                    <label className="block text-xs font-medium text-slate-400 mb-1">Unit</label>
                                    <input 
                                        className="w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2 text-sm text-slate-200 focus:outline-none focus:border-blue-500"
                                        value={editFormData.unit}
                                        onChange={e => setEditFormData({...editFormData, unit: e.target.value})}
                                    />
                                </div>
                                <div className="col-span-3">
                                    <label className="block text-xs font-medium text-slate-400 mb-1">Color</label>
                                    <div className="flex items-center gap-2 h-[38px] bg-slate-800 border border-slate-600 rounded-lg px-2">
                                        <input 
                                            type="color"
                                            value={editFormData.color}
                                            onChange={e => setEditFormData({...editFormData, color: e.target.value})}
                                            className="w-6 h-6 rounded bg-transparent border-none cursor-pointer"
                                        />
                                    </div>
                                </div>
                            </div>
                            <div className="flex justify-end gap-2 mt-2">
                                <button onClick={handleCancelEdit} className="text-xs text-slate-400 hover:text-white px-3 py-2">Cancel</button>
                                <button onClick={handleSaveEdit} className="text-xs bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-500 font-medium">Save Changes</button>
                            </div>
                        </div>
                    ) : (
                        <>
                            <div className="flex items-center justify-between gap-2 mb-3 px-1">
                                <div className="flex items-center gap-2 overflow-hidden">
                                    <Database className="w-4 h-4 text-slate-400 shrink-0" />
                                    <h3 className="text-sm font-semibold text-slate-200 whitespace-nowrap">{chart.name}</h3>
                                    {chart.query && (
                                        <span className="text-xs text-slate-600 font-mono truncate hidden sm:block" title={chart.query}>
                                            ({chart.query})
                                        </span>
                                    )}
                                </div>
                                <div className="flex items-center gap-1 shrink-0">
                                    <button 
                                    onClick={() => handleEditClick(chart)}
                                    className="p-1.5 text-slate-500 hover:text-blue-400 hover:bg-slate-800 rounded opacity-0 group-hover:opacity-100 transition-all"
                                    title="Edit Metric"
                                    >
                                    <Pencil className="w-4 h-4" />
                                    </button>
                                    <button 
                                    onClick={() => handleRemoveCustomMetric(chart.id)}
                                    className="p-1.5 text-slate-500 hover:text-red-400 hover:bg-slate-800 rounded opacity-0 group-hover:opacity-100 transition-all"
                                    title="Remove Graph"
                                    >
                                    <Trash2 className="w-4 h-4" />
                                    </button>
                                </div>
                            </div>
                            <MetricsChart 
                                data={chart.data} 
                                color={chart.color} 
                                name={chart.name} 
                                unit={chart.unit}
                                timeLabel={getTimeLabel()}
                            />
                        </>
                    )}
                  </div>
                ))}

            </div>

            {/* Add Metric Section */}
            {!isAddingMetric ? (
               <button 
                 onClick={() => setIsAddingMetric(true)}
                 className="w-full py-4 border-2 border-dashed border-slate-700 hover:border-blue-500/50 hover:bg-slate-800/50 rounded-xl text-slate-500 hover:text-blue-400 transition-all flex items-center justify-center gap-2 font-medium"
               >
                 <Plus className="w-5 h-5" />
                 Add Custom Metric
               </button>
            ) : (
               <div className="bg-slate-800 p-5 rounded-xl border border-slate-600 animate-in fade-in slide-in-from-bottom-2">
                  <h4 className="text-sm font-bold text-slate-200 mb-4 flex items-center gap-2">
                    <Database className="w-4 h-4 text-blue-400" />
                    Configure New Graph
                  </h4>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                     <div>
                        <label className="block text-xs font-medium text-slate-400 mb-1">Metric Source</label>
                        <select 
                           onChange={handlePresetSelect}
                           className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 focus:outline-none focus:border-blue-500"
                           defaultValue=""
                        >
                           <option value="" disabled>Select a popular metric...</option>
                           {COMMON_METRICS.map(m => (
                             <option key={m.query} value={m.query}>{m.label} ({m.query})</option>
                           ))}
                           <option value="custom">Custom Query...</option>
                        </select>
                     </div>
                     <div>
                        <label className="block text-xs font-medium text-slate-400 mb-1">Raw Query</label>
                        <input 
                           type="text" 
                           value={newMetric.query}
                           onChange={e => setNewMetric({...newMetric, query: e.target.value})}
                           placeholder="e.g. node_filesystem_free_bytes"
                           className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 focus:outline-none focus:border-blue-500 font-mono"
                        />
                     </div>
                     <div>
                        <label className="block text-xs font-medium text-slate-400 mb-1">Display Name</label>
                        <input 
                           type="text" 
                           value={newMetric.name}
                           onChange={e => setNewMetric({...newMetric, name: e.target.value})}
                           placeholder="My Custom Graph"
                           className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 focus:outline-none focus:border-blue-500"
                        />
                     </div>
                     <div>
                        <label className="block text-xs font-medium text-slate-400 mb-1">Unit (Optional)</label>
                        <input 
                           type="text" 
                           value={newMetric.unit}
                           onChange={e => setNewMetric({...newMetric, unit: e.target.value})}
                           placeholder="e.g. MB, req/s"
                           className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 focus:outline-none focus:border-blue-500"
                        />
                     </div>
                  </div>
                  <div className="flex justify-end gap-3">
                     <button 
                        onClick={() => setIsAddingMetric(false)}
                        className="px-4 py-2 rounded-lg text-slate-400 hover:text-slate-200 text-sm font-medium"
                     >
                        Cancel
                     </button>
                     <button 
                        onClick={handleAddCustomMetric}
                        disabled={!newMetric.name}
                        className="px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-500 text-white text-sm font-medium flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                     >
                        <Save className="w-4 h-4" />
                        Add Graph
                     </button>
                  </div>
               </div>
            )}
            
            <div className="mt-8 flex items-center justify-between p-4 bg-slate-900 rounded-lg border border-slate-700/50">
                <div className="flex items-center gap-3">
                   <Activity className="w-5 h-5 text-slate-500" />
                   <span className="text-sm text-slate-400">
                     Data source: <span className="font-mono text-slate-300">prometheus_node_exporter</span> via Graphite API
                   </span>
                </div>
                
                <div className="flex items-center gap-4">
                  {isConfigSaved && (
                     <div className="flex items-center gap-1.5 text-emerald-400 text-xs font-medium animate-in fade-in slide-in-from-right-2">
                       <Check className="w-3.5 h-3.5" />
                       Saved
                     </div>
                  )}
                  <div className="flex items-center gap-2">
                     <label className="text-xs font-mono text-slate-500">scrape_interval:</label>
                     <select 
                       value={scrapeInterval}
                       onChange={handleIntervalChange}
                       className="bg-slate-800 border border-slate-700 text-xs text-slate-200 rounded px-2 py-1 focus:outline-none focus:border-blue-500 font-mono"
                     >
                       {SCRAPE_INTERVALS.map(int => (
                         <option key={int} value={int}>{int}</option>
                       ))}
                     </select>
                  </div>
                </div>
            </div>
        </div>
      </div>
    </div>
  );
};