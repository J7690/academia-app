import sys

def strip(s):
    out = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c == '/' and i + 1 < n and s[i + 1] == '/':
            j = s.find('\n', i)
            if j == -1:
                break
            i = j
            continue
        if c == '/' and i + 1 < n and s[i + 1] == '*':
            j = s.find('*/', i + 2)
            i = (j + 2) if j != -1 else n
            continue
        if c in ("'", '"'):
            quote = c
            j = i + 1
            while j < n:
                if s[j] == '\\':
                    j += 2
                    continue
                if s[j] == '$' and j + 1 < n and s[j + 1] == '{':
                    j += 2
                    d = 1
                    while j < n and d > 0:
                        if s[j] in ("'", '"'):
                            qq = s[j]
                            j += 1
                            while j < n and s[j] != qq:
                                if s[j] == '\\':
                                    j += 2
                                    continue
                                j += 1
                            j += 1
                            continue
                        if s[j] == '{':
                            d += 1
                        elif s[j] == '}':
                            d -= 1
                        j += 1
                    continue
                if s[j] == quote:
                    j += 1
                    break
                j += 1
            i = j
            continue
        out.append(c)
        i += 1
    return ''.join(out)


for path in sys.argv[1:]:
    src = open(path, encoding='utf-8').read()
    stripped = strip(src)
    results = []
    ok = True
    for op, cl in [('(', ')'), ('[', ']'), ('{', '}')]:
        bal = 0
        for ch in stripped:
            if ch == op:
                bal += 1
            elif ch == cl:
                bal -= 1
        results.append(f"{op}{cl}={bal}")
        if bal != 0:
            ok = False
    status = "OK" if ok else "MISMATCH"
    alert = src.count("AlertDialog(")
    adaptive = src.count("AdaptiveDialog(")
    print(f"{status} {path} | {' '.join(results)} | AlertDialog={alert} AdaptiveDialog={adaptive}")
