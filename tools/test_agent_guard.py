#!/usr/bin/env python3
""".claude/hooks/agent_guard.py testleri (IS-053). Yalnız standart kütüphane; Godot gerekmez.

Koşu: python tools/test_agent_guard.py   (Windows'ta `python` ya da `py -3`; CI: ci_local.sh tools)
Kapsam: bash modu (commit/push/merge/rebase/tag/dal değiştirme/branch -D/worktree remove/rm -rf kök; izinli
status/diff/log/show, reset --hard, stash push -m + apply <sha>), edit modu (pano, .claude/{agents,hooks,
settings}, --allow kökleri; Windows ters bölü, sürücü harfi, Git Bash /c/ yolu, worktree yolu, büyük/küçük
harf), readonly modu (Edit/Write hepsi; > / >>, sed -i, git checkout --, git apply, cp/mv depo içi; geçici
dizinler serbest), süreç düzeyi (çıkış 2 + Türkçe stderr; bozuk JSON/bilinmeyen mod → 0).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
GUARD = os.path.join(HERE, "..", ".claude", "hooks", "agent_guard.py")
sys.path.insert(0, os.path.join(HERE, "..", ".claude", "hooks"))

import agent_guard as ag  # noqa: E402

ROOT = "C:\\Users\\dev\\Insider"
WT = ROOT + "\\.claude\\worktrees\\agent-x"
TEMPS = ["C:\\Users\\dev\\AppData\\Local\\Temp"]


def payload(tool: str, cwd: str = WT, **tool_input: object) -> dict:
    return {"tool_name": tool, "cwd": cwd, "tool_input": tool_input, "agent_type": "oynanis",
            "scratchpad_dir": "C:\\Users\\dev\\AppData\\Local\\Temp\\claude\\x\\scratchpad"}


def run(mode: str, data: dict, allow: list[str] | None = None) -> str | None:
    return ag.evaluate(mode, data, allow, project_dir=ROOT, temp_dirs=TEMPS)


class Base(unittest.TestCase):
    mode = "bash"

    def blocked(self, cmd: str, tool: str = "Bash", cwd: str = WT) -> None:
        reason = run(self.mode, payload(tool, cwd, command=cmd))
        self.assertIsNotNone(reason, f"engellenmeliydi: {cmd!r}")

    def allowed(self, cmd: str, tool: str = "Bash", cwd: str = WT) -> None:
        reason = run(self.mode, payload(tool, cwd, command=cmd))
        self.assertIsNone(reason, f"izinli olmalıydı: {cmd!r} → {reason}")


class BashMode(Base):
    def test_git_writes_blocked(self) -> None:
        for cmd in [
            "git commit -m 'x'",
            "git -C . commit -am x",
            "git push origin dev",
            "git push --force",
            "git merge dev",
            "git rebase dev",
            "git tag faz-2",
            "git tag -d faz-2",
            "git cherry-pick abc123",
            "git pull",
            "git switch dev",
            "git checkout main",
            "git checkout dev",
            "git checkout faz2-int",
            "git checkout -b yeni",
            "git branch -D worktree-agent-x",
            "git branch --delete x",
            "git branch -m eski yeni",
            "git worktree remove ../x",
            "git worktree prune",
            "git stash",
            "git stash pop",
            "git stash drop",
            "git stash clear",
            "git clean -fdx",
            "gh pr create --fill",
            "gh release create v1",
            "git worktree add ../x dev",
            "git revert HEAD",
            "git update-ref refs/heads/dev HEAD",
            "git am 0001-x.patch",
            "gh pr merge 12 --squash",
        ]:
            with self.subTest(cmd=cmd):
                self.blocked(cmd)

    def test_compound_and_nested_blocked(self) -> None:
        for cmd in [
            "cd /c/x && git commit -m x",
            "git status; git push",
            "git add . && git commit -m 'IS-053: x'",
            "echo ok | git commit -F -",
            "true\ngit push origin dev",
            "bash -c 'git push origin dev'",
            "sh -c \"cd x && git commit -m y\"",
            "FOO=1 git commit -m x",
            "env GIT_DIR=.git git push",
            "timeout 30 git push",
            "(cd sub && git merge dev)",
            "echo $(git push)",
            "/usr/bin/git commit -m x",
            "C:/Program\\ Files/Git/cmd/git.exe push",
            "GIT COMMIT -m x",
        ]:
            with self.subTest(cmd=cmd):
                self.blocked(cmd)

    def test_powershell_tool(self) -> None:
        self.blocked("git commit -m x", tool="PowerShell")
        self.blocked("& 'C:\\Program Files\\Git\\cmd\\git.exe' push", tool="PowerShell")
        self.blocked("Remove-Item -Recurse -Force C:\\Users\\dev\\Insider\\.git", tool="PowerShell")
        self.blocked("powershell -Command git push", tool="Bash")
        self.allowed("git status; Get-ChildItem C:\\Users\\dev\\Insider", tool="PowerShell")

    def test_allowed_git(self) -> None:
        for cmd in [
            "git status --short",
            "git diff --stat dev",
            "git log --oneline -5",
            "git show HEAD:project.godot",
            "git rev-parse --show-toplevel",
            "git reset -q --hard dev",
            "git stash push -u -m is053-etiket",
            "git stash push -u --message=is053",
            "git stash apply 0123abcd",
            "git stash list --format='%H %gs'",
            "git stash drop stash@{2}",
            "git checkout -- autoload/net.gd",
            "git checkout HEAD -- tests/unit/test_x.gd",
            "git branch",
            "git branch --show-current",
            "git tag",
            "git tag -l 'faz-*'",
            "git worktree list",
            "git add tools/test_agent_guard.py",
            "git clean -n",
            "git -C ../x status",
            "gh pr view 12",
            "echo 'git push origin dev'",
            "grep -n \"git commit\" docs/surec/surec.md",
            "git log --grep='git push'",
        ]:
            with self.subTest(cmd=cmd):
                self.allowed(cmd)

    def test_heredoc_body_not_a_command(self) -> None:
        self.allowed("cat > /tmp/not.txt <<'EOF'\ngit push origin dev\nEOF\necho bitti")

    def test_rm_rf_targets(self) -> None:
        for cmd in ["rm -rf .", "rm -rf ./", "rm -rf .git", "rm -fr .git/", "rm -r -f *",
                    "rm --recursive --force ..", "rm -rf /", "rm -rf ~/../..", "rm -rf /c/Users/dev/Insider",
                    "rm -rf C:\\\\Users\\\\dev\\\\Insider", "rm -rf \"$CLAUDE_PROJECT_DIR\"",
                    "rm -Rf .claude/worktrees", "rm -rf ../agent-y", "rm -rf sub/.git"]:
            with self.subTest(cmd=cmd):
                self.blocked(cmd)
        for cmd in ["rm -rf .godot", "rm -rf build/", "rm -f .git_ignore_me", "rm .gitkeep",
                    "rm -rf /tmp/denetci-1", "rm -rf \"$tmpdir\"", "rm -rf tests/fixtures/eski"]:
            with self.subTest(cmd=cmd):
                self.allowed(cmd)

    def test_rm_rf_root_from_main_tree_cwd(self) -> None:
        self.blocked("rm -rf .", cwd=ROOT)
        self.allowed("rm -rf .", cwd="C:\\Users\\dev\\AppData\\Local\\Temp\\iş")

    def test_malformed_input_is_permissive(self) -> None:
        self.assertIsNone(run("bash", {"tool_name": "Bash", "tool_input": "git push"}))
        self.assertIsNone(run("bash", {"tool_name": "Bash", "tool_input": {"command": 5}}))
        self.assertIsNone(run("bash", {"tool_name": "Read", "tool_input": {"file_path": "x"}}))
        # Kapanmamış tırnak: kaba bölmeye düşer, yine de commit yakalanır.
        self.assertIsNotNone(run("bash", payload("Bash", command="git commit -m 'yarım")))


class EditMode(unittest.TestCase):
    def edit(self, path: str, allow: list[str] | None = None, tool: str = "Edit", cwd: str = WT) -> str | None:
        key = "notebook_path" if tool == "NotebookEdit" else "file_path"
        return run("edit", payload(tool, cwd, **{key: path}), allow)

    def test_pano_blocked(self) -> None:
        for p in [
            WT + "\\docs\\notes\\durum.md",
            ROOT + "\\docs\\surec\\backlog.md",
            "C:/Users/dev/Insider/docs/surec/kararlar.md",
            "/c/Users/dev/Insider/docs/surec/gecmis.md",
            "c:\\USERS\\DEV\\INSIDER\\DOCS\\SUREC\\BACKLOG.MD",
            "C:\\Users\\dev\\Insider\\.claude\\worktrees\\agent-x\\docs\\surec\\backlog.md",
            "/home/u/Insider/.claude/worktrees/agent-x/docs/surec/backlog.md",
            "docs/notes/durum.md",
            "D:\\Başka\\Insider\\docs\\notes\\durum.md",
        ]:
            for tool in ("Edit", "Write"):
                with self.subTest(path=p, tool=tool):
                    reason = self.edit(p, tool=tool)
                    self.assertIsNotNone(reason)
                    self.assertIn("koordinatör", reason)

    def test_config_blocked(self) -> None:
        for p in [
            WT + "\\.claude\\agents\\oynanis.md",
            ROOT + "\\.claude\\settings.json",
            ROOT + "\\.claude\\settings.local.json",
            WT + "\\.claude\\hooks\\agent_guard.py",
            "C:/Users/dev/Insider/.CLAUDE/Agents/denetci.md",
        ]:
            with self.subTest(path=p):
                self.assertIsNotNone(self.edit(p))
        self.assertIsNotNone(self.edit(WT + "\\x.ipynb\\..\\.claude\\agents\\a.md", tool="NotebookEdit"))

    def test_normal_files_allowed(self) -> None:
        for p in [
            WT + "\\autoload\\net.gd",
            WT + "\\docs\\notes\\mimari.md",
            WT + "\\docs\\surec\\surec.md",
            WT + "\\docs\\notes\\durum.md.bak",
            WT + "\\tools\\test_agent_guard.py",
            WT + "\\.claude\\agents_notes.md",
            "C:\\Users\\dev\\AppData\\Local\\Temp\\claude\\x\\scratchpad\\durum.txt",
        ]:
            with self.subTest(path=p):
                self.assertIsNone(self.edit(p))

    def test_allow_roots(self) -> None:
        allow = ["docs/arastirma/"]
        self.assertIsNone(self.edit(WT + "\\docs\\arastirma\\teknik\\ag.md", allow))
        self.assertIsNone(self.edit("C:/Users/dev/Insider/docs/arastirma/teknik/ag.md", allow))
        self.assertIsNone(self.edit("docs/Arastirma/x.md", allow))
        self.assertIsNotNone(self.edit(WT + "\\docs\\tasarim\\oyun-tasarimi.md", allow))
        self.assertIsNotNone(self.edit(WT + "\\autoload\\net.gd", allow))
        self.assertIsNotNone(self.edit(WT + "\\docs\\arastirma_x.md", allow))
        self.assertIsNotNone(self.edit(WT + "\\docs\\arastirma\\..\\notes\\mimari.md", allow))
        # Depo dışı (scratchpad) serbest.
        self.assertIsNone(self.edit("C:\\Users\\dev\\AppData\\Local\\Temp\\claude\\x\\scratchpad\\n.md", allow))
        # Pano yine engelli (allow kökü altında olmasa da).
        self.assertIsNotNone(self.edit(WT + "\\docs\\surec\\backlog.md", ["docs/"]))
        tasarim = ["docs/tasarim/"]
        self.assertIsNone(self.edit(WT + "\\docs\\tasarim\\degerlendirmeler\\faz-2.md", tasarim))
        self.assertIsNotNone(self.edit(WT + "\\docs\\arastirma\\teknik\\ag.md", tasarim))

    def test_edit_mode_ignores_bash(self) -> None:
        self.assertIsNone(run("edit", payload("Bash", command="git push")))


class ReadonlyMode(Base):
    mode = "readonly"

    def test_edit_tools_all_blocked(self) -> None:
        for tool in ("Edit", "Write", "NotebookEdit"):
            with self.subTest(tool=tool):
                self.assertIsNotNone(run("readonly", payload(tool, file_path="C:\\Users\\dev\\AppData\\Local\\Temp\\x.md")))

    def test_bash_rules_still_apply(self) -> None:
        for cmd in ["git commit -m x", "git push", "git checkout dev", "rm -rf ."]:
            with self.subTest(cmd=cmd):
                self.blocked(cmd)

    def test_repo_writes_blocked(self) -> None:
        for cmd in [
            "echo x > autoload/net.gd",
            "echo x >> docs/notes/mimari.md",
            "echo x>notlar.txt",
            "printf x 1> C:\\\\Users\\\\dev\\\\Insider\\\\a.txt",
            "cat a &> log.txt",
            "sed -i 's/a/b/' tests/t.gd",
            "sed -i.bak -e 's/a/b/' tests/t.gd",
            "perl -pi -e 's/a/b/' x.gd",
            "git checkout -- autoload/net.gd",
            "git checkout .",
            "git apply /tmp/p.diff",
            "git restore x.gd",
            "git reset --hard",
            "git stash push -m x",
            "git add .",
            "cp /tmp/a.gd autoload/a.gd",
            "mv tools/x.py tools/y.py",
            "cp -r /tmp/a -t tests/unit",
            "echo x | tee tests/unit/test_y.gd",
            "touch yeni.gd",
            "rm autoload/net.gd",
            "mkdir yeni_dizin",
            "bash -c 'echo x > a.gd'",
            "grep \">\" a.gd > sonuc.txt",
            "git apply --check --apply /tmp/p.diff",
        ]:
            with self.subTest(cmd=cmd):
                self.blocked(cmd)

    def test_reads_and_temp_writes_allowed(self) -> None:
        for cmd in [
            "git status --porcelain",
            "git diff --name-only dev",
            "git log --oneline -3",
            "git show HEAD --stat",
            "git branch --show-current",
            "git stash list",
            "git worktree list",
            "git config --get core.autocrlf",
            "bash tools/ci_local.sh",
            "GODOT=/c/godot.exe bash tools/ci_local.sh unit 2>&1 | tail -20",
            "python tools/test_agent_guard.py 2>/dev/null",
            "mkdir -p /tmp/denetci-x && echo x > /tmp/denetci-x/a.txt",
            "echo x >> /tmp/log.txt",
            "cat x > C:\\\\Users\\\\dev\\\\AppData\\\\Local\\\\Temp\\\\y.txt",
            "echo x > C:/Users/dev/AppData/Local/Temp/claude/x/scratchpad/n.txt",
            "out=$(mktemp); echo x > \"$out\"; rm -f \"$out\"",
            "sed -n '1,20p' tests/t.gd",
            "sed 's/a/b/' tests/t.gd > /tmp/t.gd",
            "cp autoload/net.gd /tmp/net.gd",
            "grep -c x a.gd > /dev/null",
            "rm -rf /tmp/denetci-x",
            "ls >&2",
            "grep \">\" autoload/net.gd",
            "grep -n '>>' tests/t.gd | head -3",
            "grep -c '|' x.csv; echo \"a > b\"",
            "git apply --check /tmp/p.diff",
            "git apply --stat /tmp/p.diff",
        ]:
            with self.subTest(cmd=cmd):
                self.allowed(cmd)

    def test_repo_write_from_temp_cwd(self) -> None:
        temp_cwd = "C:\\Users\\dev\\AppData\\Local\\Temp\\iş"
        self.allowed("echo x > a.txt", cwd=temp_cwd)
        self.blocked("echo x > C:/Users/dev/Insider/a.txt", cwd=temp_cwd)


TEMP_CWD = "C:\\Users\\dev\\AppData\\Local\\Temp\\iş"


class CdTracking(Base):
    """Zincirdeki cd/pushd/popd/Set-Location izlenir (t1b)."""

    mode = "readonly"

    def warned(self, cmd: str, mode: str = "readonly", cwd: str = WT) -> list[str]:
        warnings: list[str] = []
        reason = ag.evaluate(mode, payload("Bash", cwd, command=cmd), None, project_dir=ROOT, temp_dirs=TEMPS,
                             warnings=warnings)
        self.assertIsNone(reason, cmd)
        return warnings

    def test_cd_to_temp_then_write_allowed(self) -> None:
        for cmd in [
            "cd /c/Users/dev/AppData/Local/Temp/claude/x/scratchpad/x && echo a > f",
            "cd \"C:\\Users\\dev\\AppData\\Local\\Temp\\iş\" && sed -i 's/a/b/' f.txt",
            "cd 'C:\\Users\\dev\\AppData\\Local\\Temp' ; cp /c/Users/dev/Insider/a.gd kopya.gd",
            "cd -- /tmp/den && mkdir -p d && touch d/x",
            "cd /tmp/x\necho a >> log.txt",
            "pushd /tmp/x && echo a > f; popd",
        ]:
            with self.subTest(cmd=cmd):
                self.allowed(cmd)

    def test_cd_into_repo_then_write_blocked(self) -> None:
        for cmd in [
            "cd /c/Users/dev/Insider && echo a > f",
            "cd C:/Users/dev/Insider/.claude/worktrees/agent-x && sed -i 's/a/b/' x.gd",
            "cd /tmp && cd 'C:\\Users\\dev\\Insider\\.claude\\worktrees\\agent-x\\tests' && sed -i s/a/b/ t.gd",
            "cd ../../../../Insider && touch x",
            "cd /tmp/x && cd - >/dev/null; cd /c/Users/dev/Insider; echo a > f",
            "pushd /tmp/x && echo a > f && popd && echo b > g",
            "bash -c 'cd /tmp && echo a > f'; echo b > g",
        ]:
            with self.subTest(cmd=cmd):
                self.blocked(cmd, cwd=TEMP_CWD if "pushd" not in cmd and "bash -c" not in cmd else WT)

    def test_set_location_powershell(self) -> None:
        self.allowed("Set-Location -Path 'C:\\Users\\dev\\AppData\\Local\\Temp'; Set-Content -Path f.txt -Value x",
                     tool="PowerShell")
        self.blocked("Set-Location C:\\Users\\dev\\Insider; Set-Content -Path f.txt -Value x", tool="PowerShell",
                     cwd=TEMP_CWD)
        self.blocked("Push-Location C:\\Users\\dev\\Insider; New-Item yeni.txt", tool="PowerShell", cwd=TEMP_CWD)

    def test_unresolvable_cd_warns_but_allows(self) -> None:
        for cmd in ["cd \"$tmp\" && echo a > f", "cd - && echo a > f", "cd $(mktemp -d) && touch x",
                    "popd && echo a > f"]:
            with self.subTest(cmd=cmd):
                self.assertTrue(self.warned(cmd), cmd)
        # Mutlak depo hedefi cd çözülemese de engelli.
        self.blocked("cd $x && echo a > /c/Users/dev/Insider/f")
        self.assertEqual(self.warned("echo a > /tmp/f"), [])

    def test_bash_mode_rm_follows_cd(self) -> None:
        self.assertIsNone(run("bash", payload("Bash", WT, command="cd /tmp/x && rm -rf .")))
        self.assertIsNotNone(run("bash", payload("Bash", TEMP_CWD, command="cd /c/Users/dev/Insider && rm -rf .")))
        self.assertIsNotNone(run("bash", payload("Bash", TEMP_CWD, command="cd /c/Users/dev/Insider && rm -rf .git")))
        self.assertTrue(self.warned("cd \"$d\" && rm -rf .", mode="bash"))


class CheckoutPathOrBranch(unittest.TestCase):
    """`git checkout <tek_argüman>`: mevcut yol → dosya geri alma (izinli), değilse dal değiştirme (engelli)."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        os.makedirs(os.path.join(self.dir, "autoload"))
        os.makedirs(os.path.join(self.dir, "tools"))
        with open(os.path.join(self.dir, "autoload", "net.gd"), "w", encoding="utf-8") as f:
            f.write("x")
        with open(os.path.join(self.dir, "Makefile"), "w", encoding="utf-8") as f:
            f.write("x")
        os.makedirs(os.path.join(self.dir, "sub"))
        with open(os.path.join(self.dir, "sub", "a.gd"), "w", encoding="utf-8") as f:
            f.write("x")

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def check(self, cmd: str) -> str | None:
        return run("bash", payload("Bash", self.dir, command=cmd))

    def test_existing_path_is_restore(self) -> None:
        for cmd in ["git checkout autoload/net.gd", "git checkout tools", "git checkout Makefile",
                    "git checkout autoload\\\\net.gd", "cd autoload && git checkout net.gd",
                    "git checkout " + os.path.join(self.dir, "autoload", "net.gd").replace("\\", "/")]:
            with self.subTest(cmd=cmd):
                self.assertIsNone(self.check(cmd))

    def test_missing_path_is_branch_switch(self) -> None:
        for cmd in ["git checkout dev", "git checkout main", "git checkout faz2-int", "git checkout yok.gd",
                    "git checkout origin/main", "cd tools && git checkout autoload/net.gd"]:
            with self.subTest(cmd=cmd):
                reason = self.check(cmd)
                self.assertIsNotNone(reason)
                self.assertIn("git checkout --", reason)

    def test_git_dash_c_dir_used_for_existence(self) -> None:
        self.assertIsNone(self.check("git -C sub checkout a.gd"))
        self.assertIsNone(self.check("git -C " + os.path.join(self.dir, "sub").replace("\\", "/") + " checkout a.gd"))
        self.assertIsNotNone(self.check("git -C sub checkout dev"))
        self.assertIsNotNone(self.check("git -C tools checkout autoload/net.gd"))
        self.assertIsNotNone(self.check("git checkout a.gd"))  # kökte yok

    def test_unknown_cwd_falls_back_to_dot_heuristic(self) -> None:
        self.assertIsNone(self.check("cd $x && git checkout a.gd"))
        self.assertIsNotNone(self.check("cd $x && git checkout dev"))


class Normalization(unittest.TestCase):
    def test_norm_forms_equal(self) -> None:
        forms = ["C:\\Users\\Dev\\Insider\\a.gd", "C:/Users/dev/Insider/a.gd", "/c/users/dev/insider/a.gd",
                 "c:\\users\\dev\\insider\\x\\..\\a.gd"]
        self.assertEqual({ag.norm(f, "/") for f in forms}, {"c:/users/dev/insider/a.gd"})
        self.assertEqual(ag.norm("a\\b.gd", "c:/r"), "c:/r/a/b.gd")
        self.assertEqual(ag.norm("/home/u/r/../x", "/"), "/home/u/x")


class Process(unittest.TestCase):
    def call(self, args: list[str], stdin: bytes) -> subprocess.CompletedProcess[bytes]:
        env = dict(os.environ, CLAUDE_PROJECT_DIR=ROOT)
        return subprocess.run([sys.executable, GUARD, *args], input=stdin, capture_output=True, env=env,
                              timeout=30, check=False)

    def test_block_exit_2_with_turkish_reason(self) -> None:
        data = json.dumps(payload("Bash", command="git push origin dev")).encode("utf-8")
        r = self.call(["bash"], data)
        self.assertEqual(r.returncode, 2)
        msg = r.stderr.decode("utf-8")
        self.assertIn("commit/push", msg)
        self.assertIn("koordinatöre bırak", msg)
        self.assertIn("[oynanis]", msg)

    def test_allow_exit_0(self) -> None:
        data = json.dumps(payload("Bash", command="git status")).encode("utf-8")
        self.assertEqual(self.call(["bash"], data).returncode, 0)

    def test_allow_flag_cli(self) -> None:
        data = json.dumps(payload("Write", file_path=WT + "\\autoload\\net.gd")).encode("utf-8")
        self.assertEqual(self.call(["edit", "--allow", "docs/arastirma/"], data).returncode, 2)
        self.assertEqual(self.call(["edit"], data).returncode, 0)

    def test_warning_exit_0(self) -> None:
        data = json.dumps(payload("Bash", command="cd \"$tmp\" && echo a > f")).encode("utf-8")
        r = self.call(["readonly"], data)
        self.assertEqual(r.returncode, 0)
        self.assertIn("denetlenemedi", r.stderr.decode("utf-8"))

    def test_bad_input_exit_0(self) -> None:
        for args, stdin in [(["bash"], b"{bozuk"), (["bash"], b""), (["edit"], b"[1,2]"), (["bash"], b"\xff\xfe"),
                            (["bilinmeyen"], b"{}"), ([], b"{}")]:
            with self.subTest(args=args, stdin=stdin):
                r = self.call(args, stdin)
                self.assertEqual(r.returncode, 0)
                self.assertIn("agent_guard uyarı", r.stderr.decode("utf-8"))


class Frontmatter(unittest.TestCase):
    """Ajan dosyalarında hook bağlı ve doğru modda (alan değişirse test hatırlatır)."""

    AGENTS = os.path.join(HERE, "..", ".claude", "agents")
    EXPECT = {
        "cekirdek": ("edit", None), "oynanis": ("edit", None), "seviye": ("edit", None),
        "arayuz": ("edit", None), "altyapi": ("edit", None),
        "arastirmaci": ("edit", "docs/arastirma/"), "tasarim": ("edit", "docs/tasarim/"),
        "denetci": ("readonly", None),
    }

    def test_hooks_present(self) -> None:
        for name, (edit_mode, allow) in self.EXPECT.items():
            with self.subTest(agent=name):
                with open(os.path.join(self.AGENTS, name + ".md"), encoding="utf-8") as f:
                    text = f.read()
                front = text.split("---", 2)[1]
                self.assertIn("hooks:", front)
                self.assertIn("PreToolUse:", front)
                self.assertIn('matcher: "Bash|PowerShell"', front)
                self.assertIn('matcher: "Edit|Write|NotebookEdit|MultiEdit"', front)
                bash_mode = "readonly" if name == "denetci" else "bash"
                self.assertIn('f="$CLAUDE_PROJECT_DIR/.claude/hooks/agent_guard.py"', front)
                self.assertIn('[ -f "$f" ] || exit 0', front)
                self.assertIn(f'"$f" {bash_mode}\'', front)
                tail = f'"$f" {edit_mode}' + (f" --allow {allow}" if allow else "")
                self.assertIn(tail + "'", front)


if __name__ == "__main__":
    unittest.main(verbosity=1)
