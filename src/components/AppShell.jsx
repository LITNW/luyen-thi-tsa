import { useRef, useState } from 'react';
import { Link, NavLink } from 'react-router-dom';

const learnerLinks = [
  { to: '/', label: 'Trang chủ', end: true },
  { to: '/history', label: 'Lịch sử' },
  { to: '/account', label: 'Tài khoản' },
];

const adminLinks = [
  { to: '/admin', label: 'Tổng quan', end: true },
  { to: '/admin/education', label: 'Cấu trúc học tập' },
  { to: '/admin/exams', label: 'Đề thi' },
  { to: '/admin/categories', label: 'Loại đề' },
  { to: '/admin/users', label: 'Quản lý tài khoản' },
  { to: '/admin/attempts', label: 'Lượt làm' },
];

function NavigationLink({ item, onNavigate }) {
  return (
    <NavLink
      className="lit-shell-nav-link"
      end={item.end}
      onClick={onNavigate}
      to={item.to}
    >
      <span className="lit-shell-nav-marker" aria-hidden="true" />
      <span>{item.label}</span>
    </NavLink>
  );
}

export default function AppShell({ children, isAdmin = false, profile = null }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuButton = useRef(null);
  const closeMenu = () => setMenuOpen(false);

  const handleNavigationKeyDown = (event) => {
    if (event.key === 'Escape') {
      closeMenu();
      menuButton.current?.focus();
    }
  };

  return (
    <div className="app-shell lit-app-shell">
      <a className="lit-shell-skip-link" href="#main-content">Bỏ qua điều hướng</a>
      <header className="lit-shell-header">
        <Link to="/" className="lit-shell-brand" aria-label="LIT — Trang chủ">
          <img src="/brand/lit-horizontal.svg" alt="LIT" />
        </Link>
        <div className="lit-shell-header-context">
          <span>{isAdmin ? 'Không gian quản trị' : 'Không gian học tập'}</span>
          {profile?.display_name && <b title={profile.display_name}>{profile.display_name}</b>}
        </div>
        <button
          ref={menuButton}
          className="lit-shell-menu-toggle"
          type="button"
          aria-controls="primary-navigation"
          aria-expanded={menuOpen}
          aria-label={menuOpen ? 'Đóng điều hướng' : 'Mở điều hướng'}
          onKeyDown={handleNavigationKeyDown}
          onClick={() => setMenuOpen((open) => !open)}
        >
          <span aria-hidden="true">{menuOpen ? '×' : '☰'}</span>
        </button>
      </header>

      <div className="lit-shell-layout">
        <aside
          className="lit-shell-sidebar"
          data-open={menuOpen}
          onKeyDown={handleNavigationKeyDown}
        >
          <nav id="primary-navigation" aria-label="Điều hướng chính">
            <p className="lit-shell-nav-heading">Học tập</p>
            <div className="lit-shell-nav-group">
              {learnerLinks.map((item) => <NavigationLink key={item.to} item={item} onNavigate={closeMenu} />)}
            </div>
            {isAdmin && <>
              <p className="lit-shell-nav-heading">Quản trị</p>
              <div className="lit-shell-nav-group">
                {adminLinks.map((item) => <NavigationLink key={item.to} item={item} onNavigate={closeMenu} />)}
              </div>
              <a className="lit-shell-nav-link lit-shell-nav-external" href="/legacy/index.html">
                <span className="lit-shell-nav-marker" aria-hidden="true" />
                <span>Trình soạn đề & nhập AI</span>
                <span className="lit-shell-external-note">Giao diện hiện tại</span>
              </a>
            </>}
          </nav>
          <div className="lit-shell-sidebar-foot" aria-label="Thông tin tài khoản">
            <span className="lit-shell-role-mark" aria-hidden="true">{isAdmin ? 'A' : 'L'}</span>
            <span><b>{isAdmin ? 'Quản trị viên' : 'Học viên'}</b><small>{profile?.user_code || 'LIT'}</small></span>
          </div>
        </aside>

        <main id="main-content" className="lit-shell-main" tabIndex={-1}>
          {children}
        </main>
      </div>
    </div>
  );
}
