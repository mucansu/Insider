#!/usr/bin/env python3
"""Sub-agent PreToolUse guard (IS-053): turns the agents' red lines into a deterministic gate.

An agent's frontmatter `hooks.PreToolUse` calls this script; Claude Code writes the tool call to stdin as JSON
(`tool_name`, `tool_input`, `cwd`, `scratchpad_dir`, `agent_type` ...). To block, a Turkish reason is written to stderr
and the exit code is 2 (Claude Code stops the call and relays the reason to the agent).
Unexpected input or an internal error: warning + exit 0 (the guard never locks up a whole agent).

Usage:
  agent_guard.py bash                       Bash/PowerShell: commit/push/merge/rebase/tag/branch switch,
                                            branch delete, worktree delete, `rm -r` on the repo root/.git are blocked.
  agent_guard.py edit [--allow ROOT ...]    Edit/Write/NotebookEdit: board files and .claude/{agents,hooks,
                                            settings*.json} are blocked; with --allow only those roots inside the
                                            repo (e.g. docs/arastirma/) are writable.
  agent_guard.py readonly                   Auditor: all Edit/Write blocked; in Bash the `bash` rules + redirects into the
                                            repo/sed -i/cp/mv/rm/git write commands are blocked.
                                            Temp dirs (/tmp, Temp, scratchpad) are free.

Path decisions come from the `cwd` on stdin and the tool path (in a worktree cwd is the worktree root);
CLAUDE_PROJECT_DIR is used only to know the main repo root. Standard library only; Python 3.10+.
"""

from __future__ import annotations

import copy
import json
import os
import posixpath
import re
import shlex
import sys

COMMIT_REASON = (
    "Ajanlar commit/push/merge/rebase/tag ve dal değiştirme yapmaz; değişiklik çalışma ağacında kalır, "
    "koordinatöre bırak (raporda yaz)."
)
PANO_REASON = (
    "Pano dosyaları (docs/notes/durum.md, docs/surec/{backlog,kararlar,gecmis}.md) yalnız koordinatör yazar; "
    "gereken değişikliği raporunda belirt."
)
CONFIG_REASON = (
    "Ajan tanımları, .claude/settings*.json ve .claude/hooks/ yalnız koordinatör değiştirir; "
    "öneriyi raporda 'Karar gereken' altında yaz."
)
READONLY_REASON = (
    "Denetçi salt okunur: depo içinde dosya değiştiren komut/araç kullanılmaz. Geçici dosyaları /tmp ya da "
    "scratchpad altına yaz; bulguyu raporda belirt."
)

PANO_RE = re.compile(r"(^|/)docs/(notes/durum|surec/(backlog|kararlar|gecmis))\.md$")
CONFIG_RE = re.compile(r"(^|/)\.claude/((agents|hooks)(/|$)|settings[^/]*\.json$)")
WORKTREE_RE = re.compile(r"^(.*?/\.claude/worktrees/[^/]+)(/|$)")
EDIT_TOOLS = {"edit", "write", "notebookedit", "multiedit"}
SHELL_TOOLS = {"bash", "powershell"}

# Wrappers at the start of a command (the command itself is the next word).
WRAPPERS = {"sudo", "command", "env", "time", "nohup", "exec", "builtin", "nice", "stdbuf"}
SHELLS = {"bash", "sh", "zsh", "dash"}
SEPARATOR_CHARS = set(";&|()`\n")
GIT_OPTS_WITH_VALUE = {"-c", "-C", "--git-dir", "--work-tree", "--namespace", "--super-prefix", "--config-env"}

# readonly: side-effect-free git subcommands (the rest blocked; branch/tag/stash/worktree/config/remote handled separately).
GIT_READONLY = {
    "status", "diff", "log", "show", "rev-parse", "ls-files", "ls-tree", "blame", "merge-base", "cat-file",
    "describe", "shortlog", "grep", "rev-list", "for-each-ref", "name-rev", "show-ref", "diff-tree",
    "diff-files", "diff-index", "count-objects", "version", "help", "check-ignore", "check-attr", "var",
    "whatchanged", "range-diff", "cherry", "show-branch", "--version", "--help",
}
# readonly: file commands that write into the repo and target choice ("all" = all positional arguments, "last" = the target).
WRITE_CMDS = {
    "cp": "last", "mv": "last", "install": "last", "ln": "last", "rsync": "last",
    "copy-item": "last", "move-item": "last", "cpi": "last", "mi": "last", "copy": "last", "move": "last",
    "rm": "all", "rmdir": "all", "touch": "all", "mkdir": "all", "tee": "all", "truncate": "all",
    "shred": "all", "unlink": "all", "chmod": "all", "dd": "all",
    "remove-item": "all", "ri": "all", "del": "all", "erase": "all", "rd": "all",
    "set-content": "all", "add-content": "all", "out-file": "all", "new-item": "all", "clear-content": "all",
    "rename-item": "all", "sc": "all", "ac": "all", "ni": "all", "rni": "all",
}
INPLACE_CMDS = {"sed", "perl", "ruby"}
CD_CMDS = {"cd", "chdir", "set-location", "sl"}
PUSHD_CMDS = {"pushd", "push-location"}
POPD_CMDS = {"popd", "pop-location"}


class Ctx:
    """Context of a hook call: tool, cwd, repo roots, temp dirs."""

    def __init__(self, data: dict, project_dir: str | None = None, temp_dirs: list[str] | None = None) -> None:
        self.tool = str(data.get("tool_name") or "")
        # cwd_fs keeps case (for file system queries); comparisons use the lower-case `cwd`.
        self.cwd_fs = norm(str(data.get("cwd") or os.getcwd()), "/", lower=False)
        self.cwd_known = True  # False after a `cd` with a variable/unresolvable target in the chain
        self.warnings: list[str] = []  # allowed but unverifiable cases (written to stderr)
        self.powershell = self.tool.lower() == "powershell"
        roots: list[str] = []
        pd = project_dir if project_dir is not None else os.environ.get("CLAUDE_PROJECT_DIR", "")
        if pd:
            roots.append(norm(pd, "/"))
        m = WORKTREE_RE.match(self.cwd)
        if m:
            roots.append(m.group(1))
        git_root = find_git_root(self.cwd_fs)
        if git_root:
            roots.append(git_root.lower())
        self.roots = sorted({r.rstrip("/") or "/" for r in roots}, key=len, reverse=True)
        temps = ["/tmp", "/var/tmp", "/dev/null", "/dev/stdout", "/dev/stderr", "nul", "$null"]
        if temp_dirs is None:
            temp_dirs = [os.environ.get(k, "") for k in ("TEMP", "TMP", "TMPDIR")]
            temp_dirs.append(os.path.join(os.path.expanduser("~"), "AppData", "Local", "Temp"))
        temp_dirs = list(temp_dirs) + [str(data.get("scratchpad_dir") or "")]
        temps += [norm(t, "/") for t in temp_dirs if t]
        self.temps = [t.rstrip("/") for t in temps]

    @property
    def cwd(self) -> str:
        return self.cwd_fs.lower()

    def resolve(self, path: str) -> str:
        return norm(path, self.cwd)

    def chdir(self, raw: str | None) -> None:
        """Effect of a `cd` in a chain: if the target can be resolved cwd is updated, otherwise cwd becomes unknown."""
        if raw is None:
            raw = "~"
        if not raw or raw == "-" or raw.startswith(("$", "%")) or "`" in raw or "$(" in raw:
            self.cwd_known = False
            return
        self.cwd_fs = norm(raw, self.cwd_fs, lower=False)
        self.cwd_known = True

    def is_temp(self, abs_path: str) -> bool:
        return any(under(abs_path, t) for t in self.temps)

    def repo_rel(self, abs_path: str) -> str | None:
        """Path relative to the root if inside the repo (worktree prefix removed); None otherwise."""
        for r in self.roots:
            if under(abs_path, r):
                rel = abs_path[len(r):].lstrip("/") if r != "/" else abs_path.lstrip("/")
                return WORKTREE_STRIP_RE.sub("", rel)
        return None

    def in_repo(self, raw: str) -> bool:
        """Whether the write target is inside the repo (temp dirs and unknown variables excluded)."""
        if not raw or raw in {"-", "/dev/null"}:
            return False
        low = raw.lower()
        if low.startswith(("$claude_project_dir", "${claude_project_dir}", "$env:claude_project_dir")):
            return True
        if raw.startswith("$") or raw.startswith("%"):
            return False  # variable with an unknown value (e.g. mktemp output): do not block
        if not self.cwd_known and not is_abs(raw):
            self.warnings.append(
                f"agent_guard uyarı: zincirdeki `cd` hedefi çözülemedi; göreli yazma hedefi '{raw}' denetlenemedi "
                "(izin verildi)."
            )
            return False
        p = self.resolve(raw)
        if self.is_temp(p):
            return False
        return self.repo_rel(p) is not None

    def path_exists(self, raw: str) -> bool | None:
        """Whether the path exists relative to cwd; None if cwd is unknown."""
        if not is_abs(raw) and not self.cwd_known:
            return None
        p = norm(raw, self.cwd_fs, lower=False)
        try:
            return os.path.exists(p)
        except (OSError, ValueError):
            return False


WORKTREE_STRIP_RE = re.compile(r"^\.claude/worktrees/[^/]+(/|$)")


def is_abs(raw: str) -> bool:
    p = raw.strip().strip('"').strip("'").replace("\\", "/")
    return p.startswith(("/", "~")) or re.match(r"^[a-zA-Z]:/", p) is not None


def norm(path: str, cwd: str, lower: bool = True) -> str:
    """Normalises a path: '/' separator, drive 'c:/', Git Bash '/c/' -> 'c:/', lower case."""
    p = path.strip().strip('"').strip("'").replace("\\", "/")
    if p.startswith("~"):
        p = os.path.expanduser("~").replace("\\", "/") + p[1:]
    m = re.match(r"^/([a-zA-Z])(/|$)", p)
    if m:
        p = m.group(1) + ":/" + p[3:]
    m = re.match(r"^/mnt/([a-zA-Z])(/|$)", p)
    if m and cwd.lower().startswith(m.group(1).lower() + ":"):
        p = m.group(1) + ":/" + p[7:]
    if not (p.startswith("/") or re.match(r"^[a-zA-Z]:/", p) or re.match(r"^[a-zA-Z]:$", p)):
        p = cwd.rstrip("/") + "/" + p
    drive = ""
    if re.match(r"^[a-zA-Z]:", p):
        drive, p = p[:2], p[2:] or "/"
    p = posixpath.normpath(p)
    if p.startswith("//"):
        p = "/" + p.lstrip("/")
    out = drive + p
    return out.lower() if lower else out


def under(path: str, root: str) -> bool:
    root = root.rstrip("/")
    if not root:
        return path.startswith("/")
    return path == root or path.startswith(root + "/")


def find_git_root(cwd: str) -> str | None:
    """Searches upward from cwd for `.git` (a dir or worktree file); None if absent."""
    try:
        cur = cwd
        for _ in range(64):
            if os.path.exists(cur + "/.git"):
                return cur
            parent = posixpath.dirname(cur.rstrip("/"))
            if not parent or parent == cur or re.match(r"^[a-zA-Z]:$", parent):
                if parent and os.path.exists(parent + "/.git"):
                    return parent
                return None
            cur = parent
    except OSError:
        return None
    return None


# --- Command parsing ---------------------------------------------------------------------------------


def strip_heredocs(cmd: str) -> str:
    """Drops `<<EOF ... EOF` bodies (text in the body must not be mistaken for a command)."""
    lines = cmd.split("\n")
    out: list[str] = []
    pending: list[str] = []
    for line in lines:
        if pending:
            if line.strip() == pending[0]:
                pending.pop(0)
            continue
        out.append(line)
        for m in re.finditer(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", line):
            pending.append(m.group(2))
    return "\n".join(out)


QUOTED_PUNCT_RE = re.compile(r"""(["'])([;&|()<>`]+)\1""")
QUOTED_RE = re.compile(r"""'[^']*'|"(?:[^"\\]|\\.)*""" "\"")
PLACEHOLDER_RE = re.compile(r"^AGQ(\d+)Q$")


def protect_quoted_punct(cmd: str) -> tuple[str, list[str]]:
    """Turns quoted arguments containing only punctuation (`">"`, `'>>'`, `"|"`) into a placeholder so they are not
    mistaken for a redirect/separator. The placeholder is later restored as a plain word in `segments`."""
    saved: list[str] = []

    def sub(m: re.Match[str]) -> str:
        saved.append(m.group(2))
        return f"AGQ{len(saved) - 1}Q"

    out: list[str] = []
    pos = 0
    # Left to right: the quote kind that comes first wins (so nested quotes do not break).
    for m in QUOTED_RE.finditer(cmd):
        out.append(cmd[pos:m.start()])
        out.append(QUOTED_PUNCT_RE.sub(sub, m.group(0)) if QUOTED_PUNCT_RE.fullmatch(m.group(0)) else m.group(0))
        pos = m.end()
    out.append(cmd[pos:])
    return "".join(out), saved


def tokenize(cmd: str, powershell: bool) -> list[str]:
    lex = shlex.shlex(cmd, posix=True, punctuation_chars="();<>|&`\n")
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    lex.commenters = "" if powershell else "#"
    if powershell:
        lex.escape = ""  # in PowerShell backslash is a path separator
    try:
        return list(lex)
    except ValueError:  # unclosed quote etc.: rough split
        return re.findall(r"[;&|()`\n<>]+|[^\s;&|()`\n<>]+", cmd)


def is_redirect(tok: str) -> bool:
    return ">" in tok and set(tok) <= set("<>&|")


def is_separator(tok: str) -> bool:
    return bool(tok) and set(tok) <= (SEPARATOR_CHARS | {"<"}) and ">" not in tok and tok not in {"<", "<<", "<<<"}


def segments(cmd: str, powershell: bool) -> list[tuple[list[str], list[str]]]:
    """Splits a command into simple commands: [(words, redirect targets)]."""
    protected, saved = protect_quoted_punct(strip_heredocs(cmd))
    toks = tokenize(protected, powershell)
    segs: list[tuple[list[str], list[str]]] = []
    words: list[str] = []
    redirs: list[str] = []
    i = 0
    while i < len(toks):
        t = toks[i]
        ph = PLACEHOLDER_RE.match(t)
        if ph and int(ph.group(1)) < len(saved):
            words.append(saved[int(ph.group(1))])  # quoted punctuation: a plain argument
            i += 1
            continue
        if is_redirect(t):
            nxt = toks[i + 1] if i + 1 < len(toks) else ""
            if t.endswith("&") and (nxt.isdigit() or nxt == "-"):
                i += 2  # a descriptor copy like 2>&1
                continue
            # A trailing descriptor number like "2" is not the command word.
            if words and words[-1].isdigit():
                words.pop()
            if nxt and not is_separator(nxt) and not is_redirect(nxt):
                redirs.append(nxt)
                i += 2
            else:
                i += 1
            continue
        if t in {"<", "<<", "<<<"}:
            i += 2
            continue
        if is_separator(t):
            if words or redirs:
                segs.append((words, redirs))
            words, redirs = [], []
            i += 1
            continue
        words.append(t)
        i += 1
    if words or redirs:
        segs.append((words, redirs))
    return segs


def cmd_name(tok: str) -> str:
    name = tok.replace("\\", "/").rsplit("/", 1)[-1].lower()
    return name[:-4] if name.endswith(".exe") else name


def strip_wrappers(words: list[str]) -> list[str]:
    i = 0
    while i < len(words):
        w = words[i]
        name = cmd_name(w)
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w) or w == "$":
            i += 1
        elif name in WRAPPERS:
            i += 1
            while i < len(words) and words[i].startswith("-"):
                i += 1
        elif name == "timeout":
            i += 1
            while i < len(words) and (words[i].startswith("-") or re.match(r"^\d", words[i])):
                i += 1
        else:
            break
    return words[i:]


def split_opts(args: list[str]) -> tuple[list[str], list[str], bool]:
    """(options, positional arguments, whether '--' was seen)."""
    opts: list[str] = []
    pos: list[str] = []
    dashdash = False
    for a in args:
        if dashdash:
            pos.append(a)
        elif a == "--":
            dashdash = True
        elif a.startswith("-") and a != "-":
            opts.append(a)
        else:
            pos.append(a)
    return opts, pos, dashdash


def has_short(opts: list[str], letters: str) -> bool:
    return any(o.startswith("-") and not o.startswith("--") and any(c in o[1:] for c in letters) for o in opts)


# --- Rules -----------------------------------------------------------------------------------------


def check_git(args: list[str], readonly: bool, ctx: Ctx | None = None) -> str | None:
    i = 0
    git_dirs: list[str] = []  # `git -C <path>`: path existence is checked relative to this dir
    while i < len(args):
        a = args[i]
        if a in GIT_OPTS_WITH_VALUE:
            if a == "-C" and i + 1 < len(args):
                git_dirs.append(args[i + 1])
            i += 2
        elif a.startswith("-") and a not in {"--version", "--help"}:
            i += 1
        else:
            break
    if i >= len(args):
        return None
    sub = args[i].lower()
    rest = args[i + 1:]
    opts, pos, dashdash = split_opts(rest)
    lo = [o.lower() for o in opts]
    blocked = f"'git {sub}' engellendi. {COMMIT_REASON}"
    if sub in {"commit", "commit-tree", "push", "merge", "rebase", "cherry-pick", "revert", "am", "pull",
               "update-ref", "switch", "filter-branch", "replace"}:
        return blocked
    if sub == "tag":
        listing = not pos or "-l" in opts or "--list" in lo
        if not listing or has_short(opts, "dDfasu") or "--delete" in lo:
            return blocked
        return None
    if sub == "branch":
        if has_short(opts, "dDmMcCfu") or {"--delete", "--move", "--copy", "--force", "--set-upstream-to",
                                             "--unset-upstream", "--edit-description"} & set(lo):
            return f"'git branch {' '.join(opts)}' engellendi (dal silme/taşıma). {COMMIT_REASON}"
        list_flags = {"-l", "--list", "--contains", "--no-contains", "--merged", "--no-merged", "--points-at"}
        if readonly and pos and not (list_flags & set(lo)):
            return f"'git branch {pos[0]}' engellendi. {READONLY_REASON}"
        return None
    if sub == "checkout":
        if readonly:
            return f"'git checkout' engellendi. {READONLY_REASON}"
        if {"-b", "-B", "--orphan", "--detach"} & set(opts):
            return f"'git checkout {' '.join(opts)}' engellendi (dal değiştirme). {COMMIT_REASON}"
        if not dashdash and len(pos) == 1 and "*" not in pos[0]:
            # A single argument: an existing path is a file restore, otherwise a branch switch (heuristic '.' if cwd is unknown).
            pctx = ctx
            if ctx and git_dirs:
                pctx = copy.copy(ctx)
                for d in git_dirs:
                    pctx.chdir(d)
            exists = pctx.path_exists(pos[0]) if pctx else None
            is_path = exists if exists is not None else "." in pos[0]
            if not is_path:
                return (
                    f"'git checkout {pos[0]}' engellendi (dal değiştirme; böyle bir yol yok). "
                    f"Silinmiş dosyayı geri almak için `git checkout -- <yol>` kullan. {COMMIT_REASON}"
                )
        return None
    if sub == "worktree":
        action = pos[0].lower() if pos else ""
        if action not in {"", "list"}:
            return f"'git worktree {action}' engellendi; worktree'leri koordinatör yönetir."
        return None
    if sub == "stash":
        action = pos[0].lower() if pos else ""
        if action in {"list", "show"}:
            return None
        if readonly:
            return f"'git stash' engellendi. {READONLY_REASON}"
        if action == "push" and ("-m" in opts or "--message" in lo or any(o.startswith("--message=") for o in lo)):
            return None
        if action == "apply" and len(pos) >= 2:
            return None
        if action == "drop" and len(pos) >= 2:
            return None
        if action in {"create", "store"}:
            return None
        shown = f"git stash {action}".strip()
        return (
            f"'{shown}' engellendi: stash yığını tüm oturumlarla ortak. "
            "Yalnız `git stash push -u -m <etiket>` + `git stash apply <sha>` kullan."
        )
    if sub == "clean" and has_short(opts, "xX"):
        return "'git clean -x' engellendi (gitignore'daki .tools/ ve .godot/ silinir)."
    if readonly:
        if sub == "apply" and "--apply" not in lo and {"--check", "--stat", "--numstat", "--summary"} & set(lo):
            return None
        if sub in GIT_READONLY:
            return None
        if sub == "config" and ({"-l", "--list", "--get", "--get-all", "--get-regexp", "--show-origin"} & set(lo)
                                or (len(pos) == 1 and not opts)):
            return None
        if sub == "remote" and (not pos or pos[0] in {"show", "get-url"}):
            return None
        if sub == "reflog" and (not pos or pos[0] == "show"):
            return None
        return f"'git {sub}' engellendi. {READONLY_REASON}"
    return None


def check_gh(args: list[str]) -> str | None:
    opts, pos, _ = split_opts(args)
    if len(pos) < 2:
        return None
    area, action = pos[0].lower(), pos[1].lower()
    if area == "pr" and action in {"create", "merge", "close", "reopen", "edit", "ready", "review", "comment"}:
        return f"'gh {area} {action}' engellendi. {COMMIT_REASON}"
    if area == "release" and action not in {"list", "view", "download"}:
        return f"'gh {area} {action}' engellendi. {COMMIT_REASON}"
    if area == "repo" and action in {"create", "delete", "edit", "rename", "archive", "sync"}:
        return f"'gh {area} {action}' engellendi. {COMMIT_REASON}"
    return None


def protected_delete_target(raw: str, ctx: Ctx) -> bool:
    """Whether the `rm -r` target is the repo root (or an ancestor), .git or .claude/worktrees."""
    low = raw.lower()
    if low.startswith(("$claude_project_dir", "${claude_project_dir}", "$env:claude_project_dir")):
        rest = re.sub(r"^\$\{?(env:)?claude_project_dir\}?", "", low).strip("/*")
        return rest in {"", ".git"} or rest.startswith(".git/") or rest in {".claude", ".claude/worktrees"}
    if raw.startswith("$") or raw.startswith("%"):
        return False
    if not ctx.cwd_known and not is_abs(raw):
        ctx.warnings.append(
            f"agent_guard uyarı: zincirdeki `cd` hedefi çözülemedi; `rm -r {raw}` denetlenemedi (izin verildi)."
        )
        return False
    base = re.sub(r"(/\*|\*)$", "", raw.replace("\\", "/")) or "."
    p = ctx.resolve(base)
    parts = p.split("/")
    if ".git" in parts:
        return True
    if re.search(r"(^|/)\.claude(/worktrees(/[^/]+)?)?$", p):
        return True
    return any(under(r, p) for r in ctx.roots) or p in {"/", "c:/"} or re.match(r"^[a-z]:/?$", p) is not None


def check_rm(name: str, args: list[str], ctx: Ctx) -> str | None:
    opts, pos, _ = split_opts(args)
    lo = [o.lower() for o in opts]
    if name == "rm":
        recursive = has_short(opts, "rR") or "--recursive" in lo
    else:  # PowerShell Remove-Item and its aliases (-Recurse may be abbreviated: -r, -rec ...)
        recursive = any(o.startswith("-r") and not o.startswith("-readonly") for o in lo) or name in {"rd", "rmdir"}
    if not recursive:
        return None
    for t in pos:
        if protected_delete_target(t, ctx):
            return f"'{name} -r {t}' engellendi: depo kökü, .git ya da worktree dizini silinemez."
    return None


def check_readonly_words(name: str, args: list[str], ctx: Ctx) -> str | None:
    opts, pos, _ = split_opts(args)
    if name in INPLACE_CMDS and any(o == "-i" or (o.startswith("-i") and name == "sed") or o.startswith("--in-place")
                                    or (name == "perl" and o.startswith("-") and "i" in o[1:] and not o.startswith("--"))
                                    for o in opts):
        files = pos[1:] if name == "sed" else pos
        if not files or any(ctx.in_repo(f) for f in files):
            return f"'{name} -i' engellendi. {READONLY_REASON}"
        return None
    mode = WRITE_CMDS.get(name)
    if not mode:
        return None
    targets: list[str] = []
    for j, a in enumerate(args):
        al = a.lower()
        if al in {"-t", "--target-directory", "-destination", "-path", "-literalpath", "-filepath"} and j + 1 < len(args):
            targets.append(args[j + 1])
        elif al.startswith("--target-directory="):
            targets.append(a.split("=", 1)[1])
        elif name == "dd" and al.startswith("of="):
            targets.append(a[3:])
    if mode == "last" and pos:
        targets.append(pos[-1])
    elif mode == "all":
        targets += pos
    for t in targets:
        if ctx.in_repo(t):
            return f"'{name} … {t}' engellendi (depo içine yazma). {READONLY_REASON}"
    return None


def check_command(cmd: str, ctx: Ctx, readonly: bool, depth: int = 0) -> str | None:
    if depth > 4:
        return None
    # `cd`/`pushd`/`popd`/`Set-Location` in a chain are tracked: later relative targets resolve against the new directory.
    # (A copy: a cd in the inner shell does not leak out; the warning list stays shared.)
    ctx = copy.copy(ctx)
    dir_stack: list[tuple[str, bool]] = []
    for words, redirs in segments(cmd, ctx.powershell):
        if readonly:
            for target in redirs:
                if ctx.in_repo(target):
                    return f"'> {target}' engellendi (depo içine yönlendirme). {READONLY_REASON}"
        words = strip_wrappers(words)
        if not words:
            continue
        name = cmd_name(words[0])
        args = words[1:]
        if name in CD_CMDS | PUSHD_CMDS:
            if name in PUSHD_CMDS:
                dir_stack.append((ctx.cwd_fs, ctx.cwd_known))
            _, pos, _ = split_opts([a for a in args if a.lower() not in {"-path", "-literalpath"}])
            ctx.chdir(pos[0] if pos else None)
            continue
        if name in POPD_CMDS:
            if dir_stack:
                ctx.cwd_fs, ctx.cwd_known = dir_stack.pop()
            else:
                ctx.cwd_known = False
            continue
        if name in SHELLS and "-c" in args:
            k = args.index("-c")
            if k + 1 < len(args):
                reason = check_command(args[k + 1], ctx, readonly, depth + 1)
                if reason:
                    return reason
            continue
        if name in {"powershell", "pwsh"}:
            for k, a in enumerate(args):
                if a.lower() in {"-c", "-command"} and k + 1 < len(args):
                    sub = copy.copy(ctx)
                    sub.powershell = True
                    reason = check_command(" ".join(args[k + 1:]), sub, readonly, depth + 1)
                    if reason:
                        return reason
            continue
        if name in {"eval", "invoke-expression", "iex"}:
            reason = check_command(" ".join(args), ctx, readonly, depth + 1)
            if reason:
                return reason
            continue
        if name == "git":
            reason = check_git(args, readonly, ctx)
        elif name == "gh":
            reason = check_gh(args)
        elif name in {"rm", "remove-item", "ri", "rd", "rmdir", "del", "erase"}:
            reason = check_rm(name, args, ctx)
        else:
            reason = None
        if not reason and readonly:
            reason = check_readonly_words(name, args, ctx)
        if reason:
            return reason
    return None


def check_edit_path(raw: str, ctx: Ctx, allow: list[str]) -> str | None:
    p = ctx.resolve(raw)
    if PANO_RE.search(p):
        return f"'{raw}' yazılamaz. {PANO_REASON}"
    if CONFIG_RE.search(p):
        return f"'{raw}' yazılamaz. {CONFIG_REASON}"
    if allow:
        rel = ctx.repo_rel(p)
        if rel is not None and not ctx.is_temp(p):
            roots = [a.replace("\\", "/").strip("/").lower() for a in allow]
            if not any(rel == r or rel.startswith(r + "/") for r in roots):
                return f"'{raw}' yazılamaz: bu ajan depo içinde yalnız {', '.join(r + '/' for r in roots)} altına yazar."
    return None


def evaluate(mode: str, data: dict, allow: list[str] | None = None, project_dir: str | None = None,
             temp_dirs: list[str] | None = None, warnings: list[str] | None = None) -> str | None:
    """Block reason (str) or None (allowed). If `warnings` is given, cases that cannot be checked are added."""
    allow = allow or []
    tool = str(data.get("tool_name") or "").lower()
    tool_input = data.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return None
    ctx = Ctx(data, project_dir, temp_dirs)
    if tool in EDIT_TOOLS:
        if mode == "readonly":
            return f"{data.get('tool_name')} engellendi. {READONLY_REASON}"
        if mode == "edit":
            raw = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
            return check_edit_path(str(raw), ctx, allow) if raw else None
        return None
    if tool in SHELL_TOOLS and mode in {"bash", "readonly"}:
        cmd = tool_input.get("command")
        if not isinstance(cmd, str):
            return None
        reason = check_command(cmd, ctx, readonly=(mode == "readonly"))
        if warnings is not None:
            warnings.extend(dict.fromkeys(ctx.warnings))
        return reason
    return None


def _err(msg: str) -> None:
    try:
        sys.stderr.buffer.write((msg + "\n").encode("utf-8"))
        sys.stderr.flush()
    except Exception:  # noqa: BLE001
        pass


def main(argv: list[str]) -> int:
    try:
        mode = argv[0] if argv else ""
        if mode not in {"bash", "edit", "readonly"}:
            _err(f"agent_guard uyarı: bilinmeyen mod {mode!r}; denetim atlandı.")
            return 0
        allow: list[str] = []
        k = 1
        while k < len(argv):
            if argv[k] == "--allow" and k + 1 < len(argv):
                allow.append(argv[k + 1])
                k += 2
            else:
                k += 1
        raw = sys.stdin.buffer.read().decode("utf-8", errors="replace")
        data = json.loads(raw)
        if not isinstance(data, dict):
            raise ValueError("girdi JSON nesnesi değil")
        warnings: list[str] = []
        reason = evaluate(mode, data, allow, warnings=warnings)
    except Exception as exc:  # noqa: BLE001 - the guard must never lock up the agent
        _err(f"agent_guard uyarı: girdi işlenemedi ({type(exc).__name__}: {exc}); denetim atlandı.")
        return 0
    if reason:
        agent = data.get("agent_type") or "ajan"
        _err(f"agent_guard [{agent}]: {reason}")
        return 2
    for w in warnings:
        _err(w)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
