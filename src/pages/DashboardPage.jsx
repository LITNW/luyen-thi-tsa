import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext.jsx';
import { supabase } from '../lib/supabase.js';

export default function DashboardPage() {
  const { profile, isAdmin } = useAuth();
  const [exams, setExams] = useState([]);
  const [versions, setVersions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    const load = async () => {
      setLoading(true);
      setError('');
      const { data, error: examError } = await supabase.rpc('list_published_exams');
      if (!active) return;
      if (examError) {
        setError('Không tải được danh sách đề thi: ' + examError.message);
        setExams([]);
      } else {
        setExams((data || []).map((item) => ({
          id: item.id,
          title: item.title,
          description: item.description || '',
          duration: item.duration_minutes,
          version: item.version_no,
          questionCount: item.question_count,
        })));
      }

      if (isAdmin) {
        const { data: adminData, error: adminError } = await supabase.rpc('admin_list_exam_versions');
        if (!active) return;
        if (adminError) {
          setError((current) => [current, 'Không tải được danh sách quản trị: ' + adminError.message].filter(Boolean).join(' · '));
        } else {
          setVersions(adminData || []);
        }
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
        <Link to="/" className="brand-lockup"><span className="brand-mark small-mark">T</span><span><b>TSA Practice</b><small>LUYỆN THI ĐÁNH GIÁ TƯ DUY</small></span></Link>
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
            <h1>Hôm nay, bạn muốn<br /><span>chinh phục thử thách nào?</span></h1>
            <p>Xin chào {profile?.display_name || 'học viên'}. Chọn đề thi để bắt đầu rèn luyện tư duy.</p>
          </div>
          <div className="hero-mark" aria-hidden="true"><span>TSA</span></div>
        </section>

        <section className="metrics" aria-label="Thông tin tài khoản">
          <article className="metric"><span>01</span><div><b>{exams.length}</b><small>Đề thi khả dụng</small></div></article>
          <article className="metric"><span>02</span><div><b>{profile?.user_code || '—'}</b><small>Mã học viên</small></div></article>
          <article className="metric"><span>03</span><div><b>{isAdmin ? 'Quản trị viên' : 'Học viên'}</b><small>Vai trò tài khoản</small></div></article>
        </section>

        {error && <div className="alert" role="alert">{error}</div>}

        {isAdmin && (
          <section className="section-block">
            <div className="section-heading"><div><p className="eyebrow">WORKSPACE</p><h2>Khu vực quản trị</h2></div><span className="role-chip">ADMIN</span></div>
            <div className="admin-grid">
              <Link className="admin-card featured" to="/admin/exams"><b>Quản lý đề thi</b><span>Phiên bản, trạng thái và lượt làm</span></Link>
              <Link className="admin-card" to="/admin/users"><b>Quản lý tài khoản</b><span>Vai trò và trạng thái người dùng</span></Link>
              <Link className="admin-card" to="/admin/attempts"><b>Theo dõi lượt làm</b><span>Kết quả và thời gian làm bài</span></Link>
            </div>
            {versions.length > 0 && <div className="version-list">
              <h3>Phiên bản đề thi</h3>
              {versions.map((item) => <article className="version-row" key={item.exam_version_id}>
                <div><b>{item.title}</b><small>Phiên bản {item.version_no} · {item.question_count} câu · {item.attempt_count} lượt làm</small></div>
                <span className={item.status === 'published' ? 'status published' : 'status draft'}>{item.status === 'published' ? 'Đã xuất bản' : 'Bản nháp'}</span>
              </article>)}
            </div>}
          </section>
        )}

        <section className="section-block">
          <div className="section-heading"><div><p className="eyebrow">EXAM LIBRARY</p><h2>Đề thi đã xuất bản</h2><p className="muted">Các bài luyện tập hiện có trên hệ thống.</p></div></div>
          {loading ? <div className="loading-line"><span className="spinner" /> Đang tải danh sách đề thi…</div> :
            exams.length ? <div className="exam-grid">{exams.map((exam, index) => <article className="exam-card" key={exam.id}>
              <div className="card-top"><span className="eyebrow">ĐỀ LUYỆN TẬP {String(index + 1).padStart(2, '0')}</span><span className="status published">Sẵn sàng</span></div>
              <h3>{exam.title}</h3>
              <p className="muted">{exam.description || 'Bài luyện tập đánh giá tư duy TSA.'}</p>
              <div className="exam-meta"><span>{exam.duration} phút</span><span>{exam.questionCount || 0} câu hỏi</span><span>Phiên bản {exam.version}</span></div>
              <a className="button primary full" href={'/exam/' + encodeURIComponent(exam.id)}>Bắt đầu làm bài <span aria-hidden="true">→</span></a>
            </article>)}</div> :
            <div className="empty-state"><b>Chưa có đề thi được xuất bản</b><p>Các đề luyện tập sẽ xuất hiện tại đây khi quản trị viên đăng tải.</p></div>
          }
        </section>
        <div className="migration-note"><b>Chuyển đổi theo từng module</b><p>Đăng nhập, bảng điều khiển, lịch sử và các màn hình quản trị cơ bản đã chuyển sang React. Phòng thi, trình soạn đề và nhập đề AI vẫn được giữ nguyên trong giao diện cũ cho đến khi phiên bản mới được kiểm thử đầy đủ.</p><a href="/legacy/index.html">Mở toàn bộ giao diện hiện tại</a></div>
      </main>
      <footer className="footer">TSA PRACTICE PLATFORM <span>Học tập có chiến lược · Tiến bộ mỗi ngày</span></footer>
    </div>
  );
}
