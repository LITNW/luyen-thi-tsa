import { useEffect, useMemo, useState } from 'react';
import {
  CONSENT_VERSION,
  DEFAULT_PRIVACY_PREFERENCES,
  readPrivacyPreferences,
  savePrivacyPreferences,
} from '../lib/privacy-consent.js';
import './privacy-consent.css';

const CATEGORIES = [
  { key: 'essential', title: 'Lưu trữ cần thiết', detail: 'Phục vụ đăng nhập, duy trì phiên, ghi nhớ lựa chọn bảo mật và vận hành chức năng cốt lõi. Luôn bật.' , locked: true },
  { key: 'security', title: 'Bảo mật và chống gian lận', detail: 'Hỗ trợ phát hiện truy cập bất thường, bảo vệ phiên và ngăn hành vi lạm dụng. Không dùng cho quảng cáo.', locked: true },
  { key: 'preferences', title: 'Tùy chọn người dùng', detail: 'Ghi nhớ các tùy chọn giao diện không nhạy cảm như chế độ hiển thị và cỡ chữ.' },
  { key: 'pageState', title: 'Duy trì trạng thái trang', detail: 'Ghi nhớ trạng thái điều hướng và thao tác tạm thời để bạn tiếp tục công việc trên cùng thiết bị.' },
  { key: 'analytics', title: 'Phân tích và đo lường hiệu suất', detail: 'Đo lường mức độ ổn định và hiệu suất. Hiện LIT chưa kích hoạt nhà cung cấp phân tích; mục này đang tắt.' , unavailable: true },
];

export default function PrivacyConsentManager() {
  const initial = useMemo(() => readPrivacyPreferences(), []);
  const [preferences, setPreferences] = useState(initial.categories);
  const [hasDecision, setHasDecision] = useState(Boolean(initial.updatedAt));
  const [open, setOpen] = useState(!initial.updatedAt);
  const [details, setDetails] = useState(false);
  const [savedMessage, setSavedMessage] = useState('');

  useEffect(() => {
    const openSettings = () => { setOpen(true); setDetails(true); };
    window.addEventListener('lit:privacy-settings', openSettings);
    return () => window.removeEventListener('lit:privacy-settings', openSettings);
  }, []);

  const save = (choices) => {
    const result = savePrivacyPreferences(undefined, choices);
    setPreferences(result.categories);
    setHasDecision(true);
    setOpen(false);
    setDetails(false);
    setSavedMessage(result.persisted ? 'Đã lưu lựa chọn quyền riêng tư trên thiết bị này.' : 'Trình duyệt không cho phép lưu lựa chọn. Các mục không thiết yếu vẫn được giữ tắt.');
    window.setTimeout(() => setSavedMessage(''), 5000);
    window.dispatchEvent(new CustomEvent('lit:privacy-preferences-changed', { detail: result.categories }));
  };

  const update = (key, value) => setPreferences((current) => ({ ...current, [key]: value }));
  const optionalChoices = () => ({
    preferences: preferences.preferences,
    pageState: preferences.pageState,
    analytics: false,
  });

  return (
    <>
      {!open && (
        <div className="lit-privacy-launcher">
          <button type="button" onClick={() => { setOpen(true); setDetails(true); }} aria-label="Mở cài đặt quyền riêng tư">Quyền riêng tư</button>
        </div>
      )}
      {open && (
        <div className="lit-privacy-backdrop" role="presentation">
          <section className="lit-privacy-panel" role="dialog" aria-modal="true" aria-labelledby="lit-privacy-title">
            <div className="lit-privacy-heading">
              <div>
                <p className="lit-privacy-eyebrow">LIT · QUYỀN RIÊNG TƯ</p>
                <h2 id="lit-privacy-title">{hasDecision ? 'Cài đặt Cookie và lưu trữ' : 'LIT sử dụng Cookie và bộ nhớ trình duyệt'}</h2>
              </div>
              {hasDecision && <button className="lit-privacy-close" type="button" onClick={() => setOpen(false)} aria-label="Đóng cài đặt">×</button>}
            </div>
            <p className="lit-privacy-copy">LIT sử dụng một số công nghệ lưu trữ trên thiết bị để duy trì phiên, bảo vệ tài khoản và ghi nhớ trạng thái học tập. Bạn có thể chọn các mục không thiết yếu. Việc từ chối hoặc đóng thông báo không được xem là đồng ý.</p>
            <div className="lit-privacy-list">
              {CATEGORIES.map((category) => (
                <div className="lit-privacy-category" key={category.key}>
                  <div className="lit-privacy-category-copy">
                    <strong>{category.title}</strong>
                    <p>{category.detail}</p>
                  </div>
                  <label className="lit-privacy-toggle">
                    <input
                      type="checkbox"
                      checked={category.locked ? true : Boolean(preferences[category.key])}
                      disabled={category.locked || category.unavailable}
                      onChange={(event) => update(category.key, event.target.checked)}
                      aria-label={category.title}
                    />
                    <span>{category.locked ? 'Luôn bật' : category.unavailable ? 'Chưa khả dụng' : preferences[category.key] ? 'Bật' : 'Tắt'}</span>
                  </label>
                </div>
              ))}
            </div>
            <details className="lit-privacy-details" open={details} onToggle={(event) => setDetails(event.currentTarget.open)}>
              <summary>Thông tin về dữ liệu được lưu</summary>
              <p>Supabase Auth hiện duy trì phiên đăng nhập bằng bộ nhớ trình duyệt của SDK; LIT chưa triển khai cookie phiên HttpOnly do máy chủ thiết lập. Tùy chọn quyền riêng tư được lưu cục bộ. Trạng thái trang và bản nháp tạm thời chỉ được lưu khi chức năng tương ứng được triển khai và lựa chọn có hiệu lực. Dữ liệu bài thi đã nộp, kết quả, hồ sơ và bằng chứng đồng ý vẫn do máy chủ quản lý.</p>
              <p>Lựa chọn này được lưu trên thiết bị bằng localStorage, có phiên bản và thời điểm cập nhật. Xóa dữ liệu trình duyệt có thể xóa lựa chọn này. Không lưu mật khẩu, token xác thực hoặc bằng chứng đồng ý trong localStorage.</p>
              <p>Liên hệ quyền riêng tư: <a href="mailto:lit.privacy.vn@gmail.com">lit.privacy.vn@gmail.com</a>. Phiên bản lựa chọn: {CONSENT_VERSION}.</p>
            </details>
            <div className="lit-privacy-actions">
              <button type="button" className="lit-privacy-secondary" onClick={() => save({ ...DEFAULT_PRIVACY_PREFERENCES.categories, preferences: false, pageState: false, analytics: false })}>Từ chối mục không thiết yếu</button>
              <button type="button" className="lit-privacy-secondary" onClick={() => save(optionalChoices())}>Lưu lựa chọn</button>
              <button type="button" className="lit-privacy-primary" onClick={() => save({ ...optionalChoices(), preferences: true, pageState: true })}>Chấp nhận tùy chọn</button>
            </div>
            <p className="lit-privacy-footnote">Các mục cần thiết và bảo mật luôn bật. Phân tích hiệu suất chưa được kích hoạt và không được bật qua bảng này.</p>
          </section>
        </div>
      )}
      {savedMessage && <div className="lit-privacy-toast" role="status">{savedMessage}</div>}
    </>
  );
}
