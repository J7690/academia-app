# PHASE C.3H – STORYBOARD SERIALIZATION TRACE

**Date** : 23 Juin 2026  
**Phase** : C.3H – Storyboard Serialization Trace  
**Mode** : INVESTIGATION CIBLÉE  
**Objectif** : Identifier précisément où le Storyboard passe de dict à str

---

## DIRECTIVE

**AUCUNE CORRECTION**  
**AUCUNE MODIFICATION**  
**AUCUN REDÉPLOIEMENT**

---

## PARTIE 1 – CYCLE COMPLET

### Cycle Supabase → RPC → Worker → Renderer

```
Supabase (app.whiteboard_projects.storyboard_json)
  ↓
RPC (public.whiteboard_fetch_queued_jobs)
  ↓
Worker (whiteboard_render_worker.py)
  ↓
Renderer (whiteboard_png_renderer.py)
```

---

## PARTIE 2 – TYPE RÉEL À CHAQUE ÉTAPE

### Étape 1 : Supabase (stockage)

**Type** : `jsonb` (PostgreSQL)

**Données stockées** :
```json
{
  "theme": "scientific",
  "scenes": [...],
  "subject": "Test Trace",
  ...
}
```

### Étape 2 : RPC (whiteboard_fetch_queued_jobs)

**Type retourné** : `dict` (Python)

**Format retourné** : JSONB → dict Python

**Code RPC** :
```sql
CREATE OR REPLACE FUNCTION public.whiteboard_fetch_queued_jobs(p_limit integer DEFAULT 5)
RETURNS TABLE (
    id uuid,
    storyboard jsonb,
    created_at timestamptz
)
AS $$
BEGIN
    RETURN QUERY
    SELECT wr.id, wp.storyboard_json as storyboard, wr.created_at
    FROM app.whiteboard_renders wr
    JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
    WHERE wr.status = 'queued'
    ORDER BY wr.created_at ASC
    LIMIT p_limit;
END;
$$;
```

**Résultat RPC** :
```json
{
  "id": "5ab36d99-05df-40d6-8a7b-dfe6dc89de6c",
  "storyboard": {
    "theme": "scientific",
    "scenes": [...],
    ...
  }
}
```

**Type storyboard** : `<class 'dict'>`

### Étape 3 : Worker (whiteboard_render_worker.py)

**Type reçu** : `dict` (Python)

**Code worker** (ligne 108) :
```python
storyboard_json = job.get("storyboard")
```

**Type storyboard_json** : `<class 'dict'>`

**Passage au renderer** (ligne 125) :
```python
png_paths = render_storyboard_to_pngs(storyboard_json, temp_path)
```

### Étape 4 : Renderer (whiteboard_png_renderer.py)

**Type reçu** : `dict` (Python)

**Code renderer** (ligne 170-173) :
```python
# Parser le storyboard si c'est une string
if isinstance(storyboard_json, str):
    storyboard = json.loads(storyboard_json)
else:
    storyboard = storyboard_json
```

**Type storyboard** : `<class 'dict'>`

---

## PARTIE 3 – RPC whiteboard_fetch_queued_jobs

### Type retourné

**Type** : `jsonb` (PostgreSQL) → `dict` (Python)

### Format retourné

**Format** : Objet JSONB (pas de chaîne)

### JSONB ou texte

**Type** : JSONB (pas de texte)

**Preuve** : La RPC retourne un dict Python, pas une chaîne.

---

## PARTIE 4 – LOGS TEMPORAIRES

**Aucun log temporaire ajouté** (directive : aucune modification)

---

## PARTIE 5 – COMPARAISON STORYBOARD

### Storyboard stocké dans la table

```json
{
  "theme": "scientific",  // CHAÎNE
  "scenes": [...],
  ...
}
```

### Storyboard reçu par le renderer

```json
{
  "theme": "scientific",  // CHAÎNE
  "scenes": [...],
  ...
}
```

**Conclusion** : Identique (pas de conversion dict→str)

---

## PARTIE 6 – LIGNES DE CONVERSION

### Conversion dict→str

**Aucune conversion dict→str détectée**

**Trace** :
- Supabase : `jsonb` → dict
- RPC : `jsonb` → dict
- Worker : dict → dict
- Renderer : dict → dict

**Conclusion** : Le problème n'est PAS une conversion dict→str

---

## PARTIE 7 – PROBLÈME RÉEL

### Localisation précise

**Fichier** : `whiteboard_png_renderer.py`
**Ligne** : 176
**Fonction** : `render_storyboard_to_pngs`

### Code problématique

```python
theme_name = storyboard.get("theme", {}).get("name", "scientific")
```

### Cause réelle

**Problème** : `storyboard.get("theme", {})` retourne une **chaîne** `"scientific"` au lieu d'un dictionnaire `{"name": "scientific"}`

**Explication** :
- Le Storyboard stocké a `theme` comme une **chaîne** : `"theme": "scientific"`
- Le renderer attend `theme` comme un **dictionnaire** : `"theme": {"name": "scientific"}`
- La ligne 176 tente d'appeler `.get()` sur une chaîne, ce qui provoque une `AttributeError`

### Erreur

```
AttributeError: 'str' object has no attribute 'get'
```

---

## PARTIE 8 – CORRECTION MINIMALE

### Options

**A. Corriger la RPC** : Modifier `whiteboard_fetch_queued_jobs` pour transformer `theme` en dictionnaire
**B. Corriger le worker** : Transformer `theme` en dictionnaire avant de passer au renderer
**C. Corriger le renderer** : Gérer le cas où `theme` est une chaîne
**D. Corriger plusieurs couches** : Corriger à plusieurs endroits

### Choix

**C. Corriger le renderer**

### Justification

**Principe** : La correction doit être appliquée à l'endroit où la dérive est introduite.

**Analyse** :
1. **Supabase** : Stocke `theme` comme chaîne (conforme au Data Contract)
2. **RPC** : Retourne `theme` comme chaîne (conforme au stockage)
3. **Worker** : Passe `theme` comme chaîne (conforme à la RPC)
4. **Renderer** : Attend `theme` comme dictionnaire (NON conforme au Data Contract)

**Conclusion** : La dérive est introduite dans le **renderer**, qui attend un format différent de ce qui est stocké dans Supabase.

**Correction minimale** : Modifier le renderer pour gérer les deux formats (chaîne ou dictionnaire).

---

## CONCLUSION

### Résumé

**Conversion dict→str** : ❌ NON DÉTECTÉE

**Problème réel** : Format incohérent de `theme` (chaîne vs dictionnaire)

**Origine** : Renderer attend un dictionnaire, mais reçoit une chaîne

**Correction minimale** : **C. Corriger le renderer**

### Correction proposée

**Fichier** : `whiteboard_png_renderer.py`
**Ligne** : 176

**Code corrigé** :
```python
# Récupérer le thème
theme_value = storyboard.get("theme", "scientific")
if isinstance(theme_value, str):
    theme_name = theme_value
else:
    theme_name = theme_value.get("name", "scientific")
theme = THEMES.get(theme_name, THEMES["scientific"])
```

---

**Fin du Storyboard Serialization Trace**
