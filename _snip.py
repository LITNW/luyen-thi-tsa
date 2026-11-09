h = open('index.html', encoding='utf-8').read().splitlines()
for n in range(117, 133):
    print(f'{n}|{h[n-1]}')
print('---145-147---')
for n in range(145, 148):
    print(f'{n}|{h[n-1]}')
print('---36---')
print(h[35])
print('---56---')
print(h[55])
print('---58 dnd---')
s=h[57]
i=s.find("k==='dnd'?Object")
print(s[i:i+120])
