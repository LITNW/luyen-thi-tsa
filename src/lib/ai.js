import { supabase } from './supabase.js';

const ERROR_MESSAGES = {
  ai_gateway_disabled: 'Dịch vụ AI hiện chưa được bật.',
  unauthorized: 'Bạn cần đăng nhập để sử dụng AI.',
  invalid_session: 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.',
  admin_required: 'Tính năng AI hiện chỉ dành cho quản trị viên đang hoạt động.',
  input_required: 'Nội dung yêu cầu không được để trống.',
  input_too_large: 'Nội dung yêu cầu vượt quá giới hạn cho phép.',
  openai_rate_limited: 'Dịch vụ AI đang quá tải. Hãy thử lại sau.',
  openai_timeout: 'Dịch vụ AI phản hồi quá lâu. Hãy thử lại.',
  openai_unavailable: 'Không thể kết nối tới dịch vụ AI.',
};

export async function requestAiResponse(input) {
  if (!supabase) throw new Error('Supabase chưa được cấu hình.');
  if (typeof input !== 'string' || !input.trim()) {
    throw new Error(ERROR_MESSAGES.input_required);
  }

  const { data, error } = await supabase.auth.getSession();
  if (error) throw new Error('Không thể kiểm tra phiên đăng nhập.');
  const accessToken = data.session?.access_token;
  if (!accessToken) throw new Error(ERROR_MESSAGES.unauthorized);

  const response = await fetch('/api/ai/respond', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({ input }),
    cache: 'no-store',
  });

  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const code = payload?.error?.code;
    throw new Error(ERROR_MESSAGES[code] || 'Không thể xử lý yêu cầu AI.');
  }

  if (typeof payload?.output_text !== 'string') {
    throw new Error('Dịch vụ AI trả về dữ liệu không hợp lệ.');
  }
  return payload;
}
