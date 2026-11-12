import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext.jsx';
import { supabase } from '../lib/supabase.js';

function AdminFrame({ eyebrow = 'ADMIN WORKSPACE', title, children }) {
  return (
    <div className="app-shell">
      <header className="topbar">
        <Link to="/" className="brand-lockup"><span className="brand-mark small-mark">T</span><span><b>TSA Practice</b><small>KHU VỰC QUẢN TRỊ</small></span></Link>
        <nav className="top-links"><Link to="/admin">Tổng quan</Link><Link to="/admin/exams">Đề thi</Link><Link to="/admin/users">Tài khoản</Link><Link to="/admin/attempts">Lượt làm</Link><Link to="/">Trang chủ</Link></nav>
      </header>
      <main className="narrow-page">
        <p className="eyebrow">{eyebrow}</p><h1>{title}</h1>
        {children}
      </main>
      <footer className="footer">TSA PRACTICE PLATFORM · ADMIN</footer>
    </div>
  );
}

export function AdminHomePage() {
  return <AdminFrame title="Quản trị hệ thống">
    <p className="muted">Các màn hình dưới đây dùng RPC hiện có của Supabase. Trình soạn đề và nhập đề AI tiếp tục được mở trong giao diện cũ trong giai đoạn chuyển đổi.</p>
    <div className="admin-grid">
      <Link className="admin-card featured" to="/admin/exams"><b>Quản lý đề thi</b><span>Xem phiên bản, trạng thái và lượt làm</span></Link>
      <Link className="admin-card" to="/admin/users"><b>Quản lý tài khoản</b><span>Vai trò và trạng thái học viên</span></Link>
      <Link className="admin-card" to="/admin/attempts"><b>Theo dõi lượt làm</b><span>Kết quả và thời gian làm bài</span></Link>
      <a className="admin-card" href="/legacy/index.html"><b>Trình soạn đề & nhập AI</b><span>Mở công cụ hiện tại để tạo, sửa và nhập đề</span></a>
    </div>
  </AdminFrame>;
}

export function AdminExamsPage() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  useEffect(() => {
    let active = true;
    supabase.rpc('admin_list_exam_versions').then(({ data, error: rpcError }) => {
      if (!active) return;
      if (rpcError) setError(rpcError.message);
      else setItems(data || []);
      setLoading(false);
    });
    return () => { active = false; };
  }, []);
  return <AdminFrame title="Phiên bản đề thi">
    <p className="muted">Chỉ hiển thị metadata quản trị; đáp án chuẩn không được tải vào màn hình danh sách.</p>
    {error && <div className="alert" role="alert">{error}</div>}
    {loading ? <div className="loading-line"><span className="spinner" /> Đang tải…</div> :
      items.length ? <div className="version-list">{items.map((item) => <article className="version-row" key={item.exam_version_id}>
        <div><b>{item.title}</b><small>Phiên bản {item.version_no} · {item.question_count} câu · {item.duration_minutes} phút · {item.attempt_count} lượt làm</small></div>
        <span className={'status ' + (item.status === 'published' ? 'published' : 'draft')}>{item.status === 'published' ? 'Đã xuất bản' : 'Bản nháp'}</span>
      </article>)}</div> : <div className="empty-state">Chưa có phiên bản đề thi.</div>
    }
    <p className="migration-note"><a href="/legacy/index.html">Mở trình soạn đề hiện tại để tạo hoặc chỉnh sửa phiên bản</a></p>
  </AdminFrame>;
}

export function AdminUsersPage() {
  const { profile } = useAuth();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState('');
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    const { data, error: rpcError } = await supabase.rpc('admin_list_profiles', { p_limit: 200, p_offset: 0 });
    if (rpcError) setError(rpcError.message);
    else { setItems(data || []); setError(''); }
    setLoading(false);
  };

  useEffect(() => { void load(); }, []);

  const update = async (target, patch) => {
    if (target.id === profile?.id) {
      setError('Không thể thay đổi vai trò hoặc trạng thái của chính tài khoản đang đăng nhập tại màn hình này.');
      return;
    }
    const action = patch.role ? 'đổi vai trò' : 'đổi trạng thái';
    if (!window.confirm('Xác nhận ' + action + ' của tài khoản ' + target.email + '?')) return;
    setBusyId(target.id);
    setError('');
    const { error: rpcError } = await supabase.rpc('admin_update_profile', {
      p_user_id: target.id,
      p_display_name: target.display_name,
      p_role: patch.role || target.role,
      p_status: patch.status || target.status,
    });
    if (rpcError) setError(rpcError.message);
    else await load();
    setBusyId('');
  };

  return <AdminFrame title="Quản lý tài khoản">
    <p className="muted">Thay đổi vai trò và trạng thái thông qua RPC quản trị hiện có; không ghi trực tiếp vào bảng profiles.</p>
    {error && <div className="alert" role="alert">{error}</div>}
    {loading ? <div className="loading-line"><span className="spinner" /> Đang tải danh sách tài khoản…</div> :
      <div className="version-list">{items.map((item) => <article className="user-row" key={item.id}>
        <div><b>{item.display_name} · {item.user_code}</b><small>{item.email}</small><small>Vai trò: {item.role} · Trạng thái: {item.status}</small></div>
        <div className="user-actions">
          {item.id === profile?.id ? <span className="muted small">Tài khoản hiện tại</span> : <>
            <button className="button secondary" disabled={busyId === item.id} onClick={() => update(item, { role: item.role === 'admin' ? 'student' : 'admin' })}>{item.role === 'admin' ? 'Hạ quyền' : 'Cấp Admin'}</button>
            <button className="button secondary" disabled={busyId === item.id} onClick={() => update(item, { status: item.status === 'active' ? 'suspended' : 'active' })}>{item.status === 'active' ? 'Tạm khóa' : 'Kích hoạt'}</button>
          </>}
        </div>
      </article>)}</div>
    }
  </AdminFrame>;
}

export function AdminAttemptsPage() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  useEffect(() => {
    let active = true;
    supabase.rpc('admin_list_attempts', { p_limit: 200, p_offset: 0 }).then(({ data, error: rpcError }) => {
      if (!active) return;
      if (rpcError) setError(rpcError.message);
      else setItems(data || []);
      setLoading(false);
    });
    return () => { active = false; };
  }, []);
  return <AdminFrame title="Tất cả lượt làm bài">
    <p className="muted">Dữ liệu được lấy từ RPC quản trị. Không tải đáp án chuẩn hoặc dữ liệu chấm điểm nội bộ ngoài các trường được phép hiển thị.</p>
    {error && <div className="alert" role="alert">{error}</div>}
    {loading ? <div className="loading-line"><span className="spinner" /> Đang tải lượt làm…</div> :
      items.length ? <div className="version-list">{items.map((item) => <article className="version-row" key={item.id}>
        <div><b>{item.title}</b><small>{item.display_name} · {item.user_code} · {item.email}</small><small>{item.started_at ? new Date(item.started_at).toLocaleString('vi-VN') : ''} · {Math.floor((Number(item.elapsed_seconds) || 0) / 60)} phút</small></div>
        <div className="attempt-result"><span className={'status ' + (item.status === 'submitted' ? 'published' : 'draft')}>{item.status === 'submitted' ? 'Đã nộp' : item.status}</span>{item.status === 'submitted' && <b>{item.score} / {item.max_score}</b>}</div>
      </article>)}</div> : <div className="empty-state">Chưa có lượt làm bài.</div>
    }
  </AdminFrame>;
}
