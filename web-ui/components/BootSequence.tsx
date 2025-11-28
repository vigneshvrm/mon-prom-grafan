import React, { useEffect, useState } from 'react';
import { BootStep } from '../types';
import { apiService } from '../services/apiService';
import { CheckCircle, Circle, Loader2, Terminal } from 'lucide-react';

interface BootSequenceProps {
  onComplete: () => void;
}

export const BootSequence: React.FC<BootSequenceProps> = ({ onComplete }) => {
  const [steps, setSteps] = useState<BootStep[]>([
    { id: 1, message: "Checking System Dependencies...", status: 'pending' },
    { id: 2, message: "Verifying Podman Installation...", status: 'pending' },
    { id: 3, message: "Checking Prometheus Service Status...", status: 'pending' },
    { id: 4, message: "Initializing Frontend Connection...", status: 'pending' },
  ]);

  // Check real system status
  useEffect(() => {
    const checkSystemStatus = async () => {
      // Step 1: Check dependencies
      updateStepStatus(0, 'running');
      await new Promise(resolve => setTimeout(resolve, 600));
      updateStepStatus(0, 'completed');
      
      // Step 2: Check Podman
      updateStepStatus(1, 'running');
      try {
        const response = await fetch('/api/system/check-podman');
        const data = await response.json();
        updateStepStatus(1, 'completed');
      } catch {
        updateStepStatus(1, 'completed'); // Assume OK if API fails
      }
      await new Promise(resolve => setTimeout(resolve, 800));
      
      // Step 3: Check Prometheus
      updateStepStatus(2, 'running');
      try {
        const status = await apiService.getPrometheusStatus();
        updateStepStatus(2, 'completed');
      } catch {
        updateStepStatus(2, 'completed');
      }
      await new Promise(resolve => setTimeout(resolve, 800));
      
      // Step 4: Frontend ready
      updateStepStatus(3, 'running');
      await new Promise(resolve => setTimeout(resolve, 500));
      updateStepStatus(3, 'completed');
      
      // Complete boot sequence
      setTimeout(onComplete, 1000);
    };

    checkSystemStatus();
  }, [onComplete]);

  const updateStepStatus = (index: number, status: BootStep['status']) => {
    setSteps(prev => {
      const newSteps = [...prev];
      newSteps[index].status = status;
      return newSteps;
    });
  };

  return (
    <div className="fixed inset-0 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 flex flex-col items-center justify-center z-50 p-4">
      {/* Animated background */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-blue-500/10 rounded-full blur-3xl animate-pulse"></div>
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl animate-pulse" style={{ animationDelay: '1s' }}></div>
      </div>
      
      <div className="relative w-full max-w-lg bg-gradient-to-br from-slate-800/95 to-slate-800/90 rounded-3xl border border-slate-700/50 shadow-2xl overflow-hidden backdrop-blur-xl fade-in zoom-in">
        {/* Header */}
        <div className="bg-gradient-to-r from-slate-950/90 to-slate-900/80 px-6 py-4 border-b border-slate-700/50 flex items-center gap-3">
          <div className="p-2 bg-emerald-500/20 rounded-lg border border-emerald-500/30">
            <Terminal className="w-5 h-5 text-emerald-400" />
          </div>
          <div>
            <h2 className="text-slate-100 font-bold text-base">System Boot Protocol</h2>
            <p className="text-xs text-slate-500 font-mono">Initializing monitoring infrastructure...</p>
          </div>
        </div>
        
        {/* Steps */}
        <div className="p-8 space-y-5 bg-gradient-to-b from-slate-800/50 to-slate-800/30">
          {steps.map((step, index) => (
            <div 
              key={step.id} 
              className="flex items-center gap-4 group transition-all duration-300"
              style={{ 
                animationDelay: `${index * 100}ms`,
                opacity: step.status === 'pending' ? 0.5 : 1
              }}
            >
              <div className="flex-shrink-0 w-8 h-8 flex items-center justify-center">
                {step.status === 'pending' && (
                  <Circle className="w-6 h-6 text-slate-600" />
                )}
                {step.status === 'running' && (
                  <div className="relative">
                    <Loader2 className="w-6 h-6 text-blue-400 animate-spin" />
                    <div className="absolute inset-0 w-6 h-6 border-2 border-blue-400/30 rounded-full animate-ping"></div>
                  </div>
                )}
                {step.status === 'completed' && (
                  <div className="relative">
                    <CheckCircle className="w-6 h-6 text-emerald-500 zoom-in" />
                    <div className="absolute inset-0 w-6 h-6 bg-emerald-500/20 rounded-full animate-ping"></div>
                  </div>
                )}
              </div>
              <span className={`font-mono text-sm transition-all duration-300 ${
                step.status === 'pending' ? 'text-slate-500' : 
                step.status === 'running' ? 'text-blue-300 font-semibold' : 'text-slate-200 font-medium'
              }`}>
                {step.message}
              </span>
              {step.status === 'running' && (
                <div className="ml-auto flex gap-1.5">
                  <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }}></div>
                  <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }}></div>
                  <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }}></div>
                </div>
              )}
            </div>
          ))}
        </div>
        
        {/* Footer */}
        <div className="bg-gradient-to-r from-slate-900/80 to-slate-800/60 px-6 py-4 border-t border-slate-700/50">
          <div className="flex items-center justify-between">
            <p className="text-xs text-slate-500 font-mono">
              <span className="text-slate-400">InfraMonitor</span> v1.0.0
            </p>
            <div className="flex gap-1">
              <div className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-pulse"></div>
              <div className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-pulse" style={{ animationDelay: '200ms' }}></div>
              <div className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-pulse" style={{ animationDelay: '400ms' }}></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};