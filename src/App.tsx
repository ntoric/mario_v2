import React, { useEffect } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore, useDataStore } from './stores';
import Login from './components/Login';
import Layout from './components/Layout';
import Tables from './components/Tables';
import Items from './components/Items';
import History from './components/History';
import Users from './components/Users';
import Stores from './components/Stores';
import BusinessSettings from './components/BusinessSettings';
import SystemReset from './components/SystemReset';

const ProtectedRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { isAuthenticated, isLoading } = useAuthStore();
  
  if (isLoading) {
    return (
      <div className="loading-container">
        <div className="spinner"></div>
      </div>
    );
  }
  
  return isAuthenticated ? <>{children}</> : <Navigate to="/login" />;
};

const AppRoutes: React.FC = () => {
  const { isAuthenticated, isLoading } = useAuthStore();
  const initialize = useDataStore((state) => state.initialize);

  useEffect(() => {
    if (isAuthenticated) {
      initialize();
    }
  }, [isAuthenticated, initialize]);

  if (isLoading) {
    return (
      <div className="loading-container">
        <div className="spinner"></div>
      </div>
    );
  }

  return (
    <Routes>
      <Route path="/login" element={isAuthenticated ? <Navigate to="/" /> : <Login />} />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }
      >
        <Route index element={<Tables />} />
        <Route path="items" element={<Items />} />
        <Route path="history" element={<History />} />
        <Route path="users" element={<Users />} />
        <Route path="stores" element={<Stores />} />
        <Route path="business-settings" element={<BusinessSettings />} />
        <Route path="system-reset" element={<SystemReset />} />
      </Route>
    </Routes>
  );
};

const App: React.FC = () => {
  return (
    <div className="app">
      <AppRoutes />
    </div>
  );
};

export default App;
