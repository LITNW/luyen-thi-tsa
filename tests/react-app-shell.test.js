import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

test('authenticated route guard wraps existing pages in the shared shell after access checks', () => {
  const guard = read('../src/components/RouteGuard.jsx');
  assert.match(guard, /import AppShell from ['"]\.\/AppShell\.jsx['"]/);
  assert.match(guard, /if \(admin && !isAdmin\)/);
  assert.match(guard, /<AppShell[^>]*isAdmin=\{isAdmin\}[^>]*profile=\{profile\}>\{children\}<\/AppShell>/);
});

test('shell provides named semantic landmarks and a keyboard-operable mobile menu', () => {
  const shell = read('../src/components/AppShell.jsx');
  assert.match(shell, /<header\b/);
  assert.match(shell, /<aside\b/);
  assert.match(shell, /<nav\b[^>]*aria-label="Điều hướng chính"/);
  assert.match(shell, /aria-expanded=\{menuOpen\}/);
  assert.match(shell, /aria-controls="primary-navigation"/);
  assert.match(shell, /onKeyDown=\{handleNavigationKeyDown\}/);
  assert.match(shell, /title=\{profile\.display_name\}/);
  assert.match(shell, /<main\b[^>]*id="main-content"/);
});

test('shell navigation points only at existing React destinations and keeps admin links gated', () => {
  const shell = read('../src/components/AppShell.jsx');
  const app = read('../src/App.jsx');
  for (const [path, label] of [
    ['/', 'Trang chủ'],
    ['/history', 'Lịch sử'],
    ['/account', 'Tài khoản'],
    ['/admin', 'Tổng quan'],
    ['/admin/education', 'Cấu trúc học tập'],
    ['/admin/exams', 'Đề thi'],
    ['/admin/categories', 'Loại đề'],
    ['/admin/users', 'Quản lý tài khoản'],
    ['/admin/attempts', 'Lượt làm'],
  ]) {
    assert.ok(shell.includes(`to: '${path}'`) || shell.includes(`to: "${path}"`), `missing shell destination ${path}`);
    assert.ok(shell.includes(label), `missing navigation label ${label}`);
    assert.ok(app.includes(`path="${path}"`), `destination ${path} is not an existing route`);
  }
  assert.match(shell, /isAdmin &&/);
});

test('active links expose aria-current and focus styling comes from shared tokens', () => {
  const shell = read('../src/components/AppShell.jsx');
  const styles = read('../src/lit-theme.css');
  assert.match(shell, /<NavLink\b/);
  assert.match(shell, /end=\{item\.end\}/);
  assert.match(styles, /\.lit-app-shell[^\n]*:focus-visible|\.lit-app-shell[\s\S]*:focus-visible/);
  assert.match(styles, /var\(--lit-token-color-focus\)/);
});

test('authenticated page frames no longer create duplicate app headers or navigation', () => {
  const files = [
    '../src/pages/DashboardPage.jsx',
    '../src/pages/AccountPage.jsx',
    '../src/pages/HistoryPage.jsx',
    '../src/pages/ResultsPage.jsx',
    '../src/pages/EducationBrowsePages.jsx',
    '../src/pages/AdminPages.jsx',
    '../src/pages/AdminEducationPage.jsx',
  ];
  for (const file of files) {
    const source = read(file);
    assert.doesNotMatch(source, /<header className="topbar"/ , `${file} retains a duplicate topbar`);
    assert.doesNotMatch(source, /<footer className="footer"/ , `${file} retains a duplicate footer`);
  }
});

test('shell styles define responsive breakpoints and non-color active states', () => {
  const styles = read('../src/lit-theme.css');
  assert.match(styles, /@media \(max-width: 900px\)/);
  assert.match(styles, /@media \(max-width: 640px\)/);
  assert.match(styles, /aria-current="page"/);
  assert.match(styles, /border-inline-start/);
  assert.match(styles, /--lit-token-radius-panel/);
  assert.match(styles, /text-overflow: ellipsis/);
});
