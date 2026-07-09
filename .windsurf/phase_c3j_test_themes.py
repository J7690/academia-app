"""
Phase C.3J – Test THEMES
Vérifie que le renderer charge THEMES correctement
"""

import sys
sys.path.append(r"c:\Users\fasop\AndroidStudioProjects\academia\academia_bobodo_backend")

from whiteboard_png_renderer import THEMES

print("=== PHASE C.3J – TEST THEMES ===\n")

print("THEMES chargés :")
for theme_name, theme_config in THEMES.items():
    print(f"  {theme_name} : {theme_config}")
print()

print("Vérification THEMES['scientific'] :")
print(f"  {THEMES['scientific']}")
print()

print("Vérification THEMES['notebook'] :")
print(f"  {THEMES['notebook']}")
print()

print("=== TEST THEMES TERMINÉ ===\n")
