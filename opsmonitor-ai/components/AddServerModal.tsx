import React, { useState, useEffect } from 'react';
import { OsFamily, MonitoredServer } from '../types';
import { api } from '../services/apiConnector';
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
        // 1. Generate Configs (API Connector)
        const configs = await api.generateConfigs(
            osFamily, 
            formData.ip, 
            formData.port, 
            formData.sshUser, 
            formData.name
        );

        // 2. Create Node & Deploy (API Connector)
        const newServer = await api.createNode({
            name: formData.name,
            ip: formData.ip,
            port: parseInt(formData.port, 10),
            sshUser: formData.sshUser,
            password: formData.password,
            os: osFamily,
            configs: configs
        });

        onAdd(newServer);
        handleClose();

    } catch (error) {
        console.error("Deployment failed", error);
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
    <div className="fixed inset-0 bg-slate-900/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-slate-800 w-full max-w-lg rounded-2xl border border-slate-700 shadow-2xl flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-slate-700">
          <div>
            <h2 className="text-xl font-bold text-slate-100 flex items-center gap-2">
              <Server className="w-6 h-6 text-blue-400" />
              Add Monitored Node
            </h2>
            <p className="text-slate-400 text-sm mt-1">Configure target to install Node Exporter</p>
          </div>
          <button onClick={handleClose} className="text-slate-400 hover:text-slate-200 transition-colors">
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
            
            {/* 1. OS Selection */}
            <div className="bg-slate-900/50 p-4 rounded-xl border border-slate-700 space-y-3">
              <h3 className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Operating System</h3>
              
              <div className="grid grid-cols-2 gap-4">
                 <button
                   onClick={() => setOsFamily(OsFamily.LINUX)}
                   className={`flex items-center justify-center gap-2 p-3 rounded-lg border transition-all ${
                     osFamily === OsFamily.LINUX 
                     ? 'bg-blue-600/20 border-blue-500 text-blue-100' 
                     : 'bg-slate-800 border-slate-700 text-slate-400 hover:border-slate-600'
                   }`}
                 >
                   <span className="font-semibold">Linux</span>
                 </button>
                 <button
                   onClick={() => setOsFamily(OsFamily.WINDOWS)}
                   className={`flex items-center justify-center gap-2 p-3 rounded-lg border transition-all ${
                     osFamily === OsFamily.WINDOWS
                     ? 'bg-blue-600/20 border-blue-500 text-blue-100' 
                     : 'bg-slate-800 border-slate-700 text-slate-400 hover:border-slate-600'
                   }`}
                 >
                   <span className="font-semibold">Windows</span>
                 </button>
              </div>
            </div>

            {/* 2. Server Details */}
            <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-1">Display Name</label>
                  <input 
                      type="text" 
                      value={formData.name}
                      onChange={e => setFormData({...formData, name: e.target.value})}
                      placeholder="e.g. Production Web 01"
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-4 py-2.5 text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
                
                <div className="grid grid-cols-12 gap-3">
                  <div className="col-span-8">
                      <label className="block text-sm font-medium text-slate-300 mb-1">IP Address</label>
                      <input 
                      type="text" 
                      value={formData.ip}
                      onChange={e => setFormData({...formData, ip: e.target.value})}
                      placeholder="192.168.1.10"
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-4 py-2.5 text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                  </div>
                  <div className="col-span-4">
                      <label className="block text-sm font-medium text-slate-300 mb-1">Port</label>
                      <input 
                      type="number" 
                      value={formData.port}
                      onChange={e => setFormData({...formData, port: e.target.value})}
                      placeholder="22"
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-4 py-2.5 text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                    <div>
                        <label className="block text-sm font-medium text-slate-300 mb-1">
                            {osFamily === OsFamily.WINDOWS ? 'Administrator User' : 'SSH User'}
                        </label>
                        <input 
                            type="text" 
                            value={formData.sshUser}
                            onChange={e => setFormData({...formData, sshUser: e.target.value})}
                            placeholder={osFamily === OsFamily.WINDOWS ? 'Administrator' : 'root'}
                            className="w-full bg-slate-900 border border-slate-700 rounded-lg px-4 py-2.5 text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-slate-300 mb-1">
                           Password
                        </label>
                        <div className="relative">
                          <input 
                              type="password" 
                              value={formData.password}
                              onChange={e => setFormData({...formData, password: e.target.value})}
                              placeholder="••••••••"
                              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-4 py-2.5 text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500 pl-10"
                          />
                          <Lock className="w-4 h-4 text-slate-500 absolute left-3 top-3.5" />
                        </div>
                    </div>
                </div>
            </div>
            
            <div className="p-3 bg-blue-900/20 border border-blue-500/20 rounded-lg">
                <p className="text-xs text-blue-200">
                    <strong>Note:</strong> Ansible will use these credentials to install Node Exporter.
                </p>
            </div>
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-slate-700 flex justify-end gap-3 bg-slate-800/50">
          <button onClick={handleClose} className="px-5 py-2.5 rounded-lg text-slate-300 hover:bg-slate-700 font-medium transition-colors">
            Cancel
          </button>
          <button 
            onClick={handleDeploy}
            disabled={!isFormValid || isDeploying}
            className={`px-5 py-2.5 rounded-lg font-medium flex items-center gap-2 transition-all shadow-lg ${
              !isFormValid || isDeploying
                ? 'bg-slate-700 text-slate-500 cursor-not-allowed shadow-none'
                : 'bg-emerald-600 hover:bg-emerald-500 text-white shadow-emerald-500/20'
            }`}
          >
            {isDeploying ? <Loader2 className="w-5 h-5 animate-spin" /> : <Play className="w-5 h-5 fill-current" />}
            {isDeploying ? 'Running Ansible Playbook...' : 'Install Agent & Monitor'}
          </button>
        </div>
      </div>
    </div>
  );
};