import { Link } from 'react-router-dom';

const features = [
  { number: '01', title: 'Chọn đúng nội dung', description: 'Đi từ cấp học đến ngữ cảnh và môn học để tìm nội dung phù hợp.' },
  { number: '02', title: 'Luyện tập có trọng tâm', description: 'Tập trung vào mục tiêu học tập trong một trải nghiệm làm bài nhất quán.' },
  { number: '03', title: 'Hiểu kết quả', description: 'Xem lại lịch sử, kết quả và chi tiết bài làm trong cùng một hệ thống.' },
];

export default function PublicLandingPage() {
  return (
    <div className="lit-landing">
      <header className="lit-public-header">
        <div className="lit-container lit-header-inner">
          <Link to="/" className="lit-brand" aria-label="LIT — Trang chủ">
            <img src="/brand/lit-horizontal.svg" alt="LIT — Learn, Practice, Grow" />
          </Link>
          <nav className="lit-public-nav" aria-label="Điều hướng chính">
            <a href="#how-it-works">Cách LIT hoạt động</a>
            <Link className="lit-nav-login" to="/login">Đăng nhập</Link>
            <Link className="lit-button lit-button-primary" to="/register">Bắt đầu học tập</Link>
          </nav>
        </div>
      </header>

      <main>
        <section className="lit-hero">
          <div className="lit-container lit-hero-grid">
            <div className="lit-hero-copy">
              <p className="lit-eyebrow">LEARNING · PRACTICE · PROGRESS</p>
              <h1>Học có định hướng.<br /><span>Tiến bộ có cơ sở.</span></h1>
              <p className="lit-lead">LIT mang đến không gian luyện tập tập trung, giúp bạn chọn đúng nội dung học, thực hành theo mục tiêu và xem lại kết quả của mình.</p>
              <div className="lit-hero-actions">
                <Link className="lit-button lit-button-primary" to="/register">Tạo tài khoản <span aria-hidden="true">→</span></Link>
                <Link className="lit-button lit-button-secondary" to="/login">Tôi đã có tài khoản</Link>
              </div>
              <p className="lit-hero-note">Một không gian học tập rõ ràng, được tổ chức theo nội dung và mục tiêu của bạn.</p>
            </div>
            <div className="lit-hero-preview" aria-label="Minh họa quy trình học tập">
              <div className="lit-preview-top"><span>KHÔNG GIAN HỌC TẬP</span><span className="lit-chip">LIT Learning</span></div>
              <h2>Tiếp tục hành trình của bạn</h2>
              <div className="lit-preview-step"><span>01</span><div><b>Chọn cấp học và môn học</b><small>Nội dung được tổ chức theo ngữ cảnh</small></div></div>
              <div className="lit-preview-step"><span>02</span><div><b>Luyện tập theo đề</b><small>Tập trung vào mục tiêu của bạn</small></div></div>
              <div className="lit-preview-step"><span>03</span><div><b>Xem lại kết quả</b><small>Nhìn lại tiến độ và câu trả lời</small></div></div>
            </div>
          </div>
        </section>

        <section id="how-it-works" className="lit-section">
          <div className="lit-container">
            <p className="lit-eyebrow">A CLEAR LEARNING FLOW</p>
            <h2>Một quy trình học tập rõ ràng</h2>
            <p className="lit-section-lead">Tập trung vào hành động tiếp theo, không làm người học bị quá tải bởi quá nhiều lựa chọn cùng lúc.</p>
            <div className="lit-feature-grid">
              {features.map((feature) => (
                <article className="lit-feature-card" key={feature.number}>
                  <span>{feature.number} / {feature.number === '01' ? 'DISCOVER' : feature.number === '02' ? 'PRACTICE' : 'REVIEW'}</span>
                  <h3>{feature.title}</h3>
                  <p>{feature.description}</p>
                </article>
              ))}
            </div>
          </div>
        </section>
      </main>

      <footer className="lit-public-footer">
        <div className="lit-container">
          <img src="/brand/lit-horizontal.svg" alt="LIT" />
          <span>Learn · Practice · Grow</span>
        </div>
      </footer>
    </div>
  );
}
