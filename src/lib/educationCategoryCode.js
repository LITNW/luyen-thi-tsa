export const EDUCATION_CATEGORY_CODE_PATTERN = '[a-z][a-z0-9_]{1,63}';
export const EDUCATION_CATEGORY_CODE_HELP = '2–64 ký tự; bắt đầu bằng a–z; các ký tự còn lại chỉ gồm a–z, 0–9 và dấu gạch dưới (_).';

const educationCategoryCodeRegex = /^[a-z][a-z0-9_]{1,63}$/;

export function isValidEducationCategoryCode(value) {
  return typeof value === 'string'
    && value.length <= 64
    && !/[\r\n]/.test(value)
    && educationCategoryCodeRegex.test(value);
}
