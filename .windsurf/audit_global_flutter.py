#!/usr/bin/env python3
"""Audit global Flutter: RPCs appelees, providers, ecrans par role."""
import os, re
from collections import defaultdict
from pathlib import Path

LIB = Path(r"C:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib")

rpc_pattern = re.compile(r"""\.rpc\(\s*['"]([^'"]+)['"]""")
edge_fn_pattern = re.compile(r"""functions/v1/([a-z0-9\-]+)""")

rpc_calls = defaultdict(set)
edge_fn_calls = defaultdict(set)

for dart_file in LIB.rglob("*.dart"):
    rel = str(dart_file.relative_to(LIB))
    try:
        content = dart_file.read_text(encoding="utf-8", errors="ignore")
    except:
        continue
    for match in rpc_pattern.finditer(content):
        rpc_calls[match.group(1)].add(rel)
    for match in edge_fn_pattern.finditer(content):
        edge_fn_calls[match.group(1)].add(rel)

# Count files by directory
role_dirs = {
    "student": "features\\student", "instructor": "features\\instructor",
    "admin": "features\\admin", "university": "features\\university",
    "commercial": "features\\commercial", "merchant": "features\\merchant",
    "live": "features\\live", "auth": "features\\auth",
    "support": "features\\support", "providers": "providers", "services": "services",
}
print("=" * 70)
print("AUDIT GLOBAL FLUTTER")
print("=" * 70)

print("\n[1] FICHIERS PAR ROLE/MODULE:")
for role, d in sorted(role_dirs.items()):
    full = LIB / d
    if full.exists():
        count = sum(1 for _ in full.rglob("*.dart"))
        print(f"  {role:20s} {count} fichiers .dart")

print(f"\n[2] PROVIDERS ({sum(1 for _ in (LIB/'providers').rglob('*.dart'))}):")
for f in sorted((LIB / "providers").rglob("*.dart")):
    print(f"  - {f.stem}")

print(f"\n[3] RPCs APPELEES DANS FLUTTER ({len(rpc_calls)}):")
categories = defaultdict(list)
for rpc in sorted(rpc_calls.keys()):
    if "admin" in rpc and "prep" in rpc: cat = "ADMIN_PREP"
    elif "admin" in rpc: cat = "ADMIN"
    elif "prep_teacher" in rpc: cat = "TEACHER_CONCOURS"
    elif "ci_" in rpc: cat = "TEACHER_TD"
    elif "prep_student" in rpc: cat = "STUDENT_PREP"
    elif "prep_" in rpc: cat = "PREP_SHARED"
    elif "td_" in rpc: cat = "TD"
    elif "student" in rpc: cat = "STUDENT"
    elif "bobodo" in rpc: cat = "BOBODO"
    elif "community" in rpc: cat = "COMMUNITY"
    elif "marketplace" in rpc: cat = "MARKETPLACE"
    elif "university" in rpc or "uni_" in rpc: cat = "UNIVERSITY"
    elif "commercial" in rpc: cat = "COMMERCIAL"
    else: cat = "OTHER"
    categories[cat].append(rpc)

for cat, rpcs in sorted(categories.items()):
    print(f"\n  [{cat}] ({len(rpcs)} RPCs):")
    for rpc in rpcs:
        files = sorted(rpc_calls[rpc])
        print(f"    {rpc}")
        for f in files[:2]:
            print(f"      -> {f}")
        if len(files) > 2:
            print(f"      ... +{len(files)-2} fichiers")

print(f"\n[4] EDGE FUNCTIONS APPELEES ({len(edge_fn_calls)}):")
for fn, files in sorted(edge_fn_calls.items()):
    print(f"  {fn}:")
    for f in sorted(files):
        print(f"    -> {f}")

print("\n[5] RPCs FLUTTER vs SUPABASE - A VERIFIER:")
print("  (comparer manuellement avec audit_global_supabase.json)")

import json
out = Path(__file__).parent / "logs" / "audit_global_flutter.json"
out.parent.mkdir(exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    json.dump({
        "rpc_calls": {k: list(v) for k, v in rpc_calls.items()},
        "edge_fn_calls": {k: list(v) for k, v in edge_fn_calls.items()},
        "rpc_count": len(rpc_calls),
        "categories": {k: v for k, v in categories.items()},
    }, f, indent=2, ensure_ascii=False)
print(f"\nAudit Flutter saved: {out}")
