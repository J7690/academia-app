#!/usr/bin/env python3
"""
Vague 3 — Formules mathematiques ANIMEES via Manim (MIT), auto-heberge, 0 credit.

Rend un clip "ecriture" (Write) d'une formule LaTeX sur fond TRANSPARENT (.mov alpha),
composite ensuite par le moteur Remotion (OffthreadVideo). Repli automatique : si Manim
est absent/echoue, la formule reste rendue en KaTeX statique (rien ne casse).

Usage :
  python3 manim_render.py --latex "F(x) = \\int f(x)\\,dx + C" --out public/manim/x.mov

Pre-requis VPS (installe par Windsurf, voir doc) :
  pip install manim ; apt-get install -y texlive texlive-latex-extra dvisvgm
"""
import argparse
import subprocess
import tempfile
from pathlib import Path

SCENE_TEMPLATE = '''from manim import *

class FormulaScene(Scene):
    def construct(self):
        self.camera.background_opacity = 0
        tex = MathTex(r"""{latex}""", color=WHITE).scale(1.6)
        self.play(Write(tex), run_time=1.6)
        self.wait(0.6)
'''


def render(latex: str, out: Path) -> bool:
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        tdp = Path(td)
        scene_py = tdp / "scene.py"
        scene_py.write_text(SCENE_TEMPLATE.format(latex=latex.replace('"""', "'")), encoding="utf-8")
        # -qm : qualite moyenne ; --format=mov + -t : fond transparent (alpha)
        cmd = [
            "manim", "render", "-qm", "--format=mov", "-t",
            "--media_dir", str(tdp / "media"),
            str(scene_py), "FormulaScene",
        ]
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        if r.returncode != 0:
            return False
        movs = list((tdp / "media").rglob("*.mov"))
        if not movs:
            return False
        out.write_bytes(movs[0].read_bytes())
        return out.stat().st_size > 0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--latex", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    ok = False
    try:
        ok = render(a.latex, Path(a.out))
    except FileNotFoundError:
        ok = False  # manim non installe
    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
