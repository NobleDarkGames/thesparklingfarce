#!/usr/bin/env python3
"""
Fix UNSAFE_CAST and UNSAFE_CALL_ARGUMENT warnings in GDScript files.

Transforms:
    var x: SomeType = something as SomeType
To:
    var _res: Resource = something
    var x: SomeType = _res if _res is SomeType else null

Also fixes:
    str(dict.get("key", "")) -> DictUtils.get_string(dict, "key", "")
    int(dict.get("key", 0)) -> DictUtils.get_int(dict, "key", 0)
"""

import re
import sys
from pathlib import Path

# Types that commonly appear in unsafe casts
RESOURCE_TYPES = [
    'CharacterData', 'SpriteFrames', 'Texture2D', 'PackedScene',
    'BattleData', 'CampaignData', 'ItemData', 'NPCData',
    'DialogueData', 'MapMetadata', 'ClassData', 'CaravanData',
    'InteractableData', 'ShopData', 'SpellData', 'AIBehaviorData',
]


def fix_conversion_on_get(content: str) -> tuple[str, int]:
    """Fix patterns like str(dict.get("key")) -> DictUtils.get_string(dict, "key")"""
    fixes = 0

    # Pattern: str(something.get("key", default))
    # Match: str(var.get("key", "default")) or str(var.get("key"))
    str_pattern = re.compile(
        r'\bstr\((\w+(?:\.\w+)*)\.get\("([^"]+)"(?:,\s*("[^"]*"|[^)]*))?\)\)'
    )

    def replace_str(m):
        nonlocal fixes
        var_name = m.group(1)
        key = m.group(2)
        default = m.group(3) if m.group(3) else '""'
        fixes += 1
        return f'DictUtils.get_string({var_name}, "{key}", {default})'

    content = str_pattern.sub(replace_str, content)

    # Pattern: int(something.get("key", default))
    int_pattern = re.compile(
        r'\bint\((\w+(?:\.\w+)*)\.get\("([^"]+)"(?:,\s*(\d+|[^)]*))?\)\)'
    )

    def replace_int(m):
        nonlocal fixes
        var_name = m.group(1)
        key = m.group(2)
        default = m.group(3) if m.group(3) else '0'
        fixes += 1
        return f'DictUtils.get_int({var_name}, "{key}", {default})'

    content = int_pattern.sub(replace_int, content)

    # Pattern: bool(something.get("key", default))
    bool_pattern = re.compile(
        r'\bbool\((\w+(?:\.\w+)*)\.get\("([^"]+)"(?:,\s*(true|false|[^)]*))?\)\)'
    )

    def replace_bool(m):
        nonlocal fixes
        var_name = m.group(1)
        key = m.group(2)
        default = m.group(3) if m.group(3) else 'false'
        fixes += 1
        return f'DictUtils.get_bool({var_name}, "{key}", {default})'

    content = bool_pattern.sub(replace_bool, content)

    # Pattern: float(something.get("key", default))
    float_pattern = re.compile(
        r'\bfloat\((\w+(?:\.\w+)*)\.get\("([^"]+)"(?:,\s*([\d.]+|[^)]*))?\)\)'
    )

    def replace_float(m):
        nonlocal fixes
        var_name = m.group(1)
        key = m.group(2)
        default = m.group(3) if m.group(3) else '0.0'
        fixes += 1
        return f'DictUtils.get_float({var_name}, "{key}", {default})'

    content = float_pattern.sub(replace_float, content)

    return content, fixes

def fix_file(filepath: Path, dry_run: bool = False) -> int:
    """Fix unsafe casts in a single file. Returns number of fixes made."""
    content = filepath.read_text()
    original = content
    fixes = 0

    # First, fix conversion functions on .get() calls
    content, conv_fixes = fix_conversion_on_get(content)
    fixes += conv_fixes

    for type_name in RESOURCE_TYPES:
        # Pattern: var x: Type = something as Type
        # Capture: (indent)(var name: Type = )(something)( as Type)
        pattern = re.compile(
            rf'^(\s*)(var \w+: {type_name} = )(.+?)( as {type_name})(\s*)$',
            re.MULTILINE
        )

        def replace_cast(m):
            nonlocal fixes
            indent = m.group(1)
            var_decl = m.group(2)  # "var x: Type = "
            something = m.group(3).strip()
            trailing = m.group(5)

            # Extract variable name
            var_match = re.match(r'var (\w+):', var_decl)
            var_name = var_match.group(1) if var_match else 'result'

            # Generate unique temp var name
            temp_var = f'_{var_name}_res'

            fixes += 1

            # Two-line replacement
            line1 = f'{indent}var {temp_var}: Resource = {something}'
            line2 = f'{indent}var {var_name}: {type_name} = {temp_var} if {temp_var} is {type_name} else null{trailing}'
            return f'{line1}\n{line2}'

        content = pattern.sub(replace_cast, content)

    # Handle return statements: return something as Type
    for type_name in RESOURCE_TYPES:
        pattern = re.compile(
            rf'^(\s*)(return )(.+?)( as {type_name})(\s*)$',
            re.MULTILINE
        )

        def replace_return_cast(m):
            nonlocal fixes
            indent = m.group(1)
            something = m.group(3).strip()
            trailing = m.group(5)

            temp_var = '_return_res'
            fixes += 1

            line1 = f'{indent}var {temp_var}: Resource = {something}'
            line2 = f'{indent}return {temp_var} if {temp_var} is {type_name} else null{trailing}'
            return f'{line1}\n{line2}'

        content = pattern.sub(replace_return_cast, content)

    # Also handle inline casts like: foo.bar = load(x) as Type
    for type_name in RESOURCE_TYPES:
        # Pattern for assignment (not var declaration)
        # e.g., item.icon = load(path) as Texture2D
        pattern = re.compile(
            rf'^(\s*)(\w+(?:\.\w+)*) = (.+?) as ({type_name})(\s*)$',
            re.MULTILINE
        )

        def replace_assignment_cast(m):
            nonlocal fixes
            indent = m.group(1)
            target = m.group(2)  # e.g., "item.icon"
            something = m.group(3).strip()
            type_n = m.group(4)
            trailing = m.group(5)

            # Generate temp var name from target
            temp_var = '_loaded_res'

            fixes += 1

            line1 = f'{indent}var {temp_var}: Resource = {something}'
            line2 = f'{indent}{target} = {temp_var} if {temp_var} is {type_n} else null{trailing}'
            return f'{line1}\n{line2}'

        content = pattern.sub(replace_assignment_cast, content)

    if content != original:
        if not dry_run:
            filepath.write_text(content)
        print(f'{filepath}: {fixes} fixes')

    return fixes

def main():
    dry_run = '--dry-run' in sys.argv

    if dry_run:
        print("DRY RUN - no files will be modified\n")

    # Find all .gd files, excluding tests and gdUnit4
    root = Path('/home/homeuser/dev/sparklingfarce')
    gd_files = []

    for pattern in ['core/**/*.gd', 'scenes/**/*.gd', 'addons/sparkling_editor/**/*.gd']:
        gd_files.extend(root.glob(pattern))

    # Filter out test files
    gd_files = [f for f in gd_files if 'test' not in str(f).lower() and 'gdUnit4' not in str(f)]

    total_fixes = 0
    for filepath in sorted(gd_files):
        fixes = fix_file(filepath, dry_run)
        total_fixes += fixes

    print(f'\nTotal: {total_fixes} fixes' + (' (dry run)' if dry_run else ''))

if __name__ == '__main__':
    main()
