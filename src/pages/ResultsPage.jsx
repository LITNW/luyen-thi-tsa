import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase.js';

let mathJaxPromise;
function loadMathJax() {
  if (window.MathJax?.typesetPromise) return Promise.resolve(window.MathJax);
  if (mathJaxPromise) return mathJaxPromise;
  window.MathJax = {
    tex: {
      inlineMath: [['$', '$'], ['\\(', '\\)']],
      displayMath: [['$$', '$$'], ['\\[', '\\]']],
      processEscapes: true,
    },
    svg: { fontCache: 'none', displayAlign: 'left' },
    options: { enableMenu: false, enableAssistiveMml: false, skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code', 'input'] },
    startup: { typeset: false },
  };
  mathJaxPromise = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-svg.js';
    script.async = true;
    script.onload = () => window.MathJax.startup.promise.then(() => resolve(window.MathJax)).catch(reject);
    script.onerror = () => { mathJaxPromise = null; reject(new Error('Không tải được MathJax.')); };
    document.head.appendChild(script);
  });
  return mathJaxPromise;
}

function MathContent({ children, className = '' }) {
  const ref = useRef(null);
  useEffect(() => {
    let active = true;
    loadMathJax().then((mj) => {
      if (active && ref.current) {
        mj.typesetClear([ref.current]);
        return mj.typesetPromise([ref.current]);
      }
    }).catch(() => {});
    return () => {
      active = false;
      if (window.MathJax?.typesetClear && ref.current) window.MathJax.typesetClear([ref.current]);
    };
  }, [children]);
  return <div ref={ref} className={'math-content ' + className}>{children ?? ''}</div>;
}

function optionText(options, value) {
  const index = Number(value);
  if (!Number.isInteger(index) || index < 0 || index >= options.length) return String(value);
  return String.fromCharCode(65 + index) + '. ' + options[index];
}

function answerText(type, value, content, correct = false) {
  if (value == null || (Array.isArray(value) && value.every((item) => item == null)) || value === '') return 'Bỏ trống';
  const options = Array.isArray(content?.o) ? content.o : [];
  if (type === 'mc') return optionText(options, value);
  if (type === 'ms') return Array.isArray(value) ? value.map((item) => optionText(options, item)).join(' · ') : String(value);
  if (type === 'tf') return Array.isArray(value) ? value.map((item, index) => String.fromCharCode(97 + index) + ') ' + (item == null ? '—' : item ? 'Đúng' : 'Sai')).join(' · ') : String(value);
  if (type === 'num') return String(value).replace('.', ',');
  if (type === 'dnd') {
    const slots = [...String(content?.q || '').matchAll(/\[(\d+)\]/g)].map((match) => Number(match[1]));
    if (correct && typeof value === 'object' && !Array.isArray(value)) {
      return Object.entries(value).map(([slot, option]) => '[' + slot + '] → ' + optionText(options, Number(option) - 1)).join(' · ');
    }
    if (Array.isArray(value)) {
      return slots.map((slot) => {
        const option = value[slot - 1];
        return '[' + slot + '] → ' + (option == null ? '—' : optionText(options, option));
      }).join(' · ');
    }
    return String(value);
  }
  return typeof value === 'string' ? value : JSON.stringify(value);
}

function formatDuration(seconds) {
  const total = Math.max(0, Number(seconds) || 0);
  return Math.floor(total / 60) + ':' + String(total % 60).padStart(2, '0');
}

export default function ResultsPage() {
  const { attemptId } = useParams();
  const [attempt, setAttempt] = useState(null);
  const [exam, setExam] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    const load = async () => {
      setLoading(true);
      setError('');
      const { data: state, error: stateError } = await supabase.rpc('get_my_attempt_state', { p_attempt_id: attemptId });
      if (!active) return;
      if (stateError) {
        setError(stateError.message);
        setLoading(false);
        return;
      }
      setAttempt(state);
      if (state?.status === 'submitted' && state.exam_version_id) {
        const { data: examData, error: examError } = await supabase.rpc('get_published_exam', { p_exam_version_id: state.exam_version_id });
        if (!active) return;
        if (examError) setError('Đã tải được điểm nhưng chưa tải được nội dung đề: ' + examError.message);
        else setExam(examData);
      }
      setLoading(false);
    };
    void load();
    return () => { active = false; };
  }, [attemptId]);

  const resultRows = useMemo(() => {
    if (!attempt || !exam) return [];
    const results = attempt.result_details || [];
    const times = attempt.question_times || [];
    return (exam.questions || []).map((question, index) => {
      const position = Number(question.position || index + 1);
      const result = results.find((item) => Number(item.position) === position) || {};
      const time = times.find((item) => item.exam_version_question_id === question.id);
      return { question, result, seconds: Number(time?.seconds_spent) || 0 };
    });
  }, [attempt, exam]);

  const summary = useMemo(() => resultRows.reduce((total, row) => {
    const { answer, is_correct: isCorrect, earned_points: earned } = row.result;
    const answered = answer != null && answer !== '' && (!Array.isArray(answer) || answer.some((item) => item != null));
    if (!answered) total.blank += 1;
    else if (isCorrect) total.correct += 1;
    else if (Number(earned) > 0) total.partial += 1;
    else total.wrong += 1;
    return total;
  }, { correct: 0, partial: 0, wrong: 0, blank: 0 }), [resultRows]);

  return (
    <div className="app-shell">
      <header className="topbar">
        <Link to="/" className="brand-lockup"><span className="brand-mark small-mark">T</span><span><b>TSA Practice</b><small>KẾT QUẢ LUYỆN TẬP</small></span></Link>
        <nav className="top-links"><Link to="/history">Lịch sử</Link><Link to="/">Trang chủ</Link></nav>
      </header>
      <main className="narrow-page result-page">
        <p className="eyebrow">EXAM RESULTS</p>
        <h1>Kết quả bài làm</h1>
        {loading ? <div className="loading-line"><span className="spinner" /> Đang tải kết quả từ máy chủ…</div> :
          error && !attempt ? <div className="alert" role="alert">{error}</div> :
          attempt?.status !== 'submitted' ? <section className="account-card">
            <h2>{attempt?.status === 'in_progress' ? 'Lượt làm vẫn đang diễn ra' : 'Lượt làm chưa có kết quả'}</h2>
            <p className="muted">Trạng thái hiện tại: {attempt?.status || 'không xác định'}.</p>
            {attempt?.exam_version_id && attempt.status === 'in_progress' && <a className="button primary full" href={'/exam/' + encodeURIComponent(attempt.exam_version_id)}>Tiếp tục làm bài</a>}
          </section> :
          <>
            {error && <div className="alert" role="alert">{error}</div>}
            <section className="result-summary">
              <div className="result-score"><b>{attempt.score} / {attempt.max_score}</b><span>Điểm</span></div>
              <div><b>{summary.correct}</b><span>Đúng hoàn toàn</span></div>
              <div><b>{summary.partial}</b><span>Đúng một phần</span></div>
              <div><b>{summary.wrong}</b><span>Sai</span></div>
              <div><b>{summary.blank}</b><span>Bỏ trống</span></div>
              <div><b>{formatDuration(attempt.elapsed_seconds)}</b><span>Thời gian</span></div>
            </section>
            <h2 className="result-exam-title">{exam?.title || 'Chi tiết bài làm'}</h2>
            {resultRows.map(({ question, result, seconds }, index) => {
              const content = question.content || {};
              const earned = Number(result.earned_points) || 0;
              const points = Number(result.points ?? question.points) || 0;
              const partial = earned > 0 && !result.is_correct;
              const answered = result.answer != null && result.answer !== '';
              return <article className={'result-question ' + (result.is_correct ? 'correct' : partial ? 'partial' : 'incorrect')} key={question.id || index}>
                <div className="result-question-head"><b>Câu {Number(question.position || index + 1)}</b><span>{question.type} · {earned}/{points} điểm · {seconds}s</span></div>
                <MathContent className="question-content">{content.q}</MathContent>
                {Array.isArray(content.o) && content.o.length > 0 && <ol className="question-options" type={question.type === 'tf' ? 'a' : 'A'}>
                  {content.o.map((option, optionIndex) => <li key={optionIndex}><MathContent>{option}</MathContent></li>)}
                </ol>}
                <div className="answer-box"><b>Bạn trả lời</b><MathContent>{answerText(question.type, result.answer, content)}</MathContent></div>
                {!result.is_correct && <div className="answer-box correct-answer"><b>Đáp án đúng</b><MathContent>{answerText(question.type, result.correct_answer, content, true)}</MathContent></div>}
                {result.explanation && <div className="explanation"><b>Giải thích</b><MathContent>{result.explanation}</MathContent></div>}
                {!answered && <span className="muted small">Câu hỏi bị bỏ trống.</span>}
              </article>;
            })}
          </>
        }
      </main>
      <footer className="footer">TSA PRACTICE PLATFORM</footer>
    </div>
  );
}
