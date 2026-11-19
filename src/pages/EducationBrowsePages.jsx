import { useEffect, useState } from 'react';
import { Link, Navigate, useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase.js';

function EducationFrame({ children }) {
  return <div className="app-shell"><header className="topbar"><Link to="/" className="brand-lockup" aria-label="LIT — Trang chủ"><img src="/brand/lit-horizontal.svg" alt="LIT" /></Link><nav className="top-links"><Link to="/history">Lịch sử</Link><Link to="/account">Tài khoản</Link></nav></header><main className="education-page">{children}</main><footer className="footer">LIT · LEARN · PRACTICE · GROW <span>Học tập có chiến lược · Tiến bộ mỗi ngày</span></footer></div>;
}
function Breadcrumbs({ items }) { return <nav className="education-breadcrumbs" aria-label="Đường dẫn">{items.map((item, index) => <span key={item.to || item.label}>{index > 0 && <i aria-hidden="true">/</i>}{item.to && index < items.length - 1 ? <Link to={item.to}>{item.label}</Link> : <b>{item.label}</b>}</span>)}</nav>; }
function State({ message, empty = false }) { return empty ? <div className="empty-state"><b>{message}</b><p>Quản trị viên chưa thiết lập nội dung học tập tại đây.</p></div> : <div className="alert" role="alert">{message}</div>; }
function CourseCard({ levelCode, course, group }) { return <Link className="education-card subject-card" to={`/education/${levelCode}/subject/${course.id}`}><span className="education-card-kicker">{group || 'MÔN HỌC'}</span><b>{course.display_name}</b><span>{course.description || course.local_code || 'Xem các bài thi thuộc môn học này'}</span><i aria-hidden="true">→</i></Link>; }
function GroupCard({ levelCode, group }) { return <Link className="education-card" to={`/education/${levelCode}/group/${group.id}`}><span className="education-card-kicker">NHÓM MÔN HỌC</span><b>{group.name}</b><span>{group.description || 'Xem các môn học trong nhóm này'}</span><i aria-hidden="true">→</i></Link>; }

export function EducationLevelPage() {
  const { levelCode } = useParams(); const [level, setLevel] = useState(null); const [groups, setGroups] = useState([]); const [courses, setCourses] = useState([]); const [error, setError] = useState(''); const [loading, setLoading] = useState(true);
  useEffect(() => { let alive = true; (async () => {
    setLoading(true); setError('');
    const { data: levelData, error: levelError } = await supabase.from('education_levels').select('id,code,name,description').eq('code', levelCode).single();
    if (!alive) return; if (levelError) { setError('Không tìm thấy cấp học hoặc cấp học đã ngừng hoạt động.'); setLoading(false); return; }
    const [groupResult, courseResult] = await Promise.all([
      supabase.from('education_subject_groups').select('id,education_level_id,code,name,description,display_order').eq('education_level_id', levelData.id).eq('is_active', true).order('display_order').order('name'),
      supabase.from('education_subjects').select('id,education_level_id,group_id,local_code,display_name,description,display_order').eq('education_level_id', levelData.id).eq('is_active', true).order('display_order').order('display_name'),
    ]);
    if (!alive) return; if (groupResult.error || courseResult.error) setError(groupResult.error?.message || courseResult.error?.message || 'Không tải được môn học.');
    else { setLevel(levelData); setGroups(groupResult.data || []); setCourses(courseResult.data || []); } setLoading(false);
  })(); return () => { alive = false; }; }, [levelCode]);
  const university = level?.code === 'university';
  return <EducationFrame><Breadcrumbs items={[{ label: 'Trang chủ', to: '/' }, { label: level?.name || 'Cấp học' }]} />{loading ? <div className="loading-line"><span className="spinner" /> Đang tải dữ liệu học tập…</div> : error ? <State message={error} /> : <>
    <section className="education-hero"><p className="eyebrow">CHỌN NỘI DUNG HỌC TẬP</p><h1>{level.name}</h1><p>{level.description || 'Chọn nhóm môn học hoặc môn học để tiếp tục.'}</p></section>
    {university ? <>{groups.length ? <section className="education-section"><div className="section-heading"><div><p className="eyebrow">COURSE GROUPS</p><h2>Nhóm môn học</h2></div></div><div className="education-grid">{groups.map((group) => <GroupCard key={group.id} levelCode={levelCode} group={group} />)}</div></section> : <State empty message="Chưa có nhóm môn học được mở" />}</> : courses.length ? <section className="education-section"><div className="section-heading"><div><p className="eyebrow">COURSES</p><h2>Môn học</h2></div></div><div className="education-grid">{courses.map((course) => <CourseCard key={course.id} levelCode={levelCode} course={course} />)}</div></section> : <State empty message="Chưa có môn học được mở" />}
  </>}</EducationFrame>;
}

export function EducationGroupPage() {
  const { levelCode, groupId } = useParams(); const [level, setLevel] = useState(null); const [group, setGroup] = useState(null); const [courses, setCourses] = useState([]); const [error, setError] = useState(''); const [loading, setLoading] = useState(true);
  useEffect(() => { let alive = true; (async () => {
    setLoading(true); const { data: levelData, error: levelError } = await supabase.from('education_levels').select('id,code,name').eq('code', levelCode).single();
    if (!alive) return; if (levelError || levelData.code !== 'university') { setError('Không tìm thấy nhóm môn học.'); setLoading(false); return; }
    const { data: groupData, error: groupError } = await supabase.from('education_subject_groups').select('id,education_level_id,name,description').eq('id', groupId).eq('education_level_id', levelData.id).eq('is_active', true).single();
    if (!alive) return; if (groupError) { setError('Nhóm môn học không tồn tại hoặc đã được ẩn.'); setLoading(false); return; }
    const { data: courseData, error: courseError } = await supabase.from('education_subjects').select('id,education_level_id,group_id,local_code,display_name,description,display_order').eq('education_level_id', levelData.id).eq('group_id', groupId).eq('is_active', true).order('display_order').order('display_name');
    if (!alive) return; if (courseError) setError(courseError.message); else { setLevel(levelData); setGroup(groupData); setCourses(courseData || []); } setLoading(false);
  })(); return () => { alive = false; }; }, [levelCode, groupId]);
  return <EducationFrame><Breadcrumbs items={[{ label: 'Trang chủ', to: '/' }, { label: level?.name || 'Đại học', to: `/education/${levelCode}` }, { label: group?.name || 'Nhóm môn học' }]} />{loading ? <div className="loading-line"><span className="spinner" /> Đang tải dữ liệu học tập…</div> : error ? <State message={error} /> : <><section className="education-hero"><p className="eyebrow">NHÓM MÔN HỌC</p><h1>{group.name}</h1><p>{group.description || 'Chọn môn học để xem các bài thi đã xuất bản.'}</p></section>{courses.length ? <section className="education-section"><div className="education-grid">{courses.map((course) => <CourseCard key={course.id} levelCode={levelCode} course={course} />)}</div></section> : <State empty message="Chưa có môn học trong nhóm này" />}</>}</EducationFrame>;
}

// Retain the old route as a compatibility redirect; node paths are no longer active.
export function EducationNodePage() { const { levelCode } = useParams(); return <Navigate to={`/education/${levelCode}`} replace />; }

export function EducationSubjectPage() {
  const { levelCode, offeringId } = useParams(); const [level, setLevel] = useState(null); const [course, setCourse] = useState(null); const [group, setGroup] = useState(null); const [exams, setExams] = useState([]); const [error, setError] = useState(''); const [loading, setLoading] = useState(true);
  useEffect(() => { let alive = true; (async () => {
    setLoading(true); const { data: courseData, error: courseError } = await supabase.from('education_subjects').select('id,education_level_id,group_id,local_code,display_name,description').eq('id', offeringId).eq('is_active', true).single();
    if (!alive) return; if (courseError) { setError('Môn học không tồn tại hoặc đã được ẩn.'); setLoading(false); return; }
    const { data: levelData, error: levelError } = await supabase.from('education_levels').select('id,code,name').eq('id', courseData.education_level_id).single();
    if (!alive) return; if (levelError || levelData.code !== levelCode) { setError('Môn học không thuộc cấp học đã chọn.'); setLoading(false); return; }
    let groupData = null;
    if (courseData.group_id) { const result = await supabase.from('education_subject_groups').select('id,name').eq('id', courseData.group_id).eq('is_active', true).single(); if (!alive) return; if (result.error) { setError('Nhóm môn học không tồn tại hoặc đã được ẩn.'); setLoading(false); return; } groupData = result.data; }
    const { data: examData, error: examError } = await supabase.rpc('list_published_exams_for_education_subject', { p_education_subject_id: offeringId });
    if (!alive) return; if (examError) setError(examError.message); else { setLevel(levelData); setCourse(courseData); setGroup(groupData); setExams(examData || []); } setLoading(false);
  })(); return () => { alive = false; }; }, [levelCode, offeringId]);
  return <EducationFrame><Breadcrumbs items={[{ label: 'Trang chủ', to: '/' }, { label: level?.name || 'Cấp học', to: `/education/${levelCode}` }, ...(group ? [{ label: group.name, to: `/education/${levelCode}/group/${group.id}` }] : []), { label: course?.display_name || 'Môn học' }]} />{loading ? <div className="loading-line"><span className="spinner" /> Đang tải dữ liệu học tập…</div> : error ? <State message={error} /> : <><section className="education-hero"><p className="eyebrow">MÔN HỌC / HỌC PHẦN</p><h1>{course.display_name}</h1><p>{group?.name ? `${group.name} · ` : ''}{course.description || course.local_code || 'Danh sách bài thi đã xuất bản thuộc môn học này.'}</p></section><section className="education-section"><div className="section-heading"><div><p className="eyebrow">EXAM LIBRARY</p><h2>Bài thi</h2><p className="muted">Chỉ hiển thị đề thuộc đúng môn học và cấp học này.</p></div></div>{exams.length ? <div className="education-exam-list">{exams.map((exam) => <article className="education-exam-card" key={exam.id}><div><span className="status published">Đã xuất bản</span><h3>{exam.title}</h3><p>{exam.description || 'Bài luyện tập'}</p><small>{exam.duration_minutes} phút · {exam.question_count} câu · Phiên bản {exam.version_no}</small></div><Link className="button primary" to={`/exam/${exam.id}`}>Vào phòng thi <span aria-hidden="true">→</span></Link></article>)}</div> : <State empty message="Chưa có bài thi cho môn học này" />}</section></>}</EducationFrame>;
}
