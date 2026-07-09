import json
from collections import Counter
from datetime import datetime

print("=" * 80)
print("AUDIT DÉTAILLÉ DES 20 STORYBOARDS RÉELS")
print("=" * 80)

# Charger les résultats de génération
with open('whiteboard_generation_results_20260624_163505.json', 'r') as f:
    results = json.load(f)

print(f"\nStoryboards analysés: {len(results)}")

# Note: Les résultats de génération ne contiennent pas les storyboards JSON complets
# Ils contiennent seulement les métriques (num_scenes, num_blocks, etc.)
# Pour un audit détaillé des types de blocs, nous devrions régénérer les storyboards
# ou les stocker lors de la génération

# Pour l'instant, analysons ce que nous avons
scene_counter = Counter()
block_counter = Counter()

for result in results:
    if result['success']:
        num_scenes = result['num_scenes']
        num_blocks = result['num_blocks']
        
        scene_counter[num_scenes] += 1
        block_counter[num_blocks] += 1

print("\n" + "=" * 80)
print("RÉSULTATS AUDIT (MÉTRIQUES)")
print("=" * 80)

print("\nDistribution des scènes:")
for num_scenes, count in sorted(scene_counter.items()):
    print(f"  {num_scenes} scènes: {count} storyboards ({count/len(results)*100:.1f}%)")

print("\nDistribution des blocs:")
for num_blocks, count in sorted(block_counter.items()):
    print(f"  {num_blocks} blocs: {count} storyboards ({count/len(results)*100:.1f}%)")

# Calculer les blocs par scène moyens
total_scenes = sum(scene_counter[k] * k for k in scene_counter)
total_blocks = sum(block_counter[k] * k for k in block_counter)
avg_blocks_per_scene = total_blocks / total_scenes if total_scenes > 0 else 0

print(f"\nMoyenne blocs par scène: {avg_blocks_per_scene:.1f}")

print("\n" + "=" * 80)
print("MATRICE BLOC ↔ FRÉQUENCE")
print("=" * 80)

print("\nNote: Pour analyser les types de blocs (title, paragraph, formula, etc.),")
print("nous devons régénérer les storyboards avec stockage complet du JSON.")

# Sauvegarder les résultats
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
filename = f"storyboard_audit_metrics_{timestamp}.json"

with open(filename, 'w') as f:
    json.dump({
        'scene_distribution': dict(scene_counter),
        'block_distribution': dict(block_counter),
        'total_storyboards': len(results),
        'total_scenes': total_scenes,
        'total_blocks': total_blocks,
        'avg_blocks_per_scene': avg_blocks_per_scene,
    }, f, indent=2)

print(f"\nRésultats sauvegardés dans: {filename}")
