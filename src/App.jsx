import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { useEffect } from 'react';
import RouteGuard from './components/RouteGuard.jsx';
import { useAuth } from './context/AuthContext.jsx';
import AuthPage from './pages/AuthPage.jsx';
import DashboardPage from './pages/DashboardPage.jsx';
import AccountPage from './pages/AccountPage.jsx';

function LegacyRedirect() {
  const location = useLocation();
  useEffect(() => {
    const target = '/legacy/index.html';
    window.location.replace(target);
  }, [location.pathname]);
  return <main className="center-state"><p>Đang mở giao diện thi hiện tại…</p><a href="/legacy/index.html">Nếu trang không tự chuyển, bấm vào đây.</a></main>;
}

function HomeRoute() {
  const { session, loading } = useAuth();
  if (loading) return <main className="center-state"><span className="spinner" /><p>Đang tải…</p></main>;
  return session
    ? <RouteGuard><DashboardPage /></RouteGuard>
    : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<AuthPage mode="login" />} />
      <Route path="/register" element={<AuthPage mode="register" />} />
      <Route path="/" element={<HomeRoute />} />
      <Route path="/account" element={<RouteGuard><AccountPage /></RouteGuard>} />
      <Route path="/history" element={<RouteGuard><LegacyRedirect /></RouteGuard>} />
      <Route path="/admin/*" element={<RouteGuard admin><LegacyRedirect /></RouteGuard>} />
      <Route path="/exam/*" element={<RouteGuard><LegacyRedirect /></RouteGuard>} />
      <Route path="/results/*" element={<RouteGuard><LegacyRedirect /></RouteGuard>} />
      <Route path="/legacy" element={<Navigate to="/legacy/index.html" replace />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
