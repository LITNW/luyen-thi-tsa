import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext.jsx';
import { supabase } from '../lib/supabase.js';

function AdminFrame({ eyebrow = 'ADMIN WORKSPACE', title, children }) {
  return (
    <div className="app-shell">
      <header className="topbar">
        <Link to="/" className="brand-lockup"><span className="brand-mark small-mark">T</span><span><b>TSA Practice</b><small>KHU VỰC QUẢN TRỊ</small></span></Link>
        <nav className="top-links"><Link to="/admin">Tổng quan</Link><Link to="/admin/exams">Đề thi</Link><Link to="/admin/categories">Danh mục</Link><Link to="/admin/users">Tài khoản</Link><Link to="/admin/attempts">Lượt làm</Link><Link to="/">Trang chủ</Link></nav>
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
    <p className="muted">Các màn hình dưới đây dùng RPC quản trị của Supabase. Trình soạn đề và nhập đề AI tiếp tục được mở trong giao diện hiện tại trong giai đoạn chuyển đổi.</p>
    <div className="admin-grid">
      <Link className="admin-card featured" to="/admin/exams"><b>Quản lý đề thi</b><span>Xem phiên bản, trạng thái, lượt làm và gán danh mục</span></Link>
      <Link className="admin-card" to="/admin/categories"><b>Quản lý danh mục</b><span>Tạo, sửa, phân cấp và ẩn danh mục đề thi</span></Link>
      <Link className="admin-card" to="/admin/users"><b>Quản lý tài khoản</b><span>Vai trò và trạng thái học viên</span></Link>
      <Link className="admin-card" to="/admin/attempts"><b>Theo dõi lượt làm</b><span>Kết quả và thời gian làm bài</span></Link>
      <a className="admin-card" href="/legacy/index.html"><b>Trình soạn đề & nhập AI</b><span>Mở công cụ hiện tại để tạo, sửa và nhập đề</span></a>
    </div>
  </AdminFrame>;
}

export function AdminExamsPage() {
  const [items, setItems] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyExamId, setBusyExamId] = useState('');
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    const [examResult, categoryResult] = await Promise.all([
      supabase.rpc('admin_list_exam_versions_with_categories'),
      supabase.rpc('admin_list_exam_categories'),
    ]);
    if (examResult.error) setError(examResult.error.message);
    else if (categoryResult.error) setError(categoryResult.error.message);
    else {
      setItems(examResult.data || []);
      setCategories(categoryResult.data || []);
      setError('');
    }
    setLoading(false);
  };

  useEffect(() => { void load(); }, []);

  const assignCategory = async (examId, categoryId) => {
    setBusyExamId(examId);
    setError('');
    const { error: rpcError } = await supabase.rpc('admin_set_exam_category', {
      p_exam_id: examId,
      p_category_id: categoryId || null,
    });
    if (rpcError) setError(rpcError.message);
    else {
      const selected = categories.find((category) => category.id === categoryId);
      setItems((current) => current.map((item) => item.exam_id === examId ? {
        ...item,
        category_id: categoryId || null,
        category_name: selected?.name || null,
        category_slug: selected?.slug || null,
      } : item));
    }
    setBusyExamId('');
  };

  const activeCategories = categories.filter((category) => category.is_active);

  return <AdminFrame title="Phiên bản đề thi">
    <p className="muted">Danh mục gắn với đề thi gốc, không gắn riêng từng phiên bản. Các đề cũ chưa được phân loại sẽ giữ giá trị trống cho đến khi Admin chọn.</p>
    {error && <div className="alert" role="alert">{error}</div>}
    {loading ? <div className="loading-line"><span className="spinner" /> Đang tải…</div> :
      items.length ? <div className="version-list">{items.map((item) => {
        const archivedCurrent = item.category_id && !activeCategories.some((category) => category.id === item.category_id);
        return <article className="version-row category-exam-row" key={item.exam_version_id}>
          <div className="category-exam-info">
            <b>{item.title}</b>
            <small>Phiên bản {item.version_no} · {item.question_count} câu · {item.duration_minutes} phút · {item.attempt_count} lượt làm</small>
            <small>Danh mục hiện tại: {item.category_name || 'Chưa phân loại'}</small>
          </div>
          <div className="category-exam-actions">
            <span className={'status ' + (item.status === 'published' ? 'published' : 'draft')}>{item.status === 'published' ? 'Đã xuất bản' : 'Bản nháp'}</span>
            <label className="category-inline-label">
              <span>Gán danh mục</span>
              <select
                className="category-select"
                value={item.category_id || ''}
                disabled={busyExamId === item.exam_id}
                onChange={(event) => assignCategory(item.exam_id, event.target.value)}
              >
                <option value="">Chưa phân loại</option>
                {archivedCurrent && <option value={item.category_id} disabled>{item.category_name || 'Danh mục đã ẩn'} (đã ẩn)</option>}
                {activeCategories.map((category) => <option value={category.id} key={category.id}>{category.name}</option>)}
              </select>
            </label>
          </div>
        </article>;
      })}</div> : <div className="empty-state">Chưa có phiên bản đề thi.</div>
    }
    <p className="migration-note"><a href="/legacy/index.html">Mở trình soạn đề hiện tại để tạo hoặc chỉnh sửa phiên bản</a></p>
  </AdminFrame>;
}

const emptyCategoryForm = {
  id: '',
  name: '',
  slug: '',
  description: '',
  parent_id: '',
  is_active: true,
  display_order: 0,
};

export function AdminCategoriesPage() {
  const [items, setItems] = useState([]);
  const [form, setForm] = useState(emptyCategoryForm);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const load = async () => {
    setLoading(true);
    const { data, error: rpcError } = await supabase.rpc('admin_list_exam_categories');
    if (rpcError) setError(rpcError.message);
    else { setItems(data || []); setError(''); }
    setLoading(false);
  };

  useEffect(() => { void load(); }, []);

  const edit = (category) => {
    setForm({
      id: category.id,
      name: category.name,
      slug: category.slug,
      description: category.description || '',
      parent_id: category.parent_id || '',
      is_active: category.is_active,
      display_order: category.display_order ?? 0,
    });
    setNotice('');
    setError('');
  };

  const save = async (event) => {
    event.preventDefault();
    setSaving(true);
    setError('');
    setNotice('');
    const { error: rpcError } = await supabase.rpc('admin_save_exam_category', {
      p_name: form.name,
      p_slug: form.slug,
      p_category_id: form.id || null,
      p_description: form.description,
      p_parent_id: form.parent_id || null,
      p_is_active: form.is_active,
      p_display_order: Number(form.display_order) || 0,
    });
    if (rpcError) setError(rpcError.message);
    else {
      setNotice(form.id ? 'Đã cập nhật danh mục.' : 'Đã tạo danh mục.');
      setForm(emptyCategoryForm);
      await load();
    }
    setSaving(false);
  };

  const toggleActive = async (category) => {
    const nextActive = !category.is_active;
    const action = nextActive ? 'kích hoạt' : 'ẩn';
    if (!window.confirm(`Xác nhận ${action} danh mục "${category.name}"?`)) return;
    setSaving(true);
    setError('');
    setNotice('');
    const { error: rpcError } = await supabase.rpc('admin_save_exam_category', {
      p_name: category.name,
      p_slug: category.slug,
      p_category_id: category.id,
      p_description: category.description || '',
      p_parent_id: category.parent_id || null,
      p_is_active: nextActive,
      p_display_order: Number(category.display_order) || 0,
    });
    if (rpcError) setError(rpcError.message);
    else { setNotice(nextActive ? 'Đã kích hoạt danh mục.' : 'Đã ẩn danh mục.'); await load(); }
    setSaving(false);
  };

  return <AdminFrame title="Quản lý danh mục đề thi">
    <p className="muted">Danh mục dùng để phân loại mục đích của đề (thi thử, kiểm tra, ôn tập…). Danh mục đã gán cho đề nên được ẩn thay vì xóa.</p>
    {error && <div className="alert" role="alert">{error}</div>}
    {notice && <div className="form-message" role="status">{notice}</div>}
    <form className="category-form form-stack" onSubmit={save}>
      <h2>{form.id ? 'Sửa danh mục' : 'Tạo danh mục mới'}</h2>
      <label>Tên danh mục
        <input required maxLength={120} value={form.name} onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))} placeholder="Ví dụ: Đề thi thử" />
      </label>
      <label>Slug
        <input required maxLength={120} pattern="[a-z0-9]+(-[a-z0-9]+)*" value={form.slug} onChange={(event) => setForm((current) => ({ ...current, slug: event.target.value }))} placeholder="de-thi-thu" />
      </label>
      <label>Mô tả
        <textarea rows={3} maxLength={500} value={form.description} onChange={(event) => setForm((current) => ({ ...current, description: event.target.value }))} placeholder="Mô tả ngắn về danh mục" />
      </label>
      <label>Danh mục cha
        <select value={form.parent_id} onChange={(event) => setForm((current) => ({ ...current, parent_id: event.target.value }))}>
          <option value="">Không có</option>
          {items.filter((category) => category.is_active && category.id !== form.id).map((category) => <option key={category.id} value={category.id}>{category.name}</option>)}
        </select>
      </label>
      <label>Thứ tự hiển thị
        <input type="number" min="0" max="10000" value={form.display_order} onChange={(event) => setForm((current) => ({ ...current, display_order: event.target.value }))} />
      </label>
      <label className="category-checkbox"><input type="checkbox" checked={form.is_active} onChange={(event) => setForm((current) => ({ ...current, is_active: event.target.checked }))} /> Đang hoạt động</label>
      <div className="user-actions">
        <button className="button primary" type="submit" disabled={saving}>{saving ? 'Đang lưu…' : form.id ? 'Lưu thay đổi' : 'Tạo danh mục'}</button>
        {form.id && <button className="button secondary" type="button" disabled={saving} onClick={() => { setForm(emptyCategoryForm); setError(''); setNotice(''); }}>Hủy sửa</button>}
      </div>
    </form>

    <section className="version-list category-list">
      <h2>Danh mục hiện có</h2>
      {loading ? <div className="loading-line"><span className="spinner" /> Đang tải danh mục…</div> :
        items.length ? items.map((category) => <article className="category-row" key={category.id}>
          <div>
            <b>{category.name}</b>
            <small>{category.slug} · {category.exam_count} đề được gán</small>
            {category.parent_id && <small>Danh mục con của: {items.find((parent) => parent.id === category.parent_id)?.name || 'Danh mục khác'}</small>}
            {category.description && <small>{category.description}</small>}
          </div>
          <div className="user-actions">
            <span className={'status ' + (category.is_active ? 'published' : 'draft')}>{category.is_active ? 'Đang hoạt động' : 'Đã ẩn'}</span>
            <button className="button secondary" type="button" disabled={saving} onClick={() => edit(category)}>Sửa</button>
            <button className="button secondary" type="button" disabled={saving} onClick={() => toggleActive(category)}>{category.is_active ? 'Ẩn' : 'Kích hoạt'}</button>
          </div>
        </article>) : <div className="empty-state">Chưa có danh mục nào.</div>
      }
    </section>
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
