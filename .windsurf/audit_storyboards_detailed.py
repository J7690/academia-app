import requests
import json
from collections import Counter
from datetime import datetime

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT DÉTAILLÉ DES 20 STORYBOARDS RÉELS")
print("=" * 80)

# Récupérer les storyboards depuis whiteboard_ai_generations
sql = """
SELECT 
  id,
  created_by,
  generation_type,
  output_json,
  model_used,
  tokens_input,
  tokens_output,
  cost_usd,
  created_at
FROM app.whiteboard_ai_generations
WHERE generation_type = 'storyboard'
ORDER BY created_at DESC
LIMIT 20;
"""

print("\nRécupération des storyboards...")
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("STATUS:", resp.status_code)

if resp.status_code != 200:
    print("Erreur:", resp.text)
    exit(1)

data = resp.json()
storyboards = data.get('data', [])

print(f"Storyboards récupérés: {len(storyboards)}")

# Analyser la structure
block_type_counter = Counter()
scene_counter = Counter()
block_per_scene_counter = Counter()

for sb in storyboards:
    output_json = sb.get('output_json', {})
    scenes = output_json.get('scenes', [])
    
    scene_counter[len(scenes)] += 1
    
    for scene in scenes:
        blocks = scene.get('blocks', [])
        block_per_scene_counter[len(blocks)] += 1
        
        for block in blocks:
            block_type = block.get('type', 'unknown')
            block_type_counter[block_type] += 1

print("\n" + "=" * 80)
print("RÉSULTATS AUDIT")
print("=" * 80)

print("\nDistribution des scènes:")
for num_scenes, count in sorted(scene_counter.items()):
    print(f"  {num_scenes} scènes: {count} storyboards ({count/len(storyboards)*100:.1f}%)")

print("\nDistribution des blocs par scène:")
for num_blocks, count in sorted(block_per_scene_counter.items()):
    print(f"  {num_blocks} blocs: {count} scènes")

print("\nFréquence des types de blocs:")
total_blocks = sum(block_type_counter.values())
for block_type, count in block_type_counter.most_common():
    print(f"  {block_type}: {count} ({count/total_blocks*100:.1f}%)")

print("\n" + "=" * 80)
print("MATRICE BLOC ↔ FRÉQUENCE")
print("=" * 80)

print("\n| Type de bloc | Fréquence | Pourcentage |")
print("|-------------|-----------|------------|")
for block_type, count in block_type_counter.most_common():
    print(f"| {block_type:12} | {count:9} | {count/total_blocks*100:9.1f}% |")

# Sauvegarder les résultats
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
filename = f"storyboard_audit_detailed_{timestamp}.json"

with open(filename, 'w') as f:
    json.dump({
        'scene_distribution': dict(scene_counter),
        'block_per_scene_distribution': dict(block_per_scene_counter),
        'block_type_frequency': dict(block_type_counter),
        'total_storyboards': len(storyboards),
        'total_blocks': total_blocks,
    }, f, indent=2)

print(f"\nRésultats sauvegardés dans: {filename}")
