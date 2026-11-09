import json, re
h = open('index.html', encoding='utf-8').read()
m = re.search(r'<script type="application/json" id="data">(.*?)</script>', h)
D = json.loads(m.group(1))
dnd = []
for e in D['exams']:
    kinds = {}
    for i, q in enumerate(e['qs']):
        k = q.get('k') or 'mc'
        kinds[k] = kinds.get(k, 0) + 1
        if k == 'dnd':
            dnd.append({'i': i+1, 'q': str(q.get('q',''))[:240], 'o': q.get('o'), 'a': q.get('a'), 'once': q.get('once')})
    print(e['title'][:50], 'n=', len(e['qs']), kinds)
print('DND', len(dnd))
print(json.dumps(dnd[:15], ensure_ascii=False, indent=2))
