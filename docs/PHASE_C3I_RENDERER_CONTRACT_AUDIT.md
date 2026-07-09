# PHASE C.3I – RENDERER CONTRACT AUDIT

**Date** : 23 Juin 2026  
**Phase** : C.3I – Renderer Contract Audit  
**Mode** : AUDIT  
**Objectif** : Vérifier que le renderer est compatible à 100 % avec le Data Contract Smart Whiteboard V1

---

## DIRECTIVE

**AUCUNE CORRECTION**  
**AUCUNE MODIFICATION**  
**AUCUN REDÉPLOIEMENT**

---

## PARTIE 1 – COMPARAISON DATA CONTRACT VS RENDERER

### SMART_WHITEBOARD_DATA_CONTRACT.md

**Storyboard structure** (lignes 88-100):
```json
{
  "version": "1.0",
  "created_at": "iso8601",
  "created_by": "uuid",
  "subject": "string",
  "renderer": "scientific|notebook",
  "theme": "scientific|notebook",
  "narration_mode": "none|tts|user_recording",
  "export_settings": {},
  "scenes": []
}
```

**Storyboard fields** (lignes 104-114):
| Champ | Type | Obligatoire |
|-------|------|-------------|
| version | String | ✅ |
| created_at | ISO8601 | ✅ |
| created_by | UUID | ✅ |
| subject | String | ✅ |
| renderer | String | ✅ |
| theme | String | ✅ |
| narration_mode | String | ✅ |
| export_settings | JSON | ✅ |
| scenes | Array | ✅ |

**Block structure** (lignes 170-180):
```json
{
  "id": "uuid",
  "type": "string",
  "content": "string",
  "order": "integer",
  "visible": "boolean",
  "animation": {},
  "position": {},
  "style": {}
}
```

**Block fields** (lignes 185-194):
| Champ | Type | Obligatoire |
|-------|------|-------------|
| id | UUID | ✅ |
| type | String | ✅ |
| content | String | ✅ |
| order | Integer | ✅ |
| visible | Boolean | ✅ |
| animation | JSON | ❌ |
| position | JSON | ❌ |
| style | JSON | ✅ |

### whiteboard_png_renderer.py

**Line 176**:
```python
theme_name = storyboard.get("theme", {}).get("name", "scientific")
```

**Line 180**:
```python
scenes = storyboard.get("scenes", [])
```

**Line 191**:
```python
blocks = scene.get("blocks", [])
```

**Line 138**:
```python
block_type = block.get("type")
```

**Line 139**:
```python
content = block.get("content", "")
```

---

## PARTIE 2 – TABLEAU CHAMP ATTENDU VS CHAMP UTILISÉ

| Champ attendu | Type attendu | Champ utilisé | Type réellement attendu par renderer | Conformité |
|---------------|--------------|---------------|--------------------------------------|------------|
| theme | String | storyboard.get("theme", {}) | Dict avec clé "name" | ❌ NON CONFORME |
| renderer | String | Non utilisé | - | ✅ CONFORME |
| narration_mode | String | Non utilisé | - | ✅ CONFORME |
| export_settings | JSON | Non utilisé | - | ✅ CONFORME |
| scenes | Array | storyboard.get("scenes", []) | Array | ✅ CONFORME |
| blocks | Array | scene.get("blocks", []) | Array | ✅ CONFORME |
| block.type | String | block.get("type") | String | ✅ CONFORME |
| block.content | String | block.get("content", "") | String | ✅ CONFORME |
| block.style | JSON | Non utilisé | - | ✅ CONFORME |
| block.animation | JSON | Non utilisé | - | ✅ CONFORME |

---

## PARTIE 3 – VÉRIFICATION CHAMPS CLÉS

### theme

**Data Contract** : String (`"scientific|notebook"`)

**Renderer** : Attend Dict avec clé `"name"`

**Code renderer** (ligne 176):
```python
theme_name = storyboard.get("theme", {}).get("name", "scientific")
```

**Conclusion** : ❌ **NON CONFORME**

### renderer

**Data Contract** : String (`"scientific|notebook"`)

**Renderer** : Non utilisé

**Conclusion** : ✅ **CONFORME**

### narration_mode

**Data Contract** : String (`"none|tts|user_recording"`)

**Renderer** : Non utilisé

**Conclusion** : ✅ **CONFORME**

### export_settings

**Data Contract** : JSON

**Renderer** : Non utilisé

**Conclusion** : ✅ **CONFORME**

### scenes

**Data Contract** : Array

**Renderer** : Array

**Code renderer** (ligne 180):
```python
scenes = storyboard.get("scenes", [])
```

**Conclusion** : ✅ **CONFORME**

### blocks

**Data Contract** : Array

**Renderer** : Array

**Code renderer** (ligne 191):
```python
blocks = scene.get("blocks", [])
```

**Conclusion** : ✅ **CONFORME**

### block.type

**Data Contract** : String

**Renderer** : String

**Code renderer** (ligne 138):
```python
block_type = block.get("type")
```

**Conclusion** : ✅ **CONFORME**

### block.content

**Data Contract** : String

**Renderer** : String

**Code renderer** (ligne 139):
```python
content = block.get("content", "")
```

**Conclusion** : ✅ **CONFORME**

### block.style

**Data Contract** : JSON

**Renderer** : Non utilisé

**Conclusion** : ✅ **CONFORME**

### block.animation

**Data Contract** : JSON

**Renderer** : Non utilisé

**Conclusion** : ✅ **CONFORME**

---

## PARTIE 4 – SUPPOSITIONS DICT VS STRING

### Endroits où renderer suppose dict alors que contrat fournit string

| Ligne | Code renderer | Type attendu | Type réel | Écart |
|-------|---------------|--------------|-----------|-------|
| 176 | `storyboard.get("theme", {}).get("name", "scientific")` | String | Dict | ❌ ÉCART |

**Conclusion** : 1 écart détecté (champ `theme`)

---

## PARTIE 5 – ACCÈS POTENTIELLEMENT DANGEREUX

### Accès identifiés

| Ligne | Code | Type d'accès | Danger |
|-------|------|--------------|--------|
| 176 | `storyboard.get("theme", {}).get("name", "scientific")` | `.get()` sur dict | ❌ CRITIQUE (si theme est string) |
| 58 | `theme["title_font_size"]` | `[]` sur dict | ⚠️ MAJEUR (si clé manquante) |
| 59 | `theme["text_color"]` | `[]` sur dict | ⚠️ MAJEUR (si clé manquante) |
| 73 | `theme["paragraph_font_size"]` | `[]` sur dict | ⚠️ MAJEUR (si clé manquante) |
| 74 | `theme["text_color"]` | `[]` sur dict | ⚠️ MAJEUR (si clé manquante) |
| 88 | `theme["definition_font_size"]` | `[]` sur dict | ⚠️ MAJEUR (si clé manquante) |
| 89 | `theme["text_color"]` | `[]` sur dict | ⚠️ MAJEUR (si clé manquante) |
| 99 | `theme["exercise_font_size"]` | `[]` sur dict | ⚠️ MAJEUR (si clé manquante) |
| 100 | `theme["text_color"]` | `[]` sur dict | ⚠️ MAJEUR (si clé manquante) |
| 110 | `theme["correction_font_size"]` | `[]` sur dict | ⚠️ MAJEUR (si clé manquante) |
| 111 | `theme["accent_color"]` | `[]` sur dict | ⚠️ MAJEUR (si clé manquante) |

**Conclusion** : 1 accès CRITIQUE, 10 accès MAJEURS

---

## PARTIE 6 – CLASSIFICATION DES ÉCARTS

### Écart 1 : theme (ligne 176)

**Gravité** : **CRITIQUE**

**Justification** :
- Provoque une `AttributeError` immédiate
- Bloque l'exécution du pipeline
- Incompatible avec le Data Contract

### Écarts 2-11 : Accès directs aux clés theme (lignes 58, 59, 73, 74, 88, 89, 99, 100, 110, 111)

**Gravité** : **MAJEUR**

**Justification** :
- Risque de `KeyError` si clé manquante
- Non défensif
- Devrait utiliser `.get()` avec valeur par défaut

---

## PARTIE 7 – CORRECTION THEME SUFFIT-ELLE ?

### Réponse

**OUI**

### Justification

**Écarts identifiés** :
1. **CRITIQUE** : Ligne 176 (theme)
2. **MAJEURS** : Lignes 58, 59, 73, 74, 88, 89, 99, 100, 110, 111 (accès directs theme)

**Analyse** :
- L'écart CRITIQUE (ligne 176) est la cause du blocage actuel
- Les écarts MAJEURS (accès directs) ne provoqueront pas d'erreur tant que le thème est correctement chargé
- Le thème est chargé depuis `THEMES` (ligne 177), qui contient toutes les clés requises
- Les accès directs sont donc sûrs une fois le thème chargé

**Conclusion** : Corriger uniquement l'écart CRITIQUE (ligne 176) suffira pour exécuter le pipeline jusqu'au bout.

---

## PARTIE 8 – LISTE EXACTE DES CORRECTIONS MINIMALES

### Correction 1 : Ligne 176 (CRITIQUE)

**Fichier** : `whiteboard_png_renderer.py`
**Ligne** : 176

**Code actuel** :
```python
theme_name = storyboard.get("theme", {}).get("name", "scientific")
```

**Code corrigé** :
```python
theme_name = storyboard.get("theme", "scientific")
```

**Justification** : Le Data Contract spécifie que `theme` est une String, pas un Dict.

### Corrections 2-11 : Lignes 58, 59, 73, 74, 88, 89, 99, 100, 110, 111 (MAJEUR - OPTIONNEL)

**Fichier** : `whiteboard_png_renderer.py`

**Code actuel** (exemple ligne 58) :
```python
font = _get_font(theme["title_font_size"])
```

**Code corrigé** (optionnel) :
```python
font = _get_font(theme.get("title_font_size", 32))
```

**Justification** : Utiliser `.get()` avec valeur par défaut pour éviter les `KeyError`.

**Note** : Ces corrections sont OPTIONNELLES car le thème est chargé depuis `THEMES`, qui contient toutes les clés requises.

---

## CONCLUSION

### Résumé

**Écarts détectés** : 11 (1 CRITIQUE, 10 MAJEURS)

**Correction minimale requise** : 1 (ligne 176)

**Correction theme suffit-elle** : **OUI**

### Affirmation

**Après correction de l'écart identifié (ligne 176), le pipeline Storyboard → PNG → FFmpeg → MP4 pourra être exécuté jusqu'au bout.**

---

**Fin du Renderer Contract Audit**
