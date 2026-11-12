import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext.jsx';

export default function AccountPage() {
  const { profile, isAdmin, signOut } = useAuth();
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const navigate = useNavigate();

  const logout = async () => {
    setBusy(true);
    setError('');
    try {
      await signOut();
      navigate('/login', { replace: true });
    } catch (err) {
      setError(err?.message || 'Không thể đăng xuất.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="app-shell">
      <header className="topbar">
        <Link to="/" className="brand-lockup"><span className="brand-mark small-mark">T</span><span><b>TSA Practice</b><small>LUYỆN THI ĐÁNH GIÁ TƯ DUY</small></span></Link>
        <nav className="top-links"><Link to="/">Trang chủ</Link><a href="/legacy/index.html">Giao diện hiện tại</a></nav>
      </header>
      <main className="narrow-page">
        <p className="eyebrow">TÀI KHOẢN</p>
        <h1>Thông tin học viên</h1>
        <section className="account-card">
          <div className="account-avatar">{(profile?.display_name || 'U').slice(0, 1).toUpperCase()}</div>
          <h2>{profile?.display_name}</h2>
          <p className="muted">{profile?.email}</p>
          <dl className="profile-details">
            <div><dt>Mã tài khoản</dt><dd>{profile?.user_code || '—'}</dd></div>
            <div><dt>Vai trò</dt><dd>{isAdmin ? 'Quản trị viên' : 'Học viên'}</dd></div>
            <div><dt>Trạng thái</dt><dd>{profile?.status === 'active' ? 'Đang hoạt động' : 'Không hoạt động'}</dd></div>
          </dl>
          {error && <div className="alert" role="alert">{error}</div>}
          <button className="button secondary full" onClick={logout} disabled={busy}>{busy ? 'Đang đăng xuất…' : 'Đăng xuất'}</button>
        </section>
      </main>
      <footer className="footer">TSA PRACTICE PLATFORM</footer>
    </div>
  );
}
