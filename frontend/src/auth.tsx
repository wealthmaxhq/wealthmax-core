import { createContext, ReactNode, useContext, useEffect, useState } from 'react';
import {
  AUTH_EXPIRED_EVENT,
  getCurrentUser,
  setAuthToken,
  User,
} from './api';

type AuthContextValue = {
  user: User | null;
  ready: boolean;
  establishSession: (token: string, user: User) => void;
  updateUser: (user: User) => void;
  logout: () => void;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);

  const logout = () => {
    localStorage.removeItem('token');
    setAuthToken(null);
    setUser(null);
    setReady(true);
  };

  const establishSession = (token: string, authenticatedUser: User) => {
    localStorage.setItem('token', token);
    setAuthToken(token);
    setUser(authenticatedUser);
    setReady(true);
  };

  useEffect(() => {
    const savedToken = localStorage.getItem('token');
    if (!savedToken) {
      setReady(true);
      return;
    }
    getCurrentUser()
      .then((response) => setUser(response.data.user))
      .catch(logout)
      .finally(() => setReady(true));
  }, []);

  useEffect(() => {
    window.addEventListener(AUTH_EXPIRED_EVENT, logout);
    return () => window.removeEventListener(AUTH_EXPIRED_EVENT, logout);
  }, []);

  return (
    <AuthContext.Provider value={{ user, ready, establishSession, updateUser: setUser, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used within AuthProvider.');
  return value;
}
