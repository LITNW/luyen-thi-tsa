import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase.js';

function duration(seconds = 0) {
  const value = Math.max(0, Number(seconds) || 0);
  return Math.floor(value / 60) + ':' + String(Math.floor(value % 60)).padStart(2, '0');
}

const statusText = {
  submitted: 'Đã nộp',
  in_progress: 'Đang làm',
  abandoned: 'Đã kết thúc',
};

export default function HistoryPage() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    const load = async () => {
      const { data, error: rpcError } = await supabase.rpc('get_my_attempt_history', {
        p_limit: 100,
        p_offset: 0,
      });
      if (!active) return;
      if (rpcError) setError('Không tải được lịch sử: ' + rpcError.message);
      else setItems(data || []);
      setLoading(false);
    };
    void load();
    return () => { active = false; };
  }, []);

  return (
    <div className="app-shell">
      <header className="topbar">
        <Link to="/" className="brand-lockup"><span className="brand-mark small-mark">T</span><span><b>TSA Practice</b><small>LUYỆN THI ĐÁNH GIÁ TƯ DUY</small></span></Link>
        <nav className="top-links"><Link to="/">Trang chủ</Link><Link to="/account">Tài khoản</Link></nav>
      </header>
      <main className="narrow-page">
        <p className="eyebrow">LEARNING HISTORY</p>
        <h1>Lịch sử làm bài</h1>
        <p className="muted">Danh sách lượt làm được lấy từ máy chủ. Kết quả và trạng thái gốc không bị thay đổi bởi giao diện React.</p>
        {error && <div className="alert" role="alert">{error}</div>}
        {loading ? <div className="loading-line"><span className="spinner" /> Đang tải lịch sử…</div> :
          items.length ? <div className="history-list">{items.map((item) => <article className="history-card exam-card" key={item.attempt_id}>
            <div className="card-top"><span className="eyebrow">PHIÊN BẢN {item.version_no}</span><span className={'status ' + (item.status === 'submitted' ? 'published' : item.status === 'in_progress' ? 'draft' : '')}>{statusText[item.status] || item.status}</span></div>
            <h2>{item.title}</h2>
            <p className="muted">{item.started_at ? new Date(item.started_at).toLocaleString('vi-VN') : 'Không có thời gian bắt đầu'}</p>
            <div className="exam-meta">
              {item.status === 'submitted' && <b>{item.score} / {item.max_score} điểm</b>}
              <span>Thời gian: {duration(item.elapsed_seconds)}</span>
            </div>
            {item.status === 'in_progress' && item.exam_version_id && <a className="button primary full" href={'/exam/' + encodeURIComponent(item.exam_version_id)}>Tiếp tục làm bài <span aria-hidden="true">→</span></a>}
            {item.status === 'submitted' && item.attempt_id && <Link className="button secondary full" to={'/results/' + encodeURIComponent(item.attempt_id)}>Xem chi tiết kết quả</Link>}
          </article>)}</div> :
          <div className="empty-state"><b>Chưa có lượt làm bài nào</b><p>Khi bạn bắt đầu một đề thi, lịch sử sẽ xuất hiện tại đây.</p></div>
        }
      </main>
      <footer className="footer">TSA PRACTICE PLATFORM</footer>
    </div>
  );
}
