import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase.js';
import { buildEducationCoursePayload, splitRecordIdentity } from '../lib/educationPayload.js';

const emptyCategory = { id: '', code: '', name: '', description: '', display_order: 0, is_active: true };
const emptyCourse = { id: '', category_id: '', local_code: '', display_name: '', description: '', display_order: 0, is_active: true };

function AdminEducationFrame({ children }) {
  return <div className="app-shell">
    <header className="topbar">
      <Link to="/" className="brand-lockup" aria-label="LIT — Trang chủ"><img src="/brand/lit-horizontal.svg" alt="LIT — Khu vực quản trị" /></Link>
      <nav className="top-links"><Link to="/admin">Tổng quan</Link><Link to="/admin/education">Cấu trúc học tập</Link><Link to="/admin/exams">Đề thi</Link><Link to="/admin/categories">Loại đề</Link><Link to="/admin/users">Tài khoản</Link><Link to="/">Trang chủ</Link></nav>
    </header>
    <main className="narrow-page admin-education-page"><p className="eyebrow">EDUCATION STRUCTURE</p><h1>Quản lý môn học</h1><p className="muted">THPT quản lý môn học trực tiếp. Đại học quản lý danh mục môn học và các học phần trong từng danh mục.</p>{children}</main>
    <footer className="footer">LIT · EDUCATION ADMIN</footer>
  </div>;
}

export default function AdminEducationPage() {
  const [levels, setLevels] = useState([]);
  const [categories, setCategorys] = useState([]);
  const [courses, setCourses] = useState([]);
  const [selectedLevel, setSelectedLevel] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');
  const [categoryForm, setCategoryForm] = useState(emptyCategory);
  const [courseForm, setCourseForm] = useState(emptyCourse);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const load = async () => {
    setLoading(true); setError('');
    const [levelsResult, categorysResult, coursesResult] = await Promise.all([
      supabase.from('education_levels').select('id,code,name,is_active,display_order').order('display_order').order('name'),
      supabase.from('education_course_categories').select('*').order('display_order').order('name'),
      supabase.from('education_subjects').select('id,education_level_id,category_id,local_code,display_name,description,display_order,is_active').order('display_order').order('display_name'),
    ]);
    const failed = [levelsResult, categorysResult, coursesResult].find((result) => result.error);
    if (failed) setError(failed.error.message);
    else {
      setLevels(levelsResult.data || []); setCategorys(categorysResult.data || []); setCourses(coursesResult.data || []);
      if (!selectedLevel && levelsResult.data?.length) setSelectedLevel(levelsResult.data[0].id);
    }
    setLoading(false);
  };
  useEffect(() => { void load(); }, []);

  const level = levels.find((item) => item.id === selectedLevel);
  const university = level?.code === 'university';
  const levelCategorys = useMemo(() => categories.filter((item) => item.education_level_id === selectedLevel), [categories, selectedLevel]);
  const levelCourses = useMemo(() => courses.filter((item) => item.education_level_id === selectedLevel && (!university || item.category_id === selectedCategory)), [courses, selectedLevel, selectedCategory, university]);
  const visibleCourses = levelCourses.filter((item) => !query.trim() || `${item.display_name} ${item.local_code || ''}`.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase()));

  const saveCategory = async (event) => {
    event.preventDefault(); setSaving(true); setError(''); setNotice('');
    const { id, values } = splitRecordIdentity(categoryForm);
    const payload = { ...values, education_level_id: selectedLevel, display_order: Number(categoryForm.display_order) || 0 };
    const result = id ? await supabase.from('education_course_categories').update(payload).eq('id', id) : await supabase.from('education_course_categories').insert(payload);
    if (result.error) setError(result.error.message);
    else { setNotice(id ? 'Đã cập nhật danh mục môn học.' : 'Đã tạo danh mục môn học.'); setCategoryForm(emptyCategory); await load(); }
    setSaving(false);
  };

  const saveCourse = async (event) => {
    event.preventDefault();
    if (university && !courseForm.category_id) return setError('Hãy chọn danh mục môn học cho học phần đại học.');
    setSaving(true); setError(''); setNotice('');
    try {
      const { id, values } = splitRecordIdentity(courseForm);
      const payload = buildEducationCoursePayload(values, selectedLevel, university);
      const result = id ? await supabase.from('education_subjects').update(payload).eq('id', id) : await supabase.from('education_subjects').insert(payload);
      if (result.error) throw result.error;
      setNotice(id ? 'Đã cập nhật môn học.' : 'Đã tạo môn học.'); setCourseForm({ ...emptyCourse, category_id: selectedCategory }); await load();
    } catch (saveError) { setError(saveError.message); }
    setSaving(false);
  };

  const toggle = async (table, item, active, label) => {
    if (!active && table === 'education_course_categories' && courses.some((course) => course.category_id === item.id && course.is_active)) {
      setError('Danh mục còn môn học đang hoạt động. Hãy chuyển hoặc ẩn các môn học trước khi ẩn danh mục.'); return;
    }
    if (!window.confirm(`Xác nhận ${active ? 'kích hoạt' : 'ẩn'} ${label} “${item.name || item.display_name}”?`)) return;
    setSaving(true); setError(''); setNotice('');
    const { error: updateError } = await supabase.from(table).update({ is_active: active }).eq('id', item.id);
    if (updateError) setError(updateError.message); else { setNotice(active ? 'Đã kích hoạt.' : 'Đã ẩn.'); await load(); }
    setSaving(false);
  };

  const editCourse = (course) => { setCourseForm({ id: course.id, category_id: course.category_id || '', local_code: course.local_code || '', display_name: course.display_name, description: course.description || '', display_order: course.display_order, is_active: course.is_active }); setNotice(''); setError(''); };
  const editCategory = (category) => { setCategoryForm({ id: category.id, code: category.code, name: category.name, description: category.description || '', display_order: category.display_order, is_active: category.is_active }); setNotice(''); setError(''); };

  return <AdminEducationFrame>
    {error && <div className="alert" role="alert">{error}</div>}{notice && <div className="form-message" role="status">{notice}</div>}
    {loading ? <div className="loading-line"><span className="spinner" /> Đang tải môn học…</div> : <>
      <section className="section-block admin-education-section"><h2>Cấp học</h2><div className="education-admin-levels">{levels.map((item) => <button key={item.id} type="button" className={`education-admin-level-select ${selectedLevel === item.id ? 'selected' : ''}`} onClick={() => { setSelectedLevel(item.id); setSelectedCategory(''); setCategoryForm(emptyCategory); setCourseForm(emptyCourse); setQuery(''); }}>{item.name}<small>{item.is_active ? 'Đang hoạt động' : 'Đã ẩn'}</small></button>)}</div></section>
      {university && <section className="section-block admin-education-section"><h2>Danh mục môn học · {level.name}</h2>
        <form className="category-form form-stack" onSubmit={saveCategory}><h3>{categoryForm.id ? 'Chỉnh sửa danh mục' : 'Thêm danh mục'}</h3><div className="admin-form-grid"><label>Mã danh mục<input required pattern="[a-z][a-z0-9_]{1,63}" value={categoryForm.code} onChange={(e) => setCategoryForm({ ...categoryForm, code: e.target.value })} /></label><label>Tên danh mục<input required maxLength={160} value={categoryForm.name} onChange={(e) => setCategoryForm({ ...categoryForm, name: e.target.value })} /></label></div><label>Mô tả<textarea value={categoryForm.description} onChange={(e) => setCategoryForm({ ...categoryForm, description: e.target.value })} /></label><label>Thứ tự hiển thị<input type="number" value={categoryForm.display_order} onChange={(e) => setCategoryForm({ ...categoryForm, display_order: e.target.value })} /></label><div className="user-actions"><button className="button primary" disabled={saving}>{categoryForm.id ? 'Lưu danh mục' : 'Tạo danh mục'}</button><button type="button" className="button secondary" onClick={() => setCategoryForm(emptyCategory)}>Làm mới</button></div></form>
        <div className="version-list">{levelCategorys.map((category) => <article className="version-row" key={category.id}><button type="button" className="education-admin-level-select" onClick={() => { setSelectedCategory(category.id); setCourseForm({ ...emptyCourse, category_id: category.id }); }}>{category.name}<small>{category.code} · {courses.filter((item) => item.category_id === category.id).length} môn · {category.is_active ? 'Đang hoạt động' : 'Đã ẩn'}</small></button><div className="user-actions"><button type="button" className="button secondary" onClick={() => editCategory(category)}>Sửa</button><button type="button" className="button secondary" disabled={saving} onClick={() => toggle('education_course_categories', category, !category.is_active, 'danh mục')}>{category.is_active ? 'Ẩn' : 'Kích hoạt'}</button></div></article>)}</div>
      </section>}
      {level && (!university || selectedCategory) && <section className="section-block admin-education-section"><h2>{university ? `Môn học trong ${levelCategorys.find((item) => item.id === selectedCategory)?.name || ''}` : `Môn học · ${level.name}`}</h2>
        <form className="category-form form-stack" onSubmit={saveCourse}><h3>{courseForm.id ? 'Chỉnh sửa môn học' : 'Thêm môn học'}</h3><div className="admin-form-grid">{university && <label>Danh mục môn học<select required value={courseForm.category_id} onChange={(e) => setCourseForm({ ...courseForm, category_id: e.target.value })}><option value="">Chọn danh mục</option>{levelCategorys.filter((item) => item.is_active).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>}<label>Mã môn học<input maxLength={64} value={courseForm.local_code} onChange={(e) => setCourseForm({ ...courseForm, local_code: e.target.value })} /></label><label>Tên môn học<input required maxLength={160} value={courseForm.display_name} onChange={(e) => setCourseForm({ ...courseForm, display_name: e.target.value })} /></label></div><label>Mô tả<textarea value={courseForm.description} onChange={(e) => setCourseForm({ ...courseForm, description: e.target.value })} /></label><label>Thứ tự hiển thị<input type="number" value={courseForm.display_order} onChange={(e) => setCourseForm({ ...courseForm, display_order: e.target.value })} /></label><div className="user-actions"><button className="button primary" disabled={saving}>{courseForm.id ? 'Lưu môn học' : 'Tạo môn học'}</button><button type="button" className="button secondary" onClick={() => setCourseForm({ ...emptyCourse, category_id: selectedCategory })}>Làm mới</button></div></form>
        <label>Tìm theo tên hoặc mã<input type="search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Tên môn hoặc mã môn" /></label><div className="version-list">{visibleCourses.map((course) => <article className="version-row" key={course.id}><div><b>{course.display_name}</b><small>{course.local_code || 'Không có mã'} · {course.is_active ? 'Đang hoạt động' : 'Đã ẩn'} · ID {course.id}</small></div><div className="user-actions"><button type="button" className="button secondary" onClick={() => editCourse(course)}>Sửa / chuyển danh mục</button><button type="button" className="button secondary" disabled={saving} onClick={() => toggle('education_subjects', course, !course.is_active, 'môn học')}>{course.is_active ? 'Ẩn' : 'Kích hoạt'}</button></div></article>)}</div>{!visibleCourses.length && <div className="empty-state">Chưa có môn học trong mục này.</div>}
      </section>}
    </>}
  </AdminEducationFrame>;
}
