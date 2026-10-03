"""Verify that a change touched only comments (IS-093).

Usage (inside a git worktree):  python check_comment_only.py <base-ref> [paths...]
For every changed .gd / .py / .gdshader file between <base-ref> and the working tree,
the code with comments and blank lines removed must be identical. Exits 1 on any
difference and prints the first differing lines per file.
"""
import subprocess, sys, io, re, tokenize

def strip_gd(text: str) -> list[str]:
    out = []
    for line in text.splitlines():
        res, q, i = [], None, 0
        while i < len(line):
            c = line[i]
            if q:
                res.append(c)
                if c == '\\' and i + 1 < len(line):
                    res.append(line[i + 1]); i += 2; continue
                if line.startswith(q, i):
                    res.append(line[i + 1:i + len(q)]); i += len(q); q = None; continue
            else:
                if line.startswith('"""', i) or line.startswith("'''", i):
                    q = line[i:i + 3]; res.append(q); i += 3; continue
                if c in '"\'':
                    q = c; res.append(c); i += 1; continue
                if c == '#':
                    break
                res.append(c)
            i += 1
        s = ''.join(res).rstrip()
        if s.strip():
            out.append(s)
    return out

def strip_py(text: str) -> list[str]:
    # drop comments and docstrings (string expression statements)
    toks = []
    try:
        gen = list(tokenize.generate_tokens(io.StringIO(text).readline))
    except (tokenize.TokenError, IndentationError):
        return strip_gd(text)
    prev = None
    for t in gen:
        if t.type == tokenize.COMMENT:
            continue
        if t.type == tokenize.STRING and prev in (None, tokenize.INDENT, tokenize.DEDENT, tokenize.NEWLINE, tokenize.NL):
            prev = t.type; continue
        if t.type in (tokenize.NL, tokenize.NEWLINE, tokenize.INDENT, tokenize.DEDENT, tokenize.ENCODING, tokenize.ENDMARKER):
            prev = t.type; continue
        toks.append(t.string); prev = t.type
    return toks

def show(ref: str, path: str) -> str:
    r = subprocess.run(['git', 'show', f'{ref}:{path}'], capture_output=True)
    return r.stdout.decode('utf-8') if r.returncode == 0 else ''

def main() -> int:
    ref = sys.argv[1]
    paths = sys.argv[2:]
    names = subprocess.run(['git', 'diff', '--name-only', ref, '--'] + paths, capture_output=True, text=True, encoding='utf-8').stdout.split()
    bad = 0
    checked = 0
    for p in names:
        if not p.endswith(('.gd', '.py', '.gdshader')):
            continue
        try:
            new = io.open(p, encoding='utf-8').read()
        except FileNotFoundError:
            print(f'DELETED {p}'); bad += 1; continue
        old = show(ref, p)
        f = strip_py if p.endswith('.py') else strip_gd
        a, b = f(old), f(new)
        checked += 1
        if a != b:
            bad += 1
            for i, (x, y) in enumerate(zip(a, b)):
                if x != y:
                    print(f'CODE CHANGED {p}: #{i}\n  - {x}\n  + {y}'); break
            else:
                print(f'CODE CHANGED {p}: length {len(a)} -> {len(b)}')
    print(f'checked {checked} files, {bad} with code changes')
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
