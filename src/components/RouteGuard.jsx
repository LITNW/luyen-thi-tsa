import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext.jsx';

export default function RouteGuard({ children, admin = false }) {
  const { session, profile, loading, error, isAdmin } = useAuth();

  if (loading) return <main className="center-state"><span className="spinner" /><p>Đang khôi phục phiên làm việc…</p></main>;
  if (!session) return <Navigate to="/login" replace />;
  if (error || !profile) {
    return (
      <main className="center-state">
        <section className="notice-card">
          <h1>Không tải được hồ sơ</h1>
          <p>{error || 'Tài khoản chưa có hồ sơ hợp lệ.'}</p>
          <a className="button secondary" href="/legacy/index.html">Mở giao diện hiện tại</a>
        </section>
      </main>
    );
  }
  if (profile.status !== 'active') {
    return (
      <main className="center-state">
        <section className="notice-card">
          <h1>Tài khoản không hoạt động</h1>
          <p>Hãy liên hệ quản trị viên để được hỗ trợ.</p>
        </section>
      </main>
    );
  }
  if (admin && !isAdmin) return <Navigate to="/" replace />;
  return children;
}
