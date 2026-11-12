export function answerText(type, value, content = {}, correct = false) {
  if (value == null || (Array.isArray(value) && value.every((item) => item == null)) || value === '') return 'Bỏ trống';
  const options = Array.isArray(content?.o) ? content.o : [];
  const option = (item) => {
    const index = Number(item);
    if (!Number.isInteger(index) || index < 0 || index >= options.length) return String(item);
    return String.fromCharCode(65 + index) + '. ' + options[index];
  };
  if (type === 'mc') return option(value);
  if (type === 'ms') return Array.isArray(value) ? value.map(option).join(' · ') : String(value);
  if (type === 'tf') return Array.isArray(value)
    ? value.map((item, index) => String.fromCharCode(97 + index) + ') ' + (item == null ? '—' : item ? 'Đúng' : 'Sai')).join(' · ')
    : String(value);
  if (type === 'num') return String(value).replace('.', ',');
  if (type === 'dnd') {
    const slots = [...String(content?.q || '').matchAll(/\[(\d+)\]/g)].map((match) => Number(match[1]));
    if (correct && typeof value === 'object' && !Array.isArray(value)) {
      return Object.entries(value).map(([slot, selected]) => '[' + slot + '] → ' + option(Number(selected) - 1)).join(' · ');
    }
    if (Array.isArray(value)) {
      return slots.map((slot) => {
        const selected = value[slot - 1];
        return '[' + slot + '] → ' + (selected == null ? '—' : option(selected));
      }).join(' · ');
    }
    return String(value);
  }
  return typeof value === 'string' ? value : JSON.stringify(value);
}

export function formatDuration(seconds = 0) {
  const total = Math.max(0, Number(seconds) || 0);
  return Math.floor(total / 60) + ':' + String(Math.floor(total % 60)).padStart(2, '0');
}

export function summarizeResults(rows = []) {
  return rows.reduce((total, row) => {
    const { answer, is_correct: isCorrect, earned_points: earned } = row.result || {};
    const answered = answer != null && answer !== '' && (!Array.isArray(answer) || answer.some((item) => item != null));
    if (!answered) total.blank += 1;
    else if (isCorrect) total.correct += 1;
    else if (Number(earned) > 0) total.partial += 1;
    else total.wrong += 1;
    return total;
  }, { correct: 0, partial: 0, wrong: 0, blank: 0 });
}
