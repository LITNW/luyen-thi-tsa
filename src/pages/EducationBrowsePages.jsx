import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase.js';

function EducationFrame({ children }) {
  return <div className="app-shell">
    <header className="topbar">
      <Link to="/" className="brand-lockup"><span className="brand-mark small-mark">T</span><span><b>TSA Practice</b><small>KHÔNG GIAN HỌC TẬP</small></span></Link>
      <nav className="top-links"><Link to="/history">Lịch sử</Link><Link to="/account">Tài khoản</Link></nav>
    </header>
    <main className="education-page">{children}</main>
    <footer className="footer">TSA PRACTICE PLATFORM <span>Học tập có chiến lược · Tiến bộ mỗi ngày</span></footer>
  </div>;
}

function Breadcrumbs({ items }) {
  return <nav className="education-breadcrumbs" aria-label="Đường dẫn">
    {items.map((item, index) => <span key={item.to || item.label}>
      {index > 0 && <i aria-hidden="true">/</i>}
      {item.to && index < items.length - 1 ? <Link to={item.to}>{item.label}</Link> : <b>{item.label}</b>}
    </span>)}
  </nav>;
}

function LoadingState() {
  return <div className="loading-line"><span className="spinner" /> Đang tải dữ liệu học tập…</div>;
}

function ErrorState({ message }) {
  return <div className="alert" role="alert">{message}</div>;
}

function EmptyState({ title, description }) {
  return <div className="empty-state"><b>{title}</b><p>{description}</p></div>;
}

function ContextCard({ levelCode, node }) {
  return <Link className="education-card" to={`/education/${levelCode}/context/${node.id}`}>
    <span className="education-card-kicker">{node.node_type === 'grade' ? 'LỚP HỌC' : node.node_type === 'institution' ? 'CƠ SỞ ĐÀO TẠO' : node.node_type === 'program' ? 'CHƯƠNG TRÌNH' : node.node_type === 'major' ? 'NGÀNH HỌC' : 'DANH MỤC'}</span>
    <b>{node.name}</b><span>{node.description || 'Xem môn học và nội dung luyện tập'}</span><i aria-hidden="true">→</i>
  </Link>;
}

function SubjectCard({ levelCode, offering }) {
  return <Link className="education-card subject-card" to={`/education/${levelCode}/subject/${offering.id}`}>
    <span className="education-card-kicker">MÔN HỌC / HỌC PHẦN</span>
    <b>{offering.display_name}</b>
    <span>{offering.description || offering.local_code || 'Xem các bài thi thuộc môn học này'}</span>
    <i aria-hidden="true">→</i>
  </Link>;
}

export function EducationLevelPage() {
  const { levelCode } = useParams();
  const [level, setLevel] = useState(null);
  const [nodes, setNodes] = useState([]);
  const [offerings, setOfferings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    const load = async () => {
      setLoading(true); setError('');
      const { data: levelData, error: levelError } = await supabase
        .from('education_levels').select('id,code,name,description').eq('code', levelCode).single();
      if (!active) return;
      if (levelError) { setError('Không tìm thấy cấp học hoặc cấp học đã ngừng hoạt động.'); setLoading(false); return; }
      const [nodeResult, offeringResult] = await Promise.all([
        supabase.from('education_nodes').select('id,education_level_id,parent_id,node_type,code,name,description,display_order')
          .eq('education_level_id', levelData.id).is('parent_id', null).order('display_order').order('name'),
        supabase.from('education_subjects').select('id,education_level_id,education_node_id,subject_id,local_code,display_name,description,display_order')
          .eq('education_level_id', levelData.id).is('education_node_id', null).order('display_order').order('display_name'),
      ]);
      if (!active) return;
      if (nodeResult.error || offeringResult.error) setError(nodeResult.error?.message || offeringResult.error?.message || 'Không tải được danh mục học tập.');
      else { setLevel(levelData); setNodes(nodeResult.data || []); setOfferings(offeringResult.data || []); }
      setLoading(false);
    };
    void load();
    return () => { active = false; };
  }, [levelCode]);

  return <EducationFrame>
    <Breadcrumbs items={[{ label: 'Trang chủ', to: '/' }, { label: level?.name || 'Cấp học' }]} />
    {loading ? <LoadingState /> : error ? <ErrorState message={error} /> : <>
      <section className="education-hero">
        <p className="eyebrow">CHỌN NỘI DUNG HỌC TẬP</p>
        <h1>{level.name}</h1>
        <p>{level.description || 'Chọn môn học hoặc một nhánh chương trình để tiếp tục.'}</p>
      </section>
      {nodes.length > 0 && <section className="education-section">
        <div className="section-heading"><div><p className="eyebrow">LỘ TRÌNH</p><h2>Chương trình / lớp / ngữ cảnh</h2></div></div>
        <div className="education-grid">{nodes.map((node) => <ContextCard key={node.id} levelCode={levelCode} node={node} />)}</div>
      </section>}
      {offerings.length > 0 && <section className="education-section">
        <div className="section-heading"><div><p className="eyebrow">SUBJECTS</p><h2>Môn học</h2></div></div>
        <div className="education-grid">{offerings.map((offering) => <SubjectCard key={offering.id} levelCode={levelCode} offering={offering} />)}</div>
      </section>}
      {!nodes.length && !offerings.length && <EmptyState title="Chưa có môn học được mở" description="Quản trị viên chưa thiết lập môn học cho cấp học này." />}
    </>}
  </EducationFrame>;
}

export function EducationNodePage() {
  const { levelCode, nodeId } = useParams();
  const [level, setLevel] = useState(null);
  const [node, setNode] = useState(null);
  const [path, setPath] = useState([]);
  const [children, setChildren] = useState([]);
  const [offerings, setOfferings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    const load = async () => {
      setLoading(true); setError('');
      const { data: levelData, error: levelError } = await supabase
        .from('education_levels').select('id,code,name,description').eq('code', levelCode).single();
      if (!active) return;
      if (levelError) { setError('Không tìm thấy cấp học.'); setLoading(false); return; }
      const { data: allNodes, error: nodeError } = await supabase
        .from('education_nodes').select('id,education_level_id,parent_id,node_type,code,name,description,display_order')
        .eq('education_level_id', levelData.id).order('display_order').order('name');
      if (!active) return;
      if (nodeError) { setError(nodeError.message); setLoading(false); return; }
      const selected = (allNodes || []).find((item) => item.id === nodeId);
      if (!selected) { setError('Ngữ cảnh này không tồn tại hoặc đã được ẩn.'); setLoading(false); return; }
      const byId = new Map((allNodes || []).map((item) => [item.id, item]));
      const chain = [];
      let current = selected;
      let guard = 0;
      while (current && guard < 12) {
        chain.unshift(current);
        current = current.parent_id ? byId.get(current.parent_id) : null;
        guard += 1;
      }
      const [childResult, offeringResult] = await Promise.all([
        supabase.from('education_nodes').select('id,education_level_id,parent_id,node_type,code,name,description,display_order')
          .eq('education_level_id', levelData.id).eq('parent_id', nodeId).order('display_order').order('name'),
        supabase.from('education_subjects').select('id,education_level_id,education_node_id,subject_id,local_code,display_name,description,display_order')
          .eq('education_level_id', levelData.id).eq('education_node_id', nodeId).order('display_order').order('display_name'),
      ]);
      if (!active) return;
      if (childResult.error || offeringResult.error) setError(childResult.error?.message || offeringResult.error?.message || 'Không tải được môn học.');
      else { setLevel(levelData); setNode(selected); setPath(chain); setChildren(childResult.data || []); setOfferings(offeringResult.data || []); }
      setLoading(false);
    };
    void load();
    return () => { active = false; };
  }, [levelCode, nodeId]);

  return <EducationFrame>
    <Breadcrumbs items={[
      { label: 'Trang chủ', to: '/' },
      { label: level?.name || 'Cấp học', to: `/education/${levelCode}` },
      ...path.map((item, index) => ({ label: item.name, to: index < path.length - 1 ? `/education/${levelCode}/context/${item.id}` : null })),
    ]} />
    {loading ? <LoadingState /> : error ? <ErrorState message={error} /> : <>
      <section className="education-hero">
        <p className="eyebrow">{node.node_type.toUpperCase()}</p>
        <h1>{node.name}</h1>
        <p>{node.description || 'Chọn môn học hoặc nhánh học tập bên dưới.'}</p>
      </section>
      {children.length > 0 && <section className="education-section">
        <div className="section-heading"><div><p className="eyebrow">SUB-CONTEXTS</p><h2>Nhánh học tập</h2></div></div>
        <div className="education-grid">{children.map((child) => <ContextCard key={child.id} levelCode={levelCode} node={child} />)}</div>
      </section>}
      {offerings.length > 0 && <section className="education-section">
        <div className="section-heading"><div><p className="eyebrow">SUBJECTS</p><h2>Môn học / học phần</h2></div></div>
        <div className="education-grid">{offerings.map((offering) => <SubjectCard key={offering.id} levelCode={levelCode} offering={offering} />)}</div>
      </section>}
      {!children.length && !offerings.length && <EmptyState title="Chưa có môn học trong ngữ cảnh này" description="Quản trị viên có thể thêm môn học trực tiếp vào ngữ cảnh hoặc tạo nhánh con." />}
    </>}
  </EducationFrame>;
}

export function EducationSubjectPage() {
  const { levelCode, offeringId } = useParams();
  const [level, setLevel] = useState(null);
  const [offering, setOffering] = useState(null);
  const [path, setPath] = useState([]);
  const [exams, setExams] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    const load = async () => {
      setLoading(true); setError('');
      const { data: offeringData, error: offeringError } = await supabase
        .from('education_subjects').select('id,education_level_id,education_node_id,subject_id,local_code,display_name,description')
        .eq('id', offeringId).single();
      if (!active) return;
      if (offeringError) { setError('Môn học không tồn tại hoặc đã được ẩn.'); setLoading(false); return; }
      const { data: levelData, error: levelError } = await supabase
        .from('education_levels').select('id,code,name,description').eq('id', offeringData.education_level_id).single();
      if (!active) return;
      if (levelError || levelData.code !== levelCode) { setError('Môn học không thuộc cấp học đã chọn.'); setLoading(false); return; }
      let chain = [];
      if (offeringData.education_node_id) {
        const { data: allNodes, error: nodesError } = await supabase
          .from('education_nodes').select('id,parent_id,name,node_type')
          .eq('education_level_id', levelData.id);
        if (!active) return;
        if (nodesError) { setError(nodesError.message); setLoading(false); return; }
        const byId = new Map((allNodes || []).map((item) => [item.id, item]));
        let current = byId.get(offeringData.education_node_id);
        let guard = 0;
        while (current && guard < 12) {
          chain.unshift(current);
          current = current.parent_id ? byId.get(current.parent_id) : null;
          guard += 1;
        }
      }
      const { data: examData, error: examError } = await supabase.rpc('list_published_exams_for_education_subject', {
        p_education_subject_id: offeringId,
      });
      if (!active) return;
      if (examError) setError(examError.message);
      else { setLevel(levelData); setOffering(offeringData); setPath(chain); setExams(examData || []); }
      setLoading(false);
    };
    void load();
    return () => { active = false; };
  }, [levelCode, offeringId]);

  const breadcrumbs = [
    { label: 'Trang chủ', to: '/' },
    { label: level?.name || 'Cấp học', to: `/education/${levelCode}` },
    ...path.map((item, index) => ({ label: item.name, to: index < path.length - 1 ? `/education/${levelCode}/context/${item.id}` : null })),
    { label: offering?.display_name || 'Môn học' },
  ];

  return <EducationFrame>
    <Breadcrumbs items={breadcrumbs} />
    {loading ? <LoadingState /> : error ? <ErrorState message={error} /> : <>
      <section className="education-hero">
        <p className="eyebrow">MÔN HỌC / HỌC PHẦN</p>
        <h1>{offering.display_name}</h1>
        <p>{offering.description || offering.local_code || 'Danh sách bài thi đã xuất bản thuộc môn học này.'}</p>
      </section>
      <section className="education-section">
        <div className="section-heading"><div><p className="eyebrow">EXAM LIBRARY</p><h2>Bài thi</h2><p className="muted">Chỉ hiển thị đề thuộc đúng môn học và cấp học này.</p></div></div>
        {exams.length ? <div className="education-exam-list">{exams.map((exam) => <article className="education-exam-card" key={exam.id}>
          <div><span className="status published">Đã xuất bản</span><h3>{exam.title}</h3><p>{exam.description || 'Bài luyện tập'}</p><small>{exam.duration_minutes} phút · {exam.question_count} câu · Phiên bản {exam.version_no}</small></div>
          <Link className="button primary" to={`/exam/${exam.id}`}>Vào phòng thi <span aria-hidden="true">→</span></Link>
        </article>)}</div> : <EmptyState title="Chưa có bài thi cho môn học này" description="Các đề thi sẽ xuất hiện sau khi quản trị viên gán đúng môn học và xuất bản." />}
      </section>
    </>}
  </EducationFrame>;
}
