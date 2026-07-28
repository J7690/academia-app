"""Outil de mise au point : liste les instants des éléments v3 dans une page bâtie."""
import re
import sys

t = open(sys.argv[1], encoding="utf-8").read()
for cls in ("w kw", "chk", "stamp"):
    ds = re.findall(r'class="' + cls + r'" style="animation-delay:([0-9.]+)s', t)
    print(cls, "->", ds[:4])
print("chap présent:", 'class="chap"' in t)
