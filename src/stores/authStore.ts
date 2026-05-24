import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { api } from '../services/api';
import type { User } from '../types';

interface AuthState {
  user: User | null;
  token: string | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  currentStoreId: string | null;
  
  // Actions
  login: (username: string, password: string) => Promise<boolean>;
  logout: () => void;
  setUser: (user: User) => void;
  setCurrentStore: (storeId: string) => void;
  getCurrentStore: () => { id: string; name: string; branch?: string } | undefined;
  canSwitchStores: () => boolean;
  ensureStoreSelected: () => void;
}

// Helper to get default store ID for a user
const getDefaultStoreId = (user: User | null): string | null => {
  if (!user) return null;
  
  // For business_admin and staff, use their assigned store_id
  if (user.role === 'business_admin' || user.role === 'staff') {
    return user.storeId || null;
  }
  
  // For superadmin and business_owner, use first available store
  return user.stores?.[0]?.id || null;
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      token: null,
      isLoading: false,
      isAuthenticated: false,
      currentStoreId: null,

      login: async (username: string, password: string) => {
        set({ isLoading: true });
        try {
          const data = await api.login(username, password);
          if (data.token && data.user) {
            api.setToken(data.token);
            
            // Set current store to default for this user
            const defaultStoreId = getDefaultStoreId(data.user);
            
            // Check if business_admin or staff has a store assigned
            if ((data.user.role === 'business_admin' || data.user.role === 'staff') && !defaultStoreId) {
              api.clearToken();
              throw new Error('No store assigned. Please contact your administrator.');
            }
            
            set({
              user: data.user,
              token: data.token,
              isAuthenticated: true,
              currentStoreId: defaultStoreId,
            });
            return true;
          }
          return false;
        } catch (error) {
          console.error('Login error:', error);
          throw error;
        } finally {
          set({ isLoading: false });
        }
      },

      logout: () => {
        api.clearToken();
        set({
          user: null,
          token: null,
          isAuthenticated: false,
          currentStoreId: null,
        });
      },

      setUser: (user: User) => {
        set({ user });
      },

      setCurrentStore: (storeId: string) => {
        set({ currentStoreId: storeId });
      },

      getCurrentStore: () => {
        const { user, currentStoreId } = get();
        if (!currentStoreId) return undefined;
        // First check user.stores (from session), fallback to finding in any available stores
        const fromUser = user?.stores?.find(s => s.id === currentStoreId);
        if (fromUser) return fromUser;
        // If not in user.stores (e.g., newly created), try to get from dataStore
        try {
          const dataStore = require('./dataStore').useDataStore.getState();
          return dataStore?.stores?.find((s: any) => s.id === currentStoreId);
        } catch {
          return undefined;
        }
      },

      canSwitchStores: () => {
        const { user } = get();
        if (!user) return false;
        return user.role === 'superadmin' || user.role === 'business_owner';
      },

      ensureStoreSelected: () => {
        const { user, currentStoreId } = get();
        
        // If no store is selected but user has a default store, set it
        if (!currentStoreId && user) {
          const defaultStoreId = getDefaultStoreId(user);
          if (defaultStoreId) {
            set({ currentStoreId: defaultStoreId });
          }
        }
      },
    }),
    {
      name: 'cafe-auth',
      partialize: (state) => ({
        user: state.user,
        token: state.token,
        isAuthenticated: state.isAuthenticated,
        currentStoreId: state.currentStoreId,
      }),
    }
  )
);
