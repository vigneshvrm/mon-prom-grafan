import React, { useState, useEffect } from 'react';
import { OsFamily, MonitoredServer, ServerStatus } from '../types';
import { apiService } from '../services/apiService';
import { X, Server, Play, Loader2, Lock } from 'lucide-react';

interface AddServerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAdd: (server: MonitoredServer) => void;
}

export const AddServerModal: React.FC<AddServerModalProps> = ({ isOpen, onClose, onAdd }) => {
  const [osFamily, setOsFamily] = useState<OsFamily>(OsFamily.LINUX);
  
  const [formData, setFormData] = useState({
    name: '',
    ip: '',
    port: '22',
    sshUser: 'root',
    password: ''
  });
  
  const [isDeploying, setIsDeploying] = useState(false);

  // Set default port based on OS selection
  useEffect(() => {
    if (osFamily === OsFamily.LINUX) {
      setFormData(prev => ({ ...prev, port: '22', sshUser: 'root' }));
    } else {
      setFormData(prev => ({ ...prev, port: '5986', sshUser: 'Administrator' }));
    }
  }, [osFamily]);

  if (!isOpen) return null;

  const handleDeploy = async () => {
    if (!formData.name || !formData.ip || !formData.port) return;
    
    setIsDeploying(true);
    
    try {
        // Call Flask backend API to install Node Exporter
        const result = await apiService.installNodeExporter({
            os: osFamily.toLowerCase() as 'linux' | 'windows',
            target_host: formData.ip,
            target_username: formData.sshUser,
            target_password: formData.password,
            prometheus_enabled: true
        });

        if (result.success) {
            // SECURITY: Password is NOT stored - only used for installation and then discarded
            // Generate a unique ID using timestamp and random number
            const serverId = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
            const newServer: MonitoredServer = {
                id: serverId,
                name: formData.name,
                ip: formData.ip,
                port: parseInt(formData.port, 10),
                os: osFamily,
                sshUser: formData.sshUser,
                // NOTE: Password is intentionally NOT included - credentials are never stored
                status: ServerStatus.ONLINE,
                metrics: {
                    cpu: [],
                    memory: [],
                    timestamps: []
                }
            };

            // Clear password from memory immediately after use
            formData.password = '';

            onAdd(newServer);
            handleClose();
        } else {
            alert(`Installation failed: ${result.error || result.stderr || 'Unknown error'}`);
        }

    } catch (error: any) {
        console.error("Deployment failed", error);
        alert(`Installation failed: ${error.message || 'Unknown error'}`);
    } finally {
        setIsDeploying(false);
    }
  };

  const handleClose = () => {
    setFormData({ name: '', ip: '', port: '22', sshUser: 'root', password: '' });
    setOsFamily(OsFamily.LINUX);
    setIsDeploying(false);
    onClose();
  };

  const isFormValid = formData.name && formData.ip && formData.port;

  return (
    <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-md flex items-center justify-center z-50 p-4 fade-in">
      <div className="bg-gradient-to-br from-slate-800 to-slate-800/95 w-full max-w-2xl rounded-3xl border border-slate-700/50 shadow-2xl flex flex-col max-h-[90vh] overflow-hidden backdrop-blur-xl">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-slate-700/50 bg-gradient-to-r from-slate-800/50 to-slate-800/30">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-gradient-to-br from-blue-500/20 to-blue-600/10 rounded-xl border border-blue-500/30">
              <Server className="w-6 h-6 text-blue-400" />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
                Add Monitored Node
              </h2>
              <p className="text-slate-400 text-sm mt-1">Configure target server to install Node Exporter agent</p>
            </div>
          </div>
          <button 
            onClick={handleClose} 
            className="p-2 text-slate-400 hover:text-slate-200 hover:bg-slate-700/50 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-8 space-y-8">
            
            {/* 1. OS Selection */}
            <div className="bg-gradient-to-br from-slate-900/80 to-slate-900/50 p-6 rounded-2xl border border-slate-700/50 space-y-4 shadow-lg">
              <h3 className="text-sm font-bold text-slate-300 uppercase tracking-wider flex items-center gap-2">
                <div className="w-1.5 h-1.5 rounded-full bg-blue-400"></div>
                Operating System
              </h3>
              
              <div className="grid grid-cols-2 gap-4">
                 <button
                   onClick={() => setOsFamily(OsFamily.LINUX)}
                   className={`group flex flex-col items-center justify-center gap-3 p-5 rounded-xl border-2 transition-all duration-200 ${
                     osFamily === OsFamily.LINUX 
                     ? 'bg-gradient-to-br from-blue-600/30 to-blue-500/20 border-blue-500 text-blue-100 shadow-lg shadow-blue-500/20 scale-105' 
                     : 'bg-slate-800/50 border-slate-700 text-slate-400 hover:border-slate-600 hover:bg-slate-800 hover:scale-[1.02]'
                   }`}
                 >
                   <div className={`p-2 rounded-lg ${osFamily === OsFamily.LINUX ? 'bg-blue-500/20' : 'bg-slate-700/50'}`}>
                     <Server className="w-6 h-6" />
                   </div>
                   <span className="font-bold text-base">Linux</span>
                   <span className="text-xs text-slate-500">SSH Port 22</span>
                 </button>
                 <button
                   onClick={() => setOsFamily(OsFamily.WINDOWS)}
                   className={`group flex flex-col items-center justify-center gap-3 p-5 rounded-xl border-2 transition-all duration-200 ${
                     osFamily === OsFamily.WINDOWS
                     ? 'bg-gradient-to-br from-blue-600/30 to-blue-500/20 border-blue-500 text-blue-100 shadow-lg shadow-blue-500/20 scale-105' 
                     : 'bg-slate-800/50 border-slate-700 text-slate-400 hover:border-slate-600 hover:bg-slate-800 hover:scale-[1.02]'
                   }`}
                 >
                   <div className={`p-2 rounded-lg ${osFamily === OsFamily.WINDOWS ? 'bg-blue-500/20' : 'bg-slate-700/50'}`}>
                     <Server className="w-6 h-6" />
                   </div>
                   <span className="font-bold text-base">Windows</span>
                   <span className="text-xs text-slate-500">WinRM Port 5986</span>
                 </button>
              </div>
            </div>

            {/* 2. Server Details */}
            <div className="space-y-6">
                <div>
                  <label className="block text-sm font-semibold text-slate-300 mb-2 uppercase tracking-wider">
                    Display Name
                  </label>
                  <input 
                      type="text" 
                      value={formData.name}
                      onChange={e => setFormData({...formData, name: e.target.value})}
                      placeholder="e.g. Production Web Server 01"
                      className="w-full bg-slate-900/80 border border-slate-700/50 rounded-xl px-4 py-3.5 text-slate-100 placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200 font-medium"
                  />
                </div>
                
                <div className="grid grid-cols-12 gap-4">
                  <div className="col-span-8">
                      <label className="block text-sm font-semibold text-slate-300 mb-2 uppercase tracking-wider">
                        IP Address
                      </label>
                      <input 
                      type="text" 
                      value={formData.ip}
                      onChange={e => setFormData({...formData, ip: e.target.value})}
                      placeholder="192.168.1.10"
                      className="w-full bg-slate-900/80 border border-slate-700/50 rounded-xl px-4 py-3.5 text-slate-100 placeholder:text-slate-600 font-mono focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200"
                      />
                  </div>
                  <div className="col-span-4">
                      <label className="block text-sm font-semibold text-slate-300 mb-2 uppercase tracking-wider">
                        Port
                      </label>
                      <input 
                      type="number" 
                      value={formData.port}
                      onChange={e => setFormData({...formData, port: e.target.value})}
                      placeholder="22"
                      className="w-full bg-slate-900/80 border border-slate-700/50 rounded-xl px-4 py-3.5 text-slate-100 placeholder:text-slate-600 font-mono focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200"
                      />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                    <div>
                        <label className="block text-sm font-semibold text-slate-300 mb-2 uppercase tracking-wider">
                            {osFamily === OsFamily.WINDOWS ? 'Administrator User' : 'SSH User'}
                        </label>
                        <input 
                            type="text" 
                            value={formData.sshUser}
                            onChange={e => setFormData({...formData, sshUser: e.target.value})}
                            placeholder={osFamily === OsFamily.WINDOWS ? 'Administrator' : 'root'}
                            className="w-full bg-slate-900/80 border border-slate-700/50 rounded-xl px-4 py-3.5 text-slate-100 placeholder:text-slate-600 font-mono focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200"
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-semibold text-slate-300 mb-2 uppercase tracking-wider">
                           Password
                        </label>
                        <div className="relative">
                          <input 
                              type="password" 
                              value={formData.password}
                              onChange={e => setFormData({...formData, password: e.target.value})}
                              placeholder="••••••••"
                              className="w-full bg-slate-900/80 border border-slate-700/50 rounded-xl px-4 py-3.5 text-slate-100 placeholder:text-slate-600 pl-12 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200"
                          />
                          <Lock className="w-5 h-5 text-slate-500 absolute left-4 top-1/2 -translate-y-1/2" />
                        </div>
                    </div>
                </div>
            </div>
            
            <div className="p-4 bg-gradient-to-r from-blue-900/30 to-blue-800/20 border border-blue-500/30 rounded-xl backdrop-blur-sm">
                <p className="text-sm text-blue-200 flex items-start gap-2">
                    <Lock className="w-4 h-4 mt-0.5 flex-shrink-0" />
                    <span>
                        <strong className="font-semibold">Security Note:</strong> These credentials will be used to securely install and configure the Node Exporter agent on the target server.
                    </span>
                </p>
            </div>
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-slate-700/50 flex justify-end gap-3 bg-gradient-to-r from-slate-800/80 to-slate-800/50 backdrop-blur-sm">
          <button 
            onClick={handleClose} 
            className="px-6 py-3 rounded-xl text-slate-300 hover:bg-slate-700/50 font-semibold transition-all duration-200 hover:scale-105 active:scale-95 border border-slate-700/50"
          >
            Cancel
          </button>
          <button 
            onClick={handleDeploy}
            disabled={!isFormValid || isDeploying}
            className={`px-6 py-3 rounded-xl font-semibold flex items-center gap-2 transition-all duration-200 shadow-lg ${
              !isFormValid || isDeploying
                ? 'bg-slate-700/50 text-slate-500 cursor-not-allowed shadow-none'
                : 'bg-gradient-to-r from-emerald-600 to-emerald-500 hover:from-emerald-500 hover:to-emerald-400 text-white shadow-emerald-500/30 hover:shadow-xl hover:shadow-emerald-500/40 hover:scale-105 active:scale-95'
            }`}
          >
            {isDeploying ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                <span>Installing Agent...</span>
              </>
            ) : (
              <>
                <Play className="w-5 h-5 fill-current" />
                <span>Install Agent & Monitor</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};