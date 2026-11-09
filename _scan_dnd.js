const fs = require('fs');
const h = fs.readFileSync('index.html', 'utf8');
const m = h.match(/<script type="application\/json" id="data">([\s\S]*?)<\/script>/);
const D = JSON.parse(m[1]);
const dnd = [];
D.exams.forEach(e => e.qs.forEach((q, i) => {
  if ((q.k || 'mc') === 'dnd') dnd.push({ exam: e.id, i: i + 1, q: String(q.q).slice(0, 220), o: q.o, a: q.a, once: q.once });
}));
console.log('exams', D.exams.length, 'dnd', dnd.length);
console.log(JSON.stringify(D.exams.map(e => ({ t: e.title.slice(0, 40), n: e.qs.length, k: e.qs.reduce((s, q) => { const k = q.k || 'mc'; s[k] = (s[k] || 0) + 1; return s; }, {}) })), null, 2));
console.log(JSON.stringify(dnd.slice(0, 12), null, 2));
