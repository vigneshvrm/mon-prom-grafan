import React, { useEffect, useState } from 'react';
import { BootStep } from '../types';
import { CheckCircle, Circle, Loader2, Terminal, XCircle, RefreshCw, AlertCircle } from 'lucide-react';
import { api } from '../services/apiConnector';

interface BootSequenceProps {
  onComplete: () => void;
}

const INITIAL_STEPS: BootStep[] = [
  { id: 1, message: "Checking System Dependencies...", status: 'pending' },
  { id: 2, message: "Verifying Podman Installation...", status: 'pending' },
  { id: 3, message: "Initializing Container Runtime...", status: 'pending' },
  { id: 4, message: "Checking Prometheus Service Status...", status: 'pending' },
  { id: 5, message: "Verifying Frontend Connection...", status: 'pending' },
];

export const BootSequence: React.FC<BootSequenceProps> = ({ onComplete }) => {
  const [steps, setSteps] = useState<BootStep[]>(INITIAL_STEPS);
  const [currentStepIndex, setCurrentStepIndex] = useState(0);
  const [hasError, setHasError] = useState(false);
  const [errorDetails, setErrorDetails] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState(0);

  useEffect(() => {
    if (hasError) return;

    if (currentStepIndex >= steps.length) {
      setTimeout(onComplete, 800);
      return;
    }

    const timer = setTimeout(() => {
      // 1. Mark current step as running
      setSteps(prev => {
        const newSteps = [...prev];
        newSteps[currentStepIndex].status = 'running';
        if (currentStepIndex > 0) {
          newSteps[currentStepIndex - 1].status = 'completed';
        }
        return newSteps;
      });

      // 2. Perform Check (Using API Connector)
      const performCheck = async () => {
          try {
              // SIMULATION: Simulate Podman missing on the very first run
              // Step 1 is "Verifying Podman..."
              if (currentStepIndex === 1) {
                  // We simulate a backend call here
                  await api.systemCheck();
                  
                  if (retryCount === 0) {
                      throw new Error("Critical Error: 'podman' command not found in PATH.");
                  }
              } else {
                  // Normal delay for other steps
                  await new Promise(resolve => setTimeout(resolve, 600));
              }

              // Success Path
              setSteps(prev => {
                const newSteps = [...prev];
                newSteps[currentStepIndex].status = 'completed';
                return newSteps;
              });
              setCurrentStepIndex(prev => prev + 1);

          } catch (err: any) {
              setSteps(prev => {
                const newSteps = [...prev];
                newSteps[currentStepIndex].status = 'failed';
                return newSteps;
            });
            setHasError(true);
            setErrorDetails(err.message || "Unknown system error");
          }
      };

      performCheck();

    }, 100);

    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentStepIndex, retryCount, hasError]);

  const handleRetry = () => {
    setHasError(false);
    setErrorDetails(null);
    setRetryCount(prev => prev + 1);

    setSteps(prev => {
        const newSteps = [...prev];
        newSteps[currentStepIndex].status = 'pending';
        return newSteps;
    });
  };

  return (
    <div className="fixed inset-0 bg-slate-900 flex flex-col items-center justify-center z-50 p-4">
      <div className={`w-full max-w-md bg-slate-800 rounded-xl border shadow-2xl overflow-hidden transition-colors ${hasError ? 'border-red-500/50' : 'border-slate-700'}`}>
        <div className="bg-slate-950 px-4 py-3 border-b border-slate-700 flex items-center gap-2">
          <Terminal className={`w-5 h-5 ${hasError ? 'text-red-500' : 'text-emerald-400'}`} />
          <h2 className="text-slate-100 font-mono text-sm font-semibold">System Boot Protocol</h2>
        </div>
        
        <div className="p-6 space-y-5">
          {steps.map((step) => (
            <div key={step.id} className="flex items-center gap-3">
              <div className="flex-shrink-0 w-6">
                {step.status === 'pending' && <Circle className="w-5 h-5 text-slate-600" />}
                {step.status === 'running' && <Loader2 className="w-5 h-5 text-blue-400 animate-spin" />}
                {step.status === 'completed' && <CheckCircle className="w-5 h-5 text-emerald-500" />}
                {step.status === 'failed' && <XCircle className="w-5 h-5 text-red-500" />}
              </div>
              <span className={`font-mono text-sm ${
                step.status === 'pending' ? 'text-slate-500' : 
                step.status === 'running' ? 'text-blue-200' : 
                step.status === 'failed' ? 'text-red-400 font-bold' : 'text-slate-200'
              }`}>
                {step.message}
              </span>
            </div>
          ))}

          {hasError && (
              <div className="mt-4 p-4 bg-red-500/10 border border-red-500/20 rounded-lg animate-in fade-in slide-in-from-top-2">
                  <div className="flex items-start gap-3">
                      <AlertCircle className="w-5 h-5 text-red-400 shrink-0 mt-0.5" />
                      <div>
                          <h3 className="text-sm font-bold text-red-400">Startup Failed</h3>
                          <p className="text-xs text-red-300/80 mt-1 font-mono leading-relaxed">
                              {errorDetails}
                          </p>
                      </div>
                  </div>
                  <button 
                    onClick={handleRetry}
                    className="mt-4 w-full flex items-center justify-center gap-2 bg-red-600 hover:bg-red-500 text-white py-2 rounded-lg text-sm font-medium transition-colors"
                  >
                      <RefreshCw className="w-4 h-4" />
                      Refresh & Retry
                  </button>
              </div>
          )}
        </div>
        
        <div className="bg-slate-900/50 px-6 py-4 border-t border-slate-700">
          <p className="text-xs text-slate-500 text-center font-mono">
             OpsMonitor AI v1.0.0 (System Check)
          </p>
        </div>
      </div>
    </div>
  );
};