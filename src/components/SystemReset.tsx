import React, { useState, useEffect } from 'react';
import { AlertTriangle, Trash2, RefreshCw, Check, X, Database, Users, Store, Tag, Coffee, ShoppingCart, Grid3X3, Receipt, Settings, Clock } from 'lucide-react';
import { useAuthStore } from '../stores';
import { usePageHeader } from '../contexts/PageHeaderContext';
import { api } from '../services/api';

interface ResetOption {
  id: string;
  label: string;
  description: string;
  icon: React.ReactNode;
  count: number;
  color: string;
}

interface SystemStats {
  users: number;
  stores: number;
  categories: number;
  items: number;
  orders: number;
  tables: number;
  bills: number;
}

const SystemReset: React.FC = () => {
  const { user } = useAuthStore();
  const { setHeaderContent } = usePageHeader();
  const [stats, setStats] = useState<SystemStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedOptions, setSelectedOptions] = useState<Set<string>>(new Set());
  const [isResetting, setIsResetting] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [resetResult, setResetResult] = useState<any>(null);
  const [error, setError] = useState('');

  // Periodic Cleanup Settings State
  const [cleanupEnabled, setCleanupEnabled] = useState(false);
  const [cleanupIntervalMins, setCleanupIntervalMins] = useState(60);
  const [cleanupLastRun, setCleanupLastRun] = useState<string | null>(null);
  const [isSavingConfig, setIsSavingConfig] = useState(false);
  const [configMessage, setConfigMessage] = useState('');
  const [configError, setConfigError] = useState('');

  useEffect(() => {
    setHeaderContent({
      title: 'System Reset',
      subtitle: 'Reset system data - Superadmin only',
    });
    loadData();
  }, [setHeaderContent]);

  const loadData = async () => {
    setIsLoading(true);
    setError('');
    try {
      const [statsData, configData] = await Promise.all([
        api.getSystemStats(),
        api.getSystemConfig()
      ]);
      setStats(statsData);
      setCleanupEnabled(configData.cleanupEnabled);
      setCleanupIntervalMins(configData.cleanupIntervalMins);
      setCleanupLastRun(configData.cleanupLastRun);
    } catch (err: any) {
      setError(err.message || 'Failed to load system data');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSaveConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSavingConfig(true);
    setConfigMessage('');
    setConfigError('');
    try {
      const response = await api.updateSystemConfig({
        cleanupEnabled,
        cleanupIntervalMins
      });
      setConfigMessage(response.message || 'Configuration updated successfully');
      // Refresh config to get latest last-run timestamp if any
      const configData = await api.getSystemConfig();
      setCleanupEnabled(configData.cleanupEnabled);
      setCleanupIntervalMins(configData.cleanupIntervalMins);
      setCleanupLastRun(configData.cleanupLastRun);
    } catch (err: any) {
      setConfigError(err.message || 'Failed to save configuration');
    } finally {
      setIsSavingConfig(false);
    }
  };


  const resetOptions: ResetOption[] = stats ? [
    {
      id: 'users',
      label: 'Users',
      description: 'Remove all users except superadmin',
      icon: <Users size={24} />,
      count: stats.users,
      color: '#ef4444',
    },
    {
      id: 'stores',
      label: 'Stores',
      description: 'Delete all stores and related data',
      icon: <Store size={24} />,
      count: stats.stores,
      color: '#f97316',
    },
    {
      id: 'categories',
      label: 'Categories',
      description: 'Remove all menu categories',
      icon: <Tag size={24} />,
      count: stats.categories,
      color: '#f59e0b',
    },
    {
      id: 'items',
      label: 'Items',
      description: 'Delete all menu items',
      icon: <Coffee size={24} />,
      count: stats.items,
      color: '#eab308',
    },
    {
      id: 'tables',
      label: 'Tables',
      description: 'Remove all table configurations',
      icon: <Grid3X3 size={24} />,
      count: stats.tables,
      color: '#8b5cf6',
    },
    {
      id: 'orders',
      label: 'Orders',
      description: 'Delete all order history',
      icon: <ShoppingCart size={24} />,
      count: stats.orders,
      color: '#06b6d4',
    },
    {
      id: 'bills',
      label: 'Bills',
      description: 'Remove all billing records',
      icon: <Receipt size={24} />,
      count: stats.bills,
      color: '#10b981',
    },
  ] : [];

  const toggleOption = (id: string) => {
    const newSelected = new Set(selectedOptions);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    setSelectedOptions(newSelected);
  };

  const selectAll = () => {
    if (selectedOptions.size === resetOptions.length) {
      setSelectedOptions(new Set());
    } else {
      setSelectedOptions(new Set(resetOptions.map(o => o.id)));
    }
  };

  const handleReset = async () => {
    if (selectedOptions.size === 0) return;
    
    setIsResetting(true);
    setError('');
    
    try {
      const result = await api.resetSystem({
        users: selectedOptions.has('users'),
        stores: selectedOptions.has('stores'),
        categories: selectedOptions.has('categories'),
        items: selectedOptions.has('items'),
        orders: selectedOptions.has('orders'),
        tables: selectedOptions.has('tables'),
        bills: selectedOptions.has('bills'),
      });
      
      setResetResult(result);
      setShowConfirm(false);
      await loadData();
      setSelectedOptions(new Set());
    } catch (err: any) {
      setError(err.message || 'Reset failed');
    } finally {
      setIsResetting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="loading-container">
        <div className="spinner"></div>
      </div>
    );
  }

  if (user?.role !== 'superadmin') {
    return (
      <div className="error-container">
        <AlertTriangle size={48} color="#ef4444" />
        <h2>Access Denied</h2>
        <p>Only superadmin can access system reset functionality.</p>
      </div>
    );
  }

  return (
    <div className="system-reset-container">
      <div className="reset-intro">
        <div className="reset-warning">
          <AlertTriangle size={32} color="#ef4444" />
          <div>
            <h3>Warning: Destructive Action</h3>
            <p>
              System reset will permanently delete selected data. This action cannot be undone.
              Make sure you have a backup if needed.
            </p>
          </div>
        </div>
      </div>

      {/* Periodic Cleanup Settings Card */}
      <div className="cleanup-config-card">
        <div className="cleanup-config-header">
          <Settings size={24} className="config-icon" />
          <div>
            <h3>Periodic Database Cleanup</h3>
            <p>Automatically clean up orders, bills, bill queues, and order items periodically across all stores.</p>
          </div>
        </div>
        
        <form onSubmit={handleSaveConfig} className="cleanup-config-form">
          <div className="form-row">
            <div className="form-group toggle-group">
              <label className="toggle-label">
                <span>Enable Periodic Cleanup</span>
                <span className="toggle-sub">Turn on/off automatic database purge</span>
              </label>
              <button
                type="button"
                className={`toggle-switch ${cleanupEnabled ? 'active' : ''}`}
                onClick={() => setCleanupEnabled(!cleanupEnabled)}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>

            <div className="form-group input-group">
              <label htmlFor="cleanupInterval">
                <span>Cleanup Period (Minutes)</span>
                <span className="toggle-sub">Interval between automatic purges</span>
              </label>
              <input
                id="cleanupInterval"
                type="number"
                min="1"
                required
                value={cleanupIntervalMins}
                onChange={(e) => setCleanupIntervalMins(Math.max(1, parseInt(e.target.value) || 1))}
                className="form-control"
                placeholder="60"
              />
            </div>
          </div>

          <div className="cleanup-status-info">
            <Clock size={16} />
            <span>
              Last Cleanup Run:{' '}
              <strong>
                {cleanupLastRun
                  ? new Date(cleanupLastRun).toLocaleString()
                  : 'Never'}
              </strong>
            </span>
          </div>

          {configError && (
            <div className="error-message" style={{ marginTop: '1rem' }}>
              {configError}
            </div>
          )}

          {configMessage && (
            <div className="success-message" style={{ marginTop: '1rem' }}>
              <Check size={16} />
              <span>{configMessage}</span>
            </div>
          )}

          <div className="form-actions">
            <button
              type="submit"
              className="btn btn-primary"
              disabled={isSavingConfig}
            >
              {isSavingConfig ? (
                <>
                  <RefreshCw size={16} className="spin" style={{ marginRight: '0.5rem' }} />
                  Saving...
                </>
              ) : (
                'Save Configuration'
              )}
            </button>
          </div>
        </form>
      </div>


      {error && (
        <div className="error-message" style={{ marginBottom: '1rem' }}>
          {error}
        </div>
      )}

      {resetResult && (
        <div className="success-message" style={{ marginBottom: '1rem' }}>
          <Check size={16} />
          <span>System reset completed successfully!</span>
          <button 
            className="btn btn-icon" 
            onClick={() => setResetResult(null)}
            style={{ marginLeft: 'auto' }}
          >
            <X size={16} />
          </button>
        </div>
      )}

      <div className="reset-options-header">
        <h3>Select Data to Reset</h3>
        <button className="btn btn-outline btn-sm" onClick={selectAll}>
          {selectedOptions.size === resetOptions.length ? 'Deselect All' : 'Select All'}
        </button>
      </div>

      <div className="reset-options-grid">
        {resetOptions.map((option) => (
          <div
            key={option.id}
            className={`reset-option-card ${selectedOptions.has(option.id) ? 'selected' : ''}`}
            onClick={() => toggleOption(option.id)}
            style={{ '--option-color': option.color } as React.CSSProperties}
          >
            <div className="reset-option-icon" style={{ color: option.color }}>
              {option.icon}
            </div>
            <div className="reset-option-content">
              <h4>{option.label}</h4>
              <p>{option.description}</p>
              <span className="reset-option-count">
                <Database size={12} />
                {option.count} records
              </span>
            </div>
            <div className="reset-option-check">
              {selectedOptions.has(option.id) && <Check size={20} />}
            </div>
          </div>
        ))}
      </div>

      <div className="reset-actions">
        <div className="reset-summary">
          {selectedOptions.size > 0 ? (
            <span>
              <strong>{selectedOptions.size}</strong> categories selected for reset
            </span>
          ) : (
            <span>Select at least one category to reset</span>
          )}
        </div>
        <button
          className="btn btn-danger btn-lg"
          disabled={selectedOptions.size === 0 || isResetting}
          onClick={() => setShowConfirm(true)}
        >
          {isResetting ? (
            <>
              <RefreshCw size={18} className="spin" />
              Resetting...
            </>
          ) : (
            <>
              <Trash2 size={18} />
              Reset System
            </>
          )}
        </button>
      </div>

      {showConfirm && (
        <div className="modal-overlay">
          <div className="modal-content modal-sm">
            <div className="modal-header">
              <h3>Confirm System Reset</h3>
              <button className="btn btn-icon" onClick={() => setShowConfirm(false)}>
                <X size={20} />
              </button>
            </div>
            <div className="modal-body">
              <div className="confirm-warning">
                <AlertTriangle size={48} color="#ef4444" />
                <p>
                  You are about to permanently delete data from the following categories:
                </p>
                <ul className="confirm-list">
                  {Array.from(selectedOptions).map(id => {
                    const option = resetOptions.find(o => o.id === id);
                    return option ? (
                      <li key={id}>
                        <strong>{option.label}</strong> ({option.count} records)
                      </li>
                    ) : null;
                  })}
                </ul>
                <p className="confirm-note">
                  This action <strong>cannot be undone</strong>. Are you sure you want to continue?
                </p>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-outline" onClick={() => setShowConfirm(false)}>
                Cancel
              </button>
              <button 
                className="btn btn-danger" 
                onClick={handleReset}
                disabled={isResetting}
              >
                {isResetting ? 'Resetting...' : 'Yes, Reset System'}
              </button>
            </div>
          </div>
        </div>
      )}

      <style>{`
        .system-reset-container {
          padding: 1.5rem;
          max-width: 1200px;
          margin: 0 auto;
        }

        .reset-intro {
          margin-bottom: 2rem;
        }

        .reset-warning {
          display: flex;
          gap: 1rem;
          padding: 1.25rem;
          background: rgba(239, 68, 68, 0.1);
          border: 1px solid rgba(239, 68, 68, 0.3);
          border-radius: var(--radius);
        }

        .reset-warning h3 {
          color: #ef4444;
          margin: 0 0 0.5rem 0;
          font-size: 1.1rem;
        }

        .reset-warning p {
          margin: 0;
          color: var(--gray-300);
          font-size: 0.9rem;
        }

        .reset-options-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 1rem;
        }

        .reset-options-header h3 {
          margin: 0;
          font-size: 1.1rem;
        }

        .reset-options-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
          gap: 1rem;
          margin-bottom: 2rem;
        }

        .reset-option-card {
          display: flex;
          align-items: flex-start;
          gap: 1rem;
          padding: 1.25rem;
          background: var(--darker);
          border: 2px solid rgba(255, 255, 255, 0.05);
          border-radius: var(--radius);
          cursor: pointer;
          transition: all 0.2s;
        }

        .reset-option-card:hover {
          border-color: rgba(255, 255, 255, 0.1);
          background: var(--dark);
        }

        .reset-option-card.selected {
          border-color: var(--option-color);
          background: rgba(255, 255, 255, 0.03);
        }

        .reset-option-icon {
          flex-shrink: 0;
          width: 48px;
          height: 48px;
          display: flex;
          align-items: center;
          justify-content: center;
          background: rgba(255, 255, 255, 0.05);
          border-radius: var(--radius);
        }

        .reset-option-content {
          flex: 1;
          min-width: 0;
        }

        .reset-option-content h4 {
          margin: 0 0 0.25rem 0;
          font-size: 1rem;
        }

        .reset-option-content p {
          margin: 0 0 0.5rem 0;
          font-size: 0.8rem;
          color: var(--gray-400);
        }

        .reset-option-count {
          display: inline-flex;
          align-items: center;
          gap: 0.25rem;
          font-size: 0.75rem;
          color: var(--gray-500);
          padding: 0.25rem 0.5rem;
          background: rgba(255, 255, 255, 0.05);
          border-radius: 4px;
        }

        .reset-option-check {
          width: 24px;
          height: 24px;
          display: flex;
          align-items: center;
          justify-content: center;
          color: var(--option-color);
        }

        .reset-actions {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 1.25rem;
          background: var(--darker);
          border-radius: var(--radius);
          border: 1px solid rgba(255, 255, 255, 0.05);
        }

        .reset-summary {
          color: var(--gray-400);
        }

        .reset-summary strong {
          color: var(--light);
        }

        .confirm-warning {
          text-align: center;
          padding: 1rem;
        }

        .confirm-warning p {
          margin: 1rem 0;
          color: var(--gray-300);
        }

        .confirm-list {
          text-align: left;
          background: rgba(239, 68, 68, 0.05);
          padding: 1rem 1.5rem;
          border-radius: var(--radius);
          margin: 1rem 0;
          border: 1px solid rgba(239, 68, 68, 0.2);
        }

        .confirm-list li {
          margin: 0.5rem 0;
          color: var(--gray-300);
        }

        .confirm-note {
          font-size: 0.9rem;
          color: #ef4444 !important;
        }

        .error-container {
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 4rem 2rem;
          text-align: center;
        }

        .error-container h2 {
          margin: 1rem 0 0.5rem 0;
        }

        .error-container p {
          color: var(--gray-400);
        }

        .spin {
          animation: spin 1s linear infinite;
        }

        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }

        /* Periodic Cleanup Config Premium Styles */
        .cleanup-config-card {
          background: rgba(255, 255, 255, 0.02);
          backdrop-filter: blur(12px);
          border: 1px solid rgba(255, 255, 255, 0.05);
          border-radius: var(--radius);
          padding: 1.5rem;
          margin-bottom: 2rem;
          box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
        }

        .cleanup-config-header {
          display: flex;
          align-items: center;
          gap: 1rem;
          margin-bottom: 1.5rem;
          border-bottom: 1px solid rgba(255, 255, 255, 0.05);
          padding-bottom: 1rem;
        }

        .config-icon {
          color: var(--primary);
        }

        .cleanup-config-header h3 {
          margin: 0;
          font-size: 1.2rem;
          color: var(--light);
        }

        .cleanup-config-header p {
          margin: 0.25rem 0 0 0;
          font-size: 0.85rem;
          color: var(--gray-400);
        }

        .cleanup-config-form {
          display: flex;
          flex-direction: column;
          gap: 1.25rem;
        }

        .form-row {
          display: flex;
          flex-wrap: wrap;
          gap: 2rem;
        }

        .form-group {
          display: flex;
          flex-direction: column;
          gap: 0.5rem;
          flex: 1;
          min-width: 250px;
        }

        .toggle-group {
          flex-direction: row;
          justify-content: space-between;
          align-items: center;
        }

        .toggle-label {
          display: flex;
          flex-direction: column;
        }

        .toggle-label span:first-child {
          font-weight: 500;
          font-size: 0.95rem;
          color: var(--light);
        }

        .toggle-sub {
          font-size: 0.75rem;
          color: var(--gray-500);
        }

        .toggle-switch {
          width: 50px;
          height: 26px;
          background: rgba(255, 255, 255, 0.1);
          border-radius: 13px;
          position: relative;
          border: none;
          cursor: pointer;
          transition: background-color 0.3s;
          padding: 0;
        }

        .toggle-switch.active {
          background: #10b981;
        }

        .toggle-slider {
          width: 20px;
          height: 20px;
          background: var(--light);
          border-radius: 50%;
          position: absolute;
          top: 3px;
          left: 3px;
          transition: transform 0.3s;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
        }

        .toggle-switch.active .toggle-slider {
          transform: translateX(24px);
        }

        .input-group label {
          font-weight: 500;
          font-size: 0.95rem;
          color: var(--light);
          display: flex;
          flex-direction: column;
        }

        .form-control {
          background: rgba(0, 0, 0, 0.2);
          border: 1px solid rgba(255, 255, 255, 0.1);
          color: var(--light);
          padding: 0.6rem 0.8rem;
          border-radius: 6px;
          font-size: 0.95rem;
          transition: border-color 0.2s;
        }

        .form-control:focus {
          outline: none;
          border-color: var(--primary);
        }

        .cleanup-status-info {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          font-size: 0.85rem;
          color: var(--gray-400);
          background: rgba(255, 255, 255, 0.02);
          padding: 0.6rem 0.8rem;
          border-radius: 6px;
          border: 1px solid rgba(255, 255, 255, 0.03);
          align-self: flex-start;
        }

        .cleanup-status-info strong {
          color: var(--light);
        }

        .form-actions {
          display: flex;
          justify-content: flex-end;
          margin-top: 0.5rem;
        }
      `}</style>
    </div>
  );
};

export default SystemReset;
