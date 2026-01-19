import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { isAuthenticated as checkIsAuthenticated } from './auth';

interface AuthContextType {
  isAuthenticated: boolean;
  isLoading: boolean;
  setAuthenticated: (value: boolean) => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  // Check authentication state on mount
  useEffect(() => {
    const checkAuth = async () => {
      const authenticated = await checkIsAuthenticated();
      setIsAuthenticated(authenticated);
      setIsLoading(false);
    };
    checkAuth();
  }, []);

  const setAuthenticated = (value: boolean) => {
    setIsAuthenticated(value);
  };

  return (
    <AuthContext.Provider value={{ isAuthenticated, isLoading, setAuthenticated }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
