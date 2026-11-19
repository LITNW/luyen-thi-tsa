import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase.js';
import { splitRecordIdentity } from '../lib/educationPayload.js';

const emptyLevel = { id: '', code: '', name: '', description: '', display_order: 0, is_active: true };
const emptyNode = { id: '', education_level_id: '', parent_id: '', node_type: 'major', code: '', name: '', description: '', display_order: 0, is_active: true };
const emptySubject = { code: '', name: '', description: '', display_order: 0 };
const emptyOffering = { id: '', education_level_id: '', education_node_id: '', subject_id: '', knowledge_group: 'unclassified', local_code: '', display_name: '', description: '', display_order: 0, is_active: true };

const knowledgeGroups = [
  { value: 'general_sciences', label: 'Khoa học cơ bản' },
  { value: 'political_theory', label: 'Lý luận chính trị' },
  { value: 'major_foundation', label: 'Cơ sở ngành' },
  { value: 'specialization', label: 'Chuyên ngành' },
  { value: 'languages_skills', label: 'Ngoại ngữ và kỹ năng' },
  { value: 'unclassified', label: 'Chưa phân loại' },
];
const majorKnowledgeGroups = new Set(['major_foundation', 'specialization']);

function AdminEducationFrame({ children }) {
  return <div className="app-shell">
    <header className="topbar">
      <Link to="/" className="brand-lockup" aria-label="LIT — Trang chủ"><img src="/brand/lit-horizontal.svg" alt="LIT — Khu vực quản trị" /></Link>
      <nav className="top-links">
        <Link to="/admin">Tổng quan</Link><Link to="/admin/education">Cấu trúc học tập</Link>
        <Link to="/admin/exams">Đề thi</Link><Link to="/admin/categories">Loại đề</Link>
        <Link to="/admin/users">Tài khoản</Link><Link to="/">Trang chủ</Link>
      </nav>
    </header>
    <main className="narrow-page admin-education-page">
      <p className="eyebrow">EDUCATION STRUCTURE</p><h1>Quản lý cấu trúc học tập</h1>
      <p className="muted">Tạo cấp học, các tầng ngữ cảnh tùy chọn và môn học được mở tại từng ngữ cảnh. Không cần tạo lớp/trường/ngành nếu mô hình hiện tại không sử dụng chúng.</p>
      {children}
    </main>
    <footer className="footer">LIT · EDUCATION ADMIN</footer>
  </div>;
}

export default function AdminEducationPage() {
  const [levels, setLevels] = useState([]);
  const [nodes, setNodes] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [offerings, setOfferings] = useState([]);
  const [selectedLevel, setSelectedLevel] = useState('');
  const [levelForm, setLevelForm] = useState(emptyLevel);
  const [nodeForm, setNodeForm] = useState(emptyNode);
  const [subjectForm, setSubjectForm] = useState(emptySubject);
  const [offeringForm, setOfferingForm] = useState(emptyOffering);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    const [levelResult, nodeResult, subjectResult, offeringResult] = await Promise.all([
      supabase.from('education_levels').select('*').order('display_order').order('name'),
      supabase.from('education_nodes').select('*').order('display_order').order('name'),
      supabase.from('subjects').select('*').order('display_order').order('name'),
      supabase.from('education_subjects').select('*').order('display_order').order('display_name'),
    ]);
    const failed = [levelResult, nodeResult, subjectResult, offeringResult].find((result) => result.error);
    if (failed) setError(failed.error.message);
    else {
      setLevels(levelResult.data || []);
      setNodes(nodeResult.data || []);
      setSubjects(subjectResult.data || []);
      setOfferings(offeringResult.data || []);
      if (!selectedLevel && levelResult.data?.length) setSelectedLevel(levelResult.data[0].id);
    }
    setLoading(false);
  };

  useEffect(() => { void load(); }, []);

  const levelNodes = useMemo(() => nodes.filter((node) => node.education_level_id === selectedLevel), [nodes, selectedLevel]);
  const levelOfferings = useMemo(() => offerings.filter((item) => item.education_level_id === selectedLevel), [offerings, selectedLevel]);
  const nodeMap = useMemo(() => new Map(nodes.map((node) => [node.id, node])), [nodes]);
  const subjectMap = useMemo(() => new Map(subjects.map((subject) => [subject.id, subject])), [subjects]);

  const nodePath = (node) => {
    const names = [];
    let current = node;
    let guard = 0;
    while (current && guard < 12) {
      names.unshift(current.name);
      current = current.parent_id ? nodeMap.get(current.parent_id) : null;
      guard += 1;
    }
    return names.join(' / ');
  };

  const resetForms = () => {
    setLevelForm(emptyLevel);
    setNodeForm({ ...emptyNode, education_level_id: selectedLevel });
    setSubjectForm(emptySubject);
    setOfferingForm({ ...emptyOffering, education_level_id: selectedLevel });
  };

  const saveLevel = async (event) => {
    event.preventDefault();
    setSaving(true); setError(''); setNotice('');
    const { id: levelId, values: levelValues } = splitRecordIdentity(levelForm);
    const payload = { ...levelValues, display_order: Number(levelForm.display_order) || 0 };
    const result = levelId
      ? await supabase.from('education_levels').update(payload).eq('id', levelId)
      : await supabase.from('education_levels').insert(payload);
    if (result.error) setError(result.error.message);
    else { setNotice(levelId ? 'Đã cập nhật cấp học.' : 'Đã tạo cấp học.'); setLevelForm(emptyLevel); await load(); }
    setSaving(false);
  };

  const saveNode = async (event) => {
    event.preventDefault();
    if (!selectedLevel) return setError('Hãy chọn cấp học trước khi tạo ngành.');
    setSaving(true); setError(''); setNotice('');
    const { id: nodeId, values: nodeValues } = splitRecordIdentity(nodeForm);
    const payload = {
      ...nodeValues,
      education_level_id: selectedLevel,
      parent_id: nodeId ? (nodeForm.parent_id || null) : null,
      display_order: Number(nodeForm.display_order) || 0,
    };
    const result = nodeId
      ? await supabase.from('education_nodes').update(payload).eq('id', nodeId)
      : await supabase.from('education_nodes').insert(payload);
    if (result.error) setError(result.error.message);
    else { setNotice(nodeId ? 'Đã cập nhật ngành.' : 'Đã tạo ngành.'); setNodeForm({ ...emptyNode, education_level_id: selectedLevel }); await load(); }
    setSaving(false);
  };

  const saveSubject = async (event) => {
    event.preventDefault();
    setSaving(true); setError(''); setNotice('');
    const payload = { ...subjectForm, display_order: Number(subjectForm.display_order) || 0 };
    const result = await supabase.from('subjects').insert(payload);
    if (result.error) setError(result.error.message);
    else { setNotice('Đã thêm môn học vào danh mục dùng chung.'); setSubjectForm(emptySubject); await load(); }
    setSaving(false);
  };

  const saveOffering = async (event) => {
    event.preventDefault();
    if (!selectedLevel || !offeringForm.subject_id) return setError('Hãy chọn cấp học và môn học.');
    if (majorKnowledgeGroups.has(offeringForm.knowledge_group) && !offeringForm.education_node_id) return setError('Hãy chọn ngành áp dụng cho học phần cơ sở ngành hoặc chuyên ngành.');
    if (['general_sciences', 'political_theory', 'languages_skills'].includes(offeringForm.knowledge_group) && offeringForm.education_node_id) return setError('Các nhóm kiến thức độc lập không cần gắn với ngành. Hãy bỏ chọn ngành.');
    setSaving(true); setError(''); setNotice('');
    const { id: offeringId, values: offeringValues } = splitRecordIdentity(offeringForm);
    const payload = {
      ...offeringValues,
      education_level_id: selectedLevel,
      education_node_id: offeringForm.education_node_id || null,
      knowledge_group: offeringForm.knowledge_group || 'unclassified',
      local_code: offeringForm.local_code || null,
      display_order: Number(offeringForm.display_order) || 0,
    };
    const result = offeringId
      ? await supabase.from('education_subjects').update(payload).eq('id', offeringId)
      : await supabase.from('education_subjects').insert(payload);
    if (result.error) setError(result.error.message);
    else { setNotice(offeringId ? 'Đã cập nhật môn học trong ngữ cảnh.' : 'Đã thêm môn học vào cấp học/ngữ cảnh.'); setOfferingForm({ ...emptyOffering, education_level_id: selectedLevel }); await load(); }
    setSaving(false);
  };

  const toggleActive = async (table, item, nextActive) => {
    const label = table === 'education_levels' ? 'cấp học' : table === 'education_nodes' ? 'ngữ cảnh' : 'môn học';
    if (!window.confirm(`Xác nhận ${nextActive ? 'kích hoạt' : 'ẩn'} ${label} "${item.name || item.display_name}"?`)) return;
    setSaving(true); setError(''); setNotice('');
    const result = await supabase.from(table).update({ is_active: nextActive }).eq('id', item.id);
    if (result.error) setError(result.error.message);
    else { setNotice(nextActive ? 'Đã kích hoạt.' : 'Đã ẩn.'); await load(); }
    setSaving(false);
  };

  const editNode = (node) => setNodeForm({
    id: node.id, education_level_id: node.education_level_id, parent_id: node.parent_id || '',
    node_type: node.node_type, code: node.code, name: node.name, description: node.description || '',
    display_order: node.display_order, is_active: node.is_active,
  });

  const editLevel = (level) => setLevelForm({
    id: level.id, code: level.code, name: level.name, description: level.description || '',
    display_order: level.display_order, is_active: level.is_active,
  });

  const editOffering = (item) => setOfferingForm({
    id: item.id, education_level_id: item.education_level_id, education_node_id: item.education_node_id || '',
    subject_id: item.subject_id, knowledge_group: item.knowledge_group || 'unclassified', local_code: item.local_code || '', display_name: item.display_name,
    description: item.description || '', display_order: item.display_order, is_active: item.is_active,
  });

  const levelName = levels.find((level) => level.id === selectedLevel)?.name || '';

  return <AdminEducationFrame>
    {error && <div className="alert" role="alert">{error}</div>}
    {notice && <div className="form-message" role="status">{notice}</div>}
    {loading ? <div className="loading-line"><span className="spinner" /> Đang tải cấu trúc học tập…</div> : <>
      <section className="section-block admin-education-section">
        <div className="section-heading"><div><p className="eyebrow">LEVELS</p><h2>Cấp học</h2></div></div>
        <div className="education-admin-levels">
          {levels.map((level) => <article key={level.id} className={selectedLevel === level.id ? 'education-admin-level selected' : 'education-admin-level'}>
            <button type="button" className="education-admin-level-select" onClick={() => { setSelectedLevel(level.id); setNodeForm({ ...emptyNode, education_level_id: level.id }); setOfferingForm({ ...emptyOffering, education_level_id: level.id }); }}>
              <b>{level.name}</b><small>{level.code} · {level.is_active ? 'Đang hoạt động' : 'Đã ẩn'}</small>
            </button>
            <div className="user-actions">
              <button type="button" className="button secondary" onClick={() => editLevel(level)}>Sửa</button>
              <button type="button" className="button secondary" disabled={saving} onClick={() => toggleActive('education_levels', level, !level.is_active)}>{level.is_active ? 'Ẩn' : 'Kích hoạt'}</button>
            </div>
          </article>)}
        </div>
        <form className="category-form form-stack" onSubmit={saveLevel}>
          <h3>{levelForm.id ? 'Chỉnh sửa cấp học' : 'Thêm cấp học'}</h3>
          <div className="admin-form-grid">
            <label>Mã cấp học<input required pattern="[a-z][a-z0-9_]{1,63}" value={levelForm.code} disabled={!!levelForm.id} onChange={(e) => setLevelForm({ ...levelForm, code: e.target.value })} placeholder="postgraduate" /></label>
            <label>Tên hiển thị<input required maxLength={120} value={levelForm.name} onChange={(e) => setLevelForm({ ...levelForm, name: e.target.value })} placeholder="Sau đại học" /></label>
          </div>
          <label>Mô tả<textarea rows={2} value={levelForm.description} onChange={(e) => setLevelForm({ ...levelForm, description: e.target.value })} /></label>
          <label>Thứ tự hiển thị<input type="number" min="0" value={levelForm.display_order} onChange={(e) => setLevelForm({ ...levelForm, display_order: e.target.value })} /></label>
          <div className="user-actions"><button className="button primary" disabled={saving}>{saving ? 'Đang lưu…' : 'Lưu cấp học'}</button><button type="button" className="button secondary" onClick={() => setLevelForm(emptyLevel)}>Làm mới</button></div>
        </form>
      </section>

      {selectedLevel && <section className="section-block admin-education-section">
        <div className="section-heading"><div><p className="eyebrow">OPTIONAL CONTEXT</p><h2>Ngành / chuyên ngành · {levelName}</h2><p className="muted">Chỉ cần tạo ngành khi phân loại học phần cơ sở ngành hoặc chuyên ngành. Khoa học cơ bản và lý luận chính trị được phân loại độc lập.</p></div></div>
        <form className="category-form form-stack" onSubmit={saveNode}>
          <h3>{nodeForm.id ? 'Chỉnh sửa ngành' : 'Thêm ngành'}</h3>
          <div className="admin-form-grid">
                      </div>
          <div className="admin-form-grid">
            <label>Mã ngành<input required maxLength={64} pattern="[A-Za-z0-9][A-Za-z0-9._-]{0,63}" value={nodeForm.code} onChange={(e) => setNodeForm({ ...nodeForm, code: e.target.value })} placeholder="mechanical-engineering" /></label>
            <label>Tên ngành<input required maxLength={160} value={nodeForm.name} onChange={(e) => setNodeForm({ ...nodeForm, name: e.target.value })} placeholder="Kỹ thuật cơ khí" /></label>
          </div>
          <label>Mô tả<textarea rows={2} value={nodeForm.description} onChange={(e) => setNodeForm({ ...nodeForm, description: e.target.value })} /></label>
          <label>Thứ tự hiển thị<input type="number" min="0" value={nodeForm.display_order} onChange={(e) => setNodeForm({ ...nodeForm, display_order: e.target.value })} /></label>
          <div className="user-actions"><button className="button primary" disabled={saving}>{saving ? 'Đang lưu…' : nodeForm.id ? 'Lưu ngữ cảnh' : 'Thêm ngữ cảnh'}</button><button type="button" className="button secondary" onClick={() => setNodeForm({ ...emptyNode, education_level_id: selectedLevel })}>Làm mới</button></div>
        </form>
        <div className="version-list">
          {levelNodes.filter((node) => node.node_type === 'major').length ? levelNodes.filter((node) => node.node_type === 'major').map((node) => <article className="version-row" key={node.id}>
            <div><b>{nodePath(node)}</b><small>{node.node_type} · {node.code} · {node.is_active ? 'Đang hoạt động' : 'Đã ẩn'}</small></div>
            <div className="user-actions"><button type="button" className="button secondary" onClick={() => editNode(node)}>Sửa</button><button type="button" className="button secondary" disabled={saving} onClick={() => toggleActive('education_nodes', node, !node.is_active)}>{node.is_active ? 'Ẩn' : 'Kích hoạt'}</button></div>
          </article>) : <div className="empty-state">Chưa có ngành. Có thể bỏ qua nếu học phần không thuộc cơ sở ngành hoặc chuyên ngành.</div>}
        </div>
      </section>}

      <section className="section-block admin-education-section">
        <div className="section-heading"><div><p className="eyebrow">SUBJECT CATALOGUE</p><h2>Danh mục môn học dùng chung</h2></div></div>
        <form className="category-form form-stack" onSubmit={saveSubject}>
          <h3>Thêm môn học / học phần</h3>
          <div className="admin-form-grid">
            <label>Mã môn<input required pattern="[a-z][a-z0-9_]{1,63}" value={subjectForm.code} onChange={(e) => setSubjectForm({ ...subjectForm, code: e.target.value })} placeholder="physics" /></label>
            <label>Tên môn<input required maxLength={120} value={subjectForm.name} onChange={(e) => setSubjectForm({ ...subjectForm, name: e.target.value })} placeholder="Vật lý" /></label>
          </div>
          <label>Mô tả<textarea rows={2} value={subjectForm.description} onChange={(e) => setSubjectForm({ ...subjectForm, description: e.target.value })} /></label>
          <label>Thứ tự hiển thị<input type="number" min="0" value={subjectForm.display_order} onChange={(e) => setSubjectForm({ ...subjectForm, display_order: e.target.value })} /></label>
          <button className="button primary" disabled={saving}>Thêm vào danh mục</button>
        </form>
        <div className="education-admin-subjects">
          {subjects.map((subject) => <article className="education-admin-subject" key={subject.id}>
            <div><b>{subject.name}</b><small>{subject.code} · {subject.is_active ? 'Đang hoạt động' : 'Đã ẩn'}</small></div>
            <button type="button" className="button secondary" disabled={saving} onClick={() => toggleActive('subjects', subject, !subject.is_active)}>{subject.is_active ? 'Ẩn' : 'Kích hoạt'}</button>
          </article>)}
        </div>
      </section>

      {selectedLevel && <section className="section-block admin-education-section">
        <div className="section-heading"><div><p className="eyebrow">SUBJECT OFFERINGS</p><h2>Học phần thuộc {levelName}</h2><p className="muted">Mỗi học phần thuộc một nhóm kiến thức; chỉ cơ sở ngành và chuyên ngành mới cần gắn ngành áp dụng.</p></div></div>
        <form className="category-form form-stack" onSubmit={saveOffering}>
          <h3>{offeringForm.id ? 'Chỉnh sửa học phần' : 'Thêm học phần'}</h3>
          <div className="admin-form-grid">
            <label>Môn học<select required value={offeringForm.subject_id} onChange={(e) => setOfferingForm({ ...offeringForm, subject_id: e.target.value })}>
              <option value="">Chọn môn học trong danh mục</option>
              {subjects.filter((subject) => subject.is_active).map((subject) => <option key={subject.id} value={subject.id}>{subject.name} · {subject.code}</option>)}
            </select></label>
            <label>Nhóm kiến thức<select required value={offeringForm.knowledge_group} onChange={(e) => setOfferingForm({ ...offeringForm, knowledge_group: e.target.value, education_node_id: majorKnowledgeGroups.has(e.target.value) ? offeringForm.education_node_id : '' })}>{knowledgeGroups.map((group) => <option key={group.value} value={group.value}>{group.label}</option>)}</select></label>
            <label>Ngành áp dụng<select value={offeringForm.education_node_id} disabled={!majorKnowledgeGroups.has(offeringForm.knowledge_group)} onChange={(e) => setOfferingForm({ ...offeringForm, education_node_id: e.target.value })}>
              <option value="">Trực tiếp dưới cấp học</option>
              {levelNodes.filter((node) => node.is_active && node.node_type === 'major').map((node) => <option key={node.id} value={node.id}>{nodePath(node)}</option>)}
            </select></label>
          </div>
          <div className="admin-form-grid">
            <label>Tên hiển thị<input required maxLength={160} value={offeringForm.display_name} onChange={(e) => setOfferingForm({ ...offeringForm, display_name: e.target.value })} placeholder="Toán / Giải tích 1" /></label>
            <label>Mã học phần (nếu có)<input maxLength={64} value={offeringForm.local_code} onChange={(e) => setOfferingForm({ ...offeringForm, local_code: e.target.value })} placeholder="MATH-101" /></label>
          </div>
          <label>Mô tả<textarea rows={2} value={offeringForm.description} onChange={(e) => setOfferingForm({ ...offeringForm, description: e.target.value })} /></label>
          <label>Thứ tự hiển thị<input type="number" min="0" value={offeringForm.display_order} onChange={(e) => setOfferingForm({ ...offeringForm, display_order: e.target.value })} /></label>
          <div className="user-actions"><button className="button primary" disabled={saving || !offeringForm.subject_id}>{saving ? 'Đang lưu…' : offeringForm.id ? 'Lưu môn học' : 'Gán môn học'}</button><button type="button" className="button secondary" onClick={() => setOfferingForm({ ...emptyOffering, education_level_id: selectedLevel })}>Làm mới</button></div>
        </form>
        <div className="version-list">
          {levelOfferings.length ? levelOfferings.map((item) => <article className="version-row" key={item.id}>
            <div><b>{item.display_name}</b><small>{knowledgeGroups.find((group) => group.value === item.knowledge_group)?.label || 'Chưa phân loại'}{nodeMap.get(item.education_node_id)?.name ? ' · ' + nodePath(nodeMap.get(item.education_node_id)) : ''} · {subjectMap.get(item.subject_id)?.code || '—'} · {item.local_code || 'Không có mã'} · {item.is_active ? 'Đang hoạt động' : 'Đã ẩn'}</small></div>
            <div className="user-actions"><button type="button" className="button secondary" onClick={() => editOffering(item)}>Sửa</button><button type="button" className="button secondary" disabled={saving} onClick={() => toggleActive('education_subjects', item, !item.is_active)}>{item.is_active ? 'Ẩn' : 'Kích hoạt'}</button></div>
          </article>) : <div className="empty-state">Chưa có môn học được gán cho cấp học này.</div>}
        </div>
      </section>}
    </>}
  </AdminEducationFrame>;
}
