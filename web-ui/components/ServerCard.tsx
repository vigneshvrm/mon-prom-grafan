import React from 'react';
import { MonitoredServer, ServerStatus } from '../types';
import { Server, Terminal, Activity, ShieldCheck, Clock, Network, MoreVertical } from 'lucide-react';

interface ServerCardProps {
  server: MonitoredServer;
}

export const ServerCard: React.FC<ServerCardProps> = ({ server }) => {
  const getStatusConfig = () => {
    switch (server.status) {
      case ServerStatus.ONLINE:
        return {
          bg: 'from-emerald-500/10 to-emerald-600/5',
          border: 'border-emerald-500/30',
          text: 'text-emerald-400',
          icon: 'bg-emerald-500/20',
          badge: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30',
          pulse: false
        };
      case ServerStatus.CONFIGURING:
        return {
          bg: 'from-blue-500/10 to-blue-600/5',
          border: 'border-blue-500/30',
          text: 'text-blue-400',
          icon: 'bg-blue-500/20',
          badge: 'bg-blue-500/10 text-blue-400 border-blue-500/30',
          pulse: true
        };
      default:
        return {
          bg: 'from-red-500/10 to-red-600/5',
          border: 'border-red-500/30',
          text: 'text-red-400',
          icon: 'bg-red-500/20',
          badge: 'bg-red-500/10 text-red-400 border-red-500/30',
          pulse: false
        };
    }
  };

  const statusConfig = getStatusConfig();

  return (
    <div className={`group relative bg-gradient-to-br ${statusConfig.bg} rounded-2xl border ${statusConfig.border} hover:border-opacity-60 transition-all duration-300 p-6 flex items-center justify-between shadow-lg hover:shadow-xl hover:-translate-y-1 overflow-hidden`}>
      {/* Animated background gradient on hover */}
      <div className="absolute inset-0 bg-gradient-to-r from-blue-500/0 via-purple-500/0 to-pink-500/0 group-hover:from-blue-500/5 group-hover:via-purple-500/5 group-hover:to-pink-500/5 transition-all duration-500 opacity-0 group-hover:opacity-100" />
      
      <div className="relative flex items-center gap-6 flex-1 min-w-0">
        {/* Status Icon */}
        <div className={`flex-shrink-0 p-4 rounded-xl ${statusConfig.icon} ${statusConfig.text} transition-transform group-hover:scale-110 duration-300 ${statusConfig.pulse ? 'animate-pulse' : ''}`}>
          {server.status === ServerStatus.ONLINE ? (
            <Server className="w-7 h-7" />
          ) : (
            <Activity className="w-7 h-7" />
          )}
        </div>

        {/* Server Info */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-3 mb-2">
            <h3 className="font-bold text-slate-100 text-xl leading-tight tracking-tight truncate">
              {server.name}
            </h3>
            {server.status === ServerStatus.ONLINE && (
              <div className="flex-shrink-0 w-2 h-2 rounded-full bg-emerald-400 animate-pulse shadow-lg shadow-emerald-400/50" />
            )}
          </div>
          <div className="flex flex-wrap items-center gap-4 text-sm text-slate-400">
            <span className="flex items-center gap-2 font-mono">
              <Network className="w-4 h-4 text-slate-500" />
              <span className="text-slate-500 font-semibold">HOST:</span>
              <span className="text-slate-300">{server.ip}:{server.port}</span>
            </span>
            <span className="w-1 h-1 rounded-full bg-slate-600"></span>
            <span className="flex items-center gap-2">
              <span className="text-slate-500 font-semibold">OS:</span>
              <span className="text-slate-300 font-medium">{server.os}</span>
            </span>
            <span className="w-1 h-1 rounded-full bg-slate-600"></span>
            <span className="flex items-center gap-2">
              <span className="text-slate-500 font-semibold">USER:</span>
              <span className="text-slate-300 font-mono">{server.sshUser}</span>
            </span>
          </div>
        </div>
      </div>

      {/* Status Badge & Actions */}
      <div className="relative flex items-center gap-4 flex-shrink-0">
        <div className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold border ${statusConfig.badge} shadow-lg backdrop-blur-sm`}>
          {server.status === ServerStatus.ONLINE ? (
            <ShieldCheck className="w-4 h-4" />
          ) : (
            <Clock className="w-4 h-4" />
          )}
          <span>{server.status}</span>
        </div>

        <div className="h-10 w-px bg-slate-700/50 mx-1 hidden sm:block"></div>

        <div className="flex items-center gap-2">
          <button 
            className="p-2.5 text-slate-400 hover:text-slate-100 hover:bg-slate-700/50 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95 group/btn" 
            title="View Logs"
          >
            <Terminal className="w-5 h-5 group-hover/btn:text-blue-400 transition-colors" />
          </button>
          <button 
            className="p-2.5 text-slate-400 hover:text-slate-100 hover:bg-slate-700/50 rounded-xl transition-all duration-200 hover:scale-110 active:scale-95 group/btn" 
            title="More Options"
          >
            <MoreVertical className="w-5 h-5 group-hover/btn:text-slate-300 transition-colors" />
          </button>
        </div>
      </div>
    </div>
  );
};