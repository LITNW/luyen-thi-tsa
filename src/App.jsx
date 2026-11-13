import { Navigate, Route, Routes, useParams } from 'react-router-dom';
import { useEffect } from 'react';
import RouteGuard from './components/RouteGuard.jsx';
import { useAuth } from './context/AuthContext.jsx';
import AuthPage from './pages/AuthPage.jsx';
import DashboardPage from './pages/DashboardPage.jsx';
import AccountPage from './pages/AccountPage.jsx';
import HistoryPage from './pages/HistoryPage.jsx';
import ResultsPage from './pages/ResultsPage.jsx';
import { AdminHomePage, AdminExamsPage, AdminCategoriesPage, AdminUsersPage, AdminAttemptsPage } from './pages/AdminPages.jsx';

function LegacyRedirect() {
  useEffect(() => { window.location.replace('/legacy/index.html'); }, []);
  return <main className="center-state"><p>Đang mở giao diện hiện tại…</p><a href="/legacy/index.html">Nếu trang không tự chuyển, bấm vào đây.</a></main>;
}

function LegacyExamRedirect() {
  const { id } = useParams();
  useEffect(() => {
    window.location.replace('/legacy/index.html?start=' + encodeURIComponent(id));
  }, [id]);
  return <main className="center-state"><p>Đang mở phòng thi…</p></main>;
}

function HomeRoute() {
  const { session, loading } = useAuth();
  if (loading) return <main className="center-state"><span className="spinner" /><p>Đang tải…</p></main>;
  return session ? <RouteGuard><DashboardPage /></RouteGuard> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<AuthPage mode="login" />} />
      <Route path="/register" element={<AuthPage mode="register" />} />
      <Route path="/" element={<HomeRoute />} />
      <Route path="/account" element={<RouteGuard><AccountPage /></RouteGuard>} />
      <Route path="/history" element={<RouteGuard><HistoryPage /></RouteGuard>} />
      <Route path="/admin" element={<RouteGuard admin><AdminHomePage /></RouteGuard>} />
      <Route path="/admin/exams" element={<RouteGuard admin><AdminExamsPage /></RouteGuard>} />
      <Route path="/admin/categories" element={<RouteGuard admin><AdminCategoriesPage /></RouteGuard>} />
      <Route path="/admin/users" element={<RouteGuard admin><AdminUsersPage /></RouteGuard>} />
      <Route path="/admin/attempts" element={<RouteGuard admin><AdminAttemptsPage /></RouteGuard>} />
      <Route path="/admin/import" element={<RouteGuard admin><LegacyRedirect /></RouteGuard>} />
      <Route path="/exam/:id" element={<RouteGuard><LegacyExamRedirect /></RouteGuard>} />
      <Route path="/results/:attemptId" element={<RouteGuard><ResultsPage /></RouteGuard>} />
      <Route path="/legacy" element={<Navigate to="/legacy/index.html" replace />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
