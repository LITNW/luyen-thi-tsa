import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const authPage = readFileSync(new URL('../src/pages/AuthPage.jsx', import.meta.url), 'utf8');
const authContext = readFileSync(new URL('../src/context/AuthContext.jsx', import.meta.url), 'utf8');
const legacy = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');

test('React authentication errors use user-facing copy without configuration details', () => {
  assert.match(authContext, /error: 'Dịch vụ đăng nhập hiện chưa sẵn sàng\. Vui lòng thử lại sau\.'/);
  assert.doesNotMatch(authContext, /VITE_SUPABASE_URL|VITE_SUPABASE_PUBLISHABLE_KEY/);
});

test('authentication pages do not expose internal migration status', () => {
  assert.doesNotMatch(authPage, /Bản React đang được chuyển đổi theo từng module/);
});

test('Legacy authentication reports service availability in user-facing language', () => {
  assert.match(legacy, /if\(!sb\)\{notify\('Dịch vụ đăng nhập hiện chưa sẵn sàng\. Vui lòng thử lại sau\.'\);return\}/);
  assert.doesNotMatch(legacy, /Không tải được thư viện kết nối Supabase/);
});
