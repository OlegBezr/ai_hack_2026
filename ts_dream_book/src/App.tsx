import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom';
import type { ReactNode } from 'react';
import { AuthProvider, useAuth } from './features/auth/AuthProvider';
import { BackgroundMusicProvider } from './features/audio/BackgroundMusic';
import { ToastProvider } from './lib/toast';
import { MagicBackground } from './components/MagicBackground';
import { Spinner } from './components/ui';
import { HomeScreen } from './features/home/HomeScreen';
import { LoginScreen } from './features/auth/LoginScreen';
import { StoriesListScreen } from './features/stories/StoriesListScreen';
import { StoryEditorScreen } from './features/stories/StoryEditorScreen';
import { ProfileScreen } from './features/profile/ProfileScreen';
import { ReaderRoute } from './features/reader/ReaderRoute';

/** Full-screen loader shown while the initial session resolves. */
function FullScreenLoader() {
  return (
    <MagicBackground>
      <div className="flex min-h-screen items-center justify-center">
        <Spinner size={36} />
      </div>
    </MagicBackground>
  );
}

/** Gate for authed routes — redirects to login (mirrors the Flutter guard). */
function RequireAuth({ children }: { children: ReactNode }) {
  const { session, loading } = useAuth();
  if (loading) return <FullScreenLoader />;
  if (!session) return <Navigate to="/stories/login" replace />;
  return <>{children}</>;
}

/** Keeps signed-in users out of the login screen. */
function LoginRoute() {
  const { session, loading } = useAuth();
  const location = useLocation();
  if (loading) return <FullScreenLoader />;
  if (session) return <Navigate to="/stories" replace state={{ from: location }} />;
  return <LoginScreen />;
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<HomeScreen />} />
      <Route path="/stories/login" element={<LoginRoute />} />
      <Route
        path="/stories"
        element={
          <RequireAuth>
            <StoriesListScreen />
          </RequireAuth>
        }
      />
      <Route
        path="/stories/:id"
        element={
          <RequireAuth>
            <StoryEditorScreen />
          </RequireAuth>
        }
      />
      <Route
        path="/read/:id"
        element={
          <RequireAuth>
            <ReaderRoute />
          </RequireAuth>
        }
      />
      <Route
        path="/profile"
        element={
          <RequireAuth>
            <ProfileScreen />
          </RequireAuth>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <BackgroundMusicProvider>
          <ToastProvider>
            <AppRoutes />
          </ToastProvider>
        </BackgroundMusicProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}
