#!/usr/bin/env python3
"""PHASE 3: Analyse statique approfondie des chemins d'activation des 68 RPC"""
import os, re, json

with open('rpc_matrix_full.json') as f:
    matrix = json.load(f)

with open('flutter_rpc_detailed.json') as f:
    detailed = json.load(f)

# Only problematic RPCs
problematic = [d for d in detailed if d['status'] in ('B', 'C', 'D')]

flutter_dir = r'C:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib'

# For each RPC, read the surrounding code to determine:
# - try-catch presence
# - error handling (silent vs visible)
# - activation path (initState, onPressed, timer, background)
# - user-facing or not

def analyze_context(filepath, line_num):
    """Read +/- 15 lines around the RPC call to determine context."""
    full_path = os.path.join(flutter_dir, filepath)
    try:
        with open(full_path, 'r', encoding='utf-8') as fh:
            lines = fh.readlines()
    except Exception:
        return {}

    start = max(0, line_num - 20)
    end = min(len(lines), line_num + 15)
    context = ''.join(lines[start:end])

    result = {
        'has_try': False,
        'has_catch': False,
        'error_visible': False,  # SnackBar, AlertDialog, setError, etc.
        'error_silent': False,   # debugPrint, catch(e){}, empty catch
        'activation_path': 'unknown',
        'user_facing': False,
        'widget_name': None,
        'function_name': None,
    }

    # Detect try-catch
    # Look backwards for "try {" before the RPC line
    before = ''.join(lines[start:line_num])
    after = ''.join(lines[line_num:end])

    if re.search(r'\btry\s*\{', before):
        result['has_try'] = True
    if re.search(r'\bcatch\s*\(', after) or re.search(r'\bcatch\s*\(', before):
        result['has_catch'] = True

    # Error visibility
    catch_block = ''
    if result['has_catch']:
        # Extract catch block content
        catch_match = re.search(r'catch\s*\([^)]*\)\s*\{([^}]*)\}', after, re.DOTALL)
        if catch_match:
            catch_block = catch_match.group(1)
        else:
            # Search further
            for i in range(line_num, min(len(lines), line_num + 30)):
                catch_match = re.search(r'catch\s*\([^)]*\)\s*\{([^}]*)\}', ''.join(lines[i:i+5]), re.DOTALL)
                if catch_match:
                    catch_block = catch_match.group(1)
                    break

    if catch_block:
        if re.search(r'SnackBar|AlertDialog|showDialog|ScaffoldMessenger|setError|_setError|print\(|debugPrint\(', catch_block):
            result['error_silent'] = True  # At least it's logged
        if re.search(r'SnackBar|AlertDialog|showDialog|ScaffoldMessenger|setState.*error|_setError', catch_block):
            result['error_visible'] = True
        if re.search(r'debugPrint|print\(', catch_block) and not result['error_visible']:
            result['error_silent'] = True
        if catch_block.strip() in ('', '// ignore', '// TODO'):
            result['error_silent'] = True

    # Activation path
    full_context = before + after
    if re.search(r'onPressed|onTap|onLongPress|GestureDetector.*onTap|IconButton|ElevatedButton|TextButton', full_context):
        result['activation_path'] = 'user_action'
        result['user_facing'] = True
    elif re.search(r'initState|didChangeDependencies|Future\.delayed|Timer\.periodic|Timer\(', full_context):
        result['activation_path'] = 'auto_init'
        result['user_facing'] = True
    elif re.search(r'Timer\.periodic|_batchTimer|_flushBatch|_sync', full_context):
        result['activation_path'] = 'background_timer'
        result['user_facing'] = False
    elif re.search(r'Future\.delayed|_loadData|load[A-Z]|fetch[A-Z]|refresh[A-Z]', full_context):
        result['activation_path'] = 'auto_load'
        result['user_facing'] = True

    # Extract function name
    func_match = re.search(r'(Future<\w+>\s+)?(\w+)\s*\([^)]*\)\s*\{', before)
    if func_match:
        result['function_name'] = func_match.group(2)

    # Extract class/widget name
    class_match = re.search(r'class\s+(\w+)', before)
    if class_match:
        result['widget_name'] = class_match.group(1)

    return result

# Build qualification
qualification = []
for rpc_data in problematic:
    rpc = rpc_data['rpc']
    status = rpc_data['status']

    occs = rpc_data.get('occurrences', [])
    files = rpc_data.get('files', [])

    # Aggregate analysis across all occurrences
    contexts = []
    for occ in occs[:3]:  # Analyze first 3 occurrences max
        ctx = analyze_context(occ['file'], occ['line'])
        contexts.append(ctx)

    # Determine impact class
    impact = 'unknown'
    recommendation = ''

    if status == 'D':
        impact = 'D'
        recommendation = 'ignore_or_cleanup'
    elif status == 'C':
        if rpc_data['occurrence_count'] == 0:
            impact = 'C'
            recommendation = 'implement_or_remove'
        else:
            impact = 'A'
            recommendation = 'implement_urgently'
    elif status == 'B':
        # Analyze if broken and visible
        has_visible_error = any(c.get('error_visible') for c in contexts)
        has_silent_error = any(c.get('error_silent') for c in contexts)
        is_user_action = any(c.get('activation_path') == 'user_action' for c in contexts)
        is_auto_init = any(c.get('activation_path') == 'auto_init' for c in contexts)
        is_background = any(c.get('activation_path') == 'background_timer' for c in contexts)

        if rpc_data['occurrence_count'] == 0:
            impact = 'C'
            recommendation = 'verify_or_remove'
        elif is_background:
            impact = 'B'
            recommendation = 'fix_soon'
        elif is_user_action and not has_visible_error and not has_silent_error:
            # No try-catch around user action -> raw error visible
            impact = 'A'
            recommendation = 'fix_immediately'
        elif is_user_action and has_visible_error:
            impact = 'A'
            recommendation = 'fix_immediately'
        elif is_user_action and has_silent_error and not has_visible_error:
            impact = 'B'
            recommendation = 'fix_soon'
        elif is_auto_init and has_visible_error:
            impact = 'A'
            recommendation = 'fix_immediately'
        elif is_auto_init and has_silent_error:
            impact = 'B'
            recommendation = 'fix_soon'
        elif is_auto_init:
            impact = 'A'
            recommendation = 'fix_immediately'
        else:
            impact = 'B'
            recommendation = 'fix_soon'

    qualification.append({
        'rpc': rpc,
        'status': status,
        'occurrence_count': rpc_data['occurrence_count'],
        'files': files,
        'impact_class': impact,
        'recommendation': recommendation,
        'contexts': contexts,
    })

# Sort by impact
order = {'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4}
qualification.sort(key=lambda x: order.get(x['impact_class'], 99))

with open('rpc_qualification_deep.json', 'w', encoding='utf-8') as f:
    json.dump(qualification, f, indent=2, ensure_ascii=False)

# Summary
summary = {}
for q in qualification:
    summary[q['impact_class']] = summary.get(q['impact_class'], 0) + 1

print("=== QUALIFICATION DES 68 RPC PROBLEMATIQUES ===")
print(f"A (Cassé et visible): {summary.get('A', 0)}")
print(f"B (Cassé mais masqué): {summary.get('B', 0)}")
print(f"C (Non utilisé): {summary.get('C', 0)}")
print(f"D (Utilisé mais fonctionne): {summary.get('D', 0)}")
print(f"E (Obsolète): {summary.get('E', 0)}")
print()
print("=== LISTE PAR CLASSE ===")
for q in qualification:
    print(f"[{q['impact_class']}] {q['rpc']} ({q['status']}) -> {q['recommendation']}")
