# Insiders

Steam'de arkadaş davetiyle oynanan 2-4 kişilik (hedef 3) online co-op, 2D üstten soygun oyunu.
Ekip hedefi keşfeder, sığınakta plan yapar, sonra plan bozulunca kaos başlar.
Godot 4.7.2 + GDScript (katı statik tipleme), host yetkili ağ.
Tasarım: `docs/tasarim/oyun-tasarimi.md` · Mimari ve sözleşmeler: `docs/notes/mimari.md`.

## Çalıştırma

1. Godot **4.7.2-stable** kurun (standart sürüm, .NET değil). Linux ve Windows'ta `tools/get_godot.sh` ikiliyi
   `.tools/` altına indirir ve yolunu basar (Windows: aşağıya bakın).
2. Godot'u açın, Proje Yöneticisi'nde **İçe Aktar** ile bu klasördeki `project.godot`'u seçin.
3. Tek pencere: F5. İki pencere (host + istemci) için **Debug → Customize Run Instances…** →
   **Enable Multiple Instances** açın, örnek sayısını 2 yapın, sonra F5.

## Test

```sh
tools/ci_local.sh                         # Godot getir → içe aktar → birim testler → araç testleri → ağ senaryoları (0 ve 150 ms)
tools/ci_local.sh unit                    # yalnız bir adım: godot | import | unit | tools | net
GODOT=/yol/godot tools/ci_local.sh        # kurulu bir Godot ile
```

İlk hatada sıfır olmayan kodla çıkar; push öncesi yeşil olmalı. GitHub Actions (`.github/workflows/ci.yml`)
aynı adımları `dev` ve `main` push'unda koşar. Birim testler doğrudan:
`godot --headless --path . -s res://tests/run_tests.gd -- --filter=smoke`
(testler `tests/unit/test_*.gd`, `extends TestCase`; yardımcılar `tests/t.gd`).

## Windows'ta geliştirme

- **Kabuk:** betikler [Git for Windows](https://git-scm.com/download/win) ile gelen **Git Bash**'te koşar
  (`bash`, `curl`, `unzip`, `sha512sum`, `cygpath` onunla gelir). WSL'nin `bash`'i değil, Git Bash kullanın.
- **Python:** 3.10 ya da üstü ([python.org](https://www.python.org/downloads/) kurulumu, PATH'e ekli).
  `ci_local.sh` yorumlayıcıyı sırayla `python3` → `python` → `py -3` arar.
- **Godot:** ya kurulu console exe'sini verin —
  `export GODOT="C:/yol/Godot_v4.7.2-stable_win64_console.exe"` — ya da `GODOT`'u boş bırakın:
  `tools/get_godot.sh` resmi win64 zip'ini `.tools/` altına indirir, SHA-512 ile doğrular ve
  `.tools/Godot_v4.7.2-stable_win64_console.exe` yolunu basar (headless çıktı için console exe gerekir).
- **Yerel CI:** Git Bash'te `bash tools/ci_local.sh` (adımlar Linux'takiyle aynı). Ağ senaryoları ve araç
  testleri süreçleri kendi süreç gruplarında açar; zaman aşımında yalnız Popen'dan sonra oluşmuş torunlar (oluşturma zamanı denetimiyle) `taskkill /F /PID` ile temizlenir.
