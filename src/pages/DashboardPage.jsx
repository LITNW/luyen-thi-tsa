import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext.jsx';
import { supabase } from '../lib/supabase.js';

export default function DashboardPage() {
  const { profile, isAdmin } = useAuth();
  const [levels, setLevels] = useState([]);
  const [versions, setVersions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    const load = async () => {
      setLoading(true);
      setError('');
      const { data: levelData, error: levelError } = await supabase
        .from('education_levels')
        .select('id,code,name,description,display_order')
        .eq('is_active', true)
        .order('display_order')
        .order('name');
      if (!active) return;
      if (levelError) {
        setError('Không tải được danh mục cấp học: ' + levelError.message);
        setLevels([]);
      } else {
        setLevels(levelData || []);
      }

      if (isAdmin) {
        const { data: adminData, error: adminError } = await supabase.rpc('admin_list_exam_versions');
        if (!active) return;
        if (adminError) setError((current) => [current, 'Không tải được danh sách quản trị: ' + adminError.message].filter(Boolean).join(' · '));
        else setVersions(adminData || []);
      } else {
        setVersions([]);
      }
      if (active) setLoading(false);
    };
    void load();
    return () => { active = false; };
  }, [isAdmin]);

  return (
    <div className="app-shell">
      <header className="topbar">
        <Link to="/" className="brand-lockup"><span className="brand-mark small-mark">T</span><span><b>TSA Practice</b><small>NỀN TẢNG LUYỆN THI</small></span></Link>
        <nav className="top-links" aria-label="Điều hướng chính">
          <Link to="/history">Lịch sử</Link>
          <Link to="/account">Tài khoản</Link>
          {isAdmin && <Link to="/admin">Quản trị</Link>}
        </nav>
      </header>

      <main className="dashboard">
        <section className="hero">
          <div>
            <p className="eyebrow">KHÔNG GIAN HỌC TẬP CỦA BẠN</p>
            <h1>Hôm nay, bạn muốn<br /><span>học tập và thử sức ở đâu?</span></h1>
            <p>Xin chào {profile?.display_name || 'học viên'}. Chọn cấp học để tìm môn học và bài thi phù hợp.</p>
          </div>
          <div className="hero-mark" aria-hidden="true"><span>TSA</span></div>
        </section>

        <section className="metrics" aria-label="Thông tin tài khoản">
          <article className="metric"><span>01</span><div><b>{levels.length}</b><small>Cấp học khả dụng</small></div></article>
          <article className="metric"><span>02</span><div><b>{profile?.user_code || '—'}</b><small>Mã học viên</small></div></article>
          <article className="metric"><span>03</span><div><b>{isAdmin ? 'Quản trị viên' : 'Học viên'}</b><small>Vai trò tài khoản</small></div></article>
        </section>

        {error && <div className="alert" role="alert">{error}</div>}

        {isAdmin && (
          <section className="section-block">
            <div className="section-heading"><div><p className="eyebrow">WORKSPACE</p><h2>Khu vực quản trị</h2></div><span className="role-chip">ADMIN</span></div>
            <div className="admin-grid">
              <Link className="admin-card featured" to="/admin/education"><b>Cấu trúc học tập</b><span>Quản lý cấp học, ngữ cảnh và môn học</span></Link>
              <Link className="admin-card" to="/admin/exams"><b>Quản lý đề thi</b><span>Phiên bản, trạng thái, vị trí học tập và loại đề</span></Link>
              <Link className="admin-card" to="/admin/users"><b>Quản lý tài khoản</b><span>Vai trò và trạng thái người dùng</span></Link>
              <Link className="admin-card" to="/admin/attempts"><b>Theo dõi lượt làm</b><span>Kết quả và thời gian làm bài</span></Link>
              <Link className="admin-card" to="/admin/categories"><b>Loại đề (tùy chọn)</b><span>Phân loại mục đích đề, không ảnh hưởng điều hướng</span></Link>
              <a className="admin-card" href="/legacy/index.html"><b>Trình soạn đề & nhập AI</b><span>Mở công cụ hiện tại trong giai đoạn chuyển đổi</span></a>
            </div>
            {versions.length > 0 && <div className="version-list">
              <h3>Phiên bản đề thi gần đây</h3>
              {versions.slice(0, 5).map((item) => <article className="version-row" key={item.exam_version_id}>
                <div><b>{item.title}</b><small>Phiên bản {item.version_no} · {item.question_count} câu · {item.attempt_count} lượt làm</small></div>
                <span className={item.status === 'published' ? 'status published' : 'status draft'}>{item.status === 'published' ? 'Đã xuất bản' : 'Bản nháp'}</span>
              </article>)}
            </div>}
          </section>
        )}

        <section className="section-block">
          <div className="section-heading"><div><p className="eyebrow">CHỌN CẤP HỌC</p><h2>Bạn muốn luyện thi ở cấp học nào?</h2><p className="muted">Các môn học và bài thi được sắp xếp theo cấp học, không hiển thị dàn trải trên trang chủ.</p></div></div>
          {loading ? <div className="loading-line"><span className="spinner" /> Đang tải cấp học…</div> :
            levels.length ? <div className="education-level-grid">{levels.map((level) => <Link className="education-level-card" to={'/education/' + encodeURIComponent(level.code)} key={level.id}>
              <span className="education-level-mark">{level.code === 'thpt' ? 'THPT' : level.code === 'university' ? 'ĐH' : level.code.slice(0, 3).toUpperCase()}</span>
              <div><b>{level.name}</b><small>{level.description || 'Chọn để xem các môn học và bài thi'}</small></div>
              <span className="education-arrow" aria-hidden="true">→</span>
            </Link>)}</div> :
            <div className="empty-state"><b>Chưa có cấp học khả dụng</b><p>Quản trị viên cần thiết lập cấp học trước khi thêm môn học và bài thi.</p></div>
          }
        </section>
      </main>
      <footer className="footer">TSA PRACTICE PLATFORM <span>Học tập có chiến lược · Tiến bộ mỗi ngày</span></footer>
    </div>
  );
}
