# Insiders

Steam'de arkadaş davetiyle oynanan 2-4 kişilik (hedef 3) online co-op, 2D üstten soygun oyunu.
Ekip hedefi keşfeder, sığınakta plan yapar, sonra plan bozulunca kaos başlar.
Godot 4.7.2 + GDScript (katı statik tipleme), host yetkili ağ.
Tasarım: `docs/tasarim/oyun-tasarimi.md` · Mimari ve sözleşmeler: `docs/notes/mimari.md`.

## Çalıştırma

1. Godot **4.7.2-stable** kurun (standart sürüm, .NET değil). Linux'ta `tools/get_godot.sh` ikiliyi
   `.tools/godot`'a indirir ve yolunu basar.
2. Godot'u açın, Proje Yöneticisi'nde **İçe Aktar** ile bu klasördeki `project.godot`'u seçin.
3. Tek pencere: F5. İki pencere (host + istemci) için **Debug → Customize Run Instances…** →
   **Enable Multiple Instances** açın, örnek sayısını 2 yapın, sonra F5.

## Test

```sh
tools/ci_local.sh                         # Godot getir → içe aktar → birim testler → ağ senaryoları (0 ve 150 ms)
tools/ci_local.sh unit                    # yalnız bir adım: godot | import | unit | net
GODOT=/yol/godot tools/ci_local.sh        # kurulu bir Godot ile
```

İlk hatada sıfır olmayan kodla çıkar; push öncesi yeşil olmalı. GitHub Actions (`.github/workflows/ci.yml`)
aynı adımları `dev` ve `main` push'unda koşar. Birim testler doğrudan:
`godot --headless --path . -s res://tests/run_tests.gd -- --filter=smoke`
(testler `tests/unit/test_*.gd`, `extends TestCase`; yardımcılar `tests/t.gd`).
