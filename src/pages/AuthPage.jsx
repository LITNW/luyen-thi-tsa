import { useEffect, useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext.jsx';

export default function AuthPage({ mode = 'login' }) {
  const isRegister = mode === 'register';
  const { session, loading, error: configError, signIn, signUp } = useAuth();
  const navigate = useNavigate();
  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (session) navigate('/', { replace: true });
  }, [session, navigate]);

  if (loading) return <main className="center-state"><span className="spinner" /><p>Đang kiểm tra phiên đăng nhập…</p></main>;
  if (session) return <Navigate to="/" replace />;

  const submit = async (event) => {
    event.preventDefault();
    setMessage('');
    setBusy(true);
    try {
      if (isRegister) {
        const data = await signUp({ displayName, email: email.trim(), password });
        if (!data.session) {
          setMessage('Đã tạo yêu cầu đăng ký. Hãy mở email xác minh, sau đó đăng nhập.');
        }
      } else {
        await signIn(email.trim(), password);
      }
    } catch (error) {
      setMessage(error?.message || 'Không thể hoàn tất thao tác.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="auth-layout">
      <section className="auth-story">
        <div className="brand-lockup"><span className="brand-mark">T</span><span><b>TSA Practice</b><small>NỀN TẢNG LUYỆN THI ĐÁNH GIÁ TƯ DUY</small></span></div>
        <p className="eyebrow">TSA PRACTICE PLATFORM</p>
        <h1>Chuẩn bị tốt hơn.<br /><span>Bứt phá giới hạn.</span></h1>
        <p className="story-copy">Không gian luyện tập tập trung cho kỳ thi Đánh giá tư duy: làm bài có thời gian, theo dõi tiến độ và xem lại kết quả.</p>
        <div className="story-points"><span><b>01</b> Luyện tập theo đề thi</span><span><b>02</b> Chấm điểm tự động</span><span><b>03</b> Lưu lịch sử học tập</span></div>
      </section>
      <section className="auth-panel">
        <p className="eyebrow">BẮT ĐẦU HỌC TẬP</p>
        <h2>{isRegister ? 'Tạo tài khoản học sinh' : 'Chào mừng trở lại'}</h2>
        <p className="muted">{isRegister ? 'Tạo tài khoản để lưu tiến độ và kết quả luyện tập.' : 'Đăng nhập để tiếp tục hành trình ôn luyện.'}</p>
        {configError && <div className="alert" role="alert">{configError}</div>}
        <form onSubmit={submit} className="form-stack">
          {isRegister && <label>Tên hiển thị<input value={displayName} onChange={(e) => setDisplayName(e.target.value)} maxLength={80} autoComplete="name" required /></label>}
          <label>Email<input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete={isRegister ? 'email' : 'username'} required /></label>
          <label>Mật khẩu<input type="password" value={password} onChange={(e) => setPassword(e.target.value)} minLength={8} autoComplete={isRegister ? 'new-password' : 'current-password'} required /></label>
          <button className="button primary full" type="submit" disabled={busy}>{busy ? 'Đang xử lý…' : isRegister ? 'Đăng ký tài khoản' : 'Đăng nhập'}</button>
        </form>
        {message && <p className="form-message" role="status">{message}</p>}
        <div className="auth-switch">{isRegister ? 'Đã có tài khoản?' : 'Chưa có tài khoản?'} <Link to={isRegister ? '/login' : '/register'}>{isRegister ? 'Đăng nhập' : 'Tạo tài khoản'}</Link></div>
        <p className="muted small">Bản React đang được chuyển đổi theo từng module. Phòng thi và các công cụ quản trị hiện vẫn có thể mở từ giao diện hiện tại.</p>
      </section>
    </main>
  );
}
