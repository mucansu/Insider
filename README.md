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

## Build'i çalıştırma

Build'ler `tools/export.sh` ile üretilir (Windows'ta Git Bash, ya da Linux): Godot 4.7.2 export şablonlarını
kullanıcı dizinine kurar (ilk koşuda resmi ~1,3 GB arşiv indirilir ve SHA-512 ile doğrulanır; yalnız Windows/Linux
x86_64 şablonları açılır, arşiv silinir; sonraki koşularda atlanır), `build/` altına iki platformu çıkarır ve bu
makinenin build'ini headless host + istemci olarak açıp kapatır. `main` push'unda GitHub Actions aynı build'leri
koşunun **Artifacts** bölümüne yükler (`insiders-windows-x86_64-…`, `insiders-linux-x86_64-…`).

```sh
tools/export.sh                  # şablonlar → windows → linux → duman koşusu
tools/export.sh windows          # yalnız bir adım: templates | windows | linux | smoke
tools/ci_local.sh export         # aynı şey, yerel CI üzerinden
```

- **Windows:** `build/windows/` klasörünü olduğu gibi kopyalayın, `Insiders.exe`'yi çift tıklayın. Oyun verisi
  exe'ye gömülüdür; `Insiders.console.exe` aynı oyunu günlük penceresiyle açar (sorun bildirirken onu kullanın).
  Build imzasız olduğundan SmartScreen uyarabilir: **Ek bilgi → Yine de çalıştır**. İlk kez host olunca Windows
  Güvenlik Duvarı sorar: **Özel ağlar**'a izin verin (Tailscale bağlantısı için de gerekir).
- **Linux:** `tar xzf Insiders-linux-x86_64.tar.gz && ./Insiders.x86_64` (Vulkan ya da OpenGL 3.3 sürücüsü gerekir).
- **Komut satırı:** build de proje argümanlarını alır (`--` sonrası, mimari S6), ör.
  `Insiders.console.exe -- --host --port=7777` ya da `Insiders.console.exe -- --join=100.64.0.2`;
  penceresiz host: `Insiders.console.exe --headless -- --host`.

## Arkadaşla internet üzerinden (Tailscale)

Faz 1-4'te bağlantı doğrudan adresle kurulur (ENet, UDP 7777); Steam daveti Faz 5'te gelir. Modemde port
yönlendirme gerekmesin diye herkes aynı [Tailscale](https://tailscale.com/download) ağına girer:

1. **Herkes** Tailscale'i kurup oturum açar. Host arkadaşlarını kendi tailnet'ine davet eder (yönetim panelinde
   **Users → Invite users**) ya da yalnız kendi makinesini paylaşır (**Machines → … → Share**).
2. **Host** kendi Tailscale adresini öğrenir: tepsi simgesindeki makine adı (100.x.y.z) ya da `tailscale ip -4`.
3. **Host** oyunu açar, adını yazar, **Host ol** (port 7777). Güvenlik duvarı sorarsa izin verir.
4. **Arkadaşlar** oyunu açar, **Katıl** bölümünde adrese host'un `100.x.y.z` adresini (MagicDNS açıksa makine adı
   da olur), porta `7777` yazar.
5. Bağlanmıyorsa: `tailscale ping <host-adı>` yanıt veriyor mu? Host'ta güvenlik duvarı izni (Insiders, gelen
   UDP 7777) var mı? Herkes aynı build'i mi kullanıyor (protokol sürümü farklıysa host bağlantıyı reddeder)?
   `tailscale status` satırında `relay` görünüyorsa trafik Tailscale aktarıcısından geçiyor: oyun çalışır ama ping
   artar; `direct` için UDP'yi engelleyen kurumsal/otel ağlarından kaçının.

HUD ping'i gösterir; oyun 150 ms RTT'ye kadar akıcı kalacak şekilde test edilir (Faz 1 çıkış kriteri).

## Test

```sh
tools/ci_local.sh                         # Godot getir → içe aktar → birim testler → araç testleri → ağ senaryoları (0 ve 150 ms)
tools/ci_local.sh unit                    # yalnız bir adım: godot | import | unit | tools | net | export
GODOT=/yol/godot tools/ci_local.sh        # kurulu bir Godot ile
```

İlk hatada sıfır olmayan kodla çıkar; push öncesi yeşil olmalı. GitHub Actions (`.github/workflows/ci.yml`)
aynı adımları `dev` ve `main` push'unda koşar; `export` varsayılan listede değildir, CI onu yalnız `main`
push'unda koşup build'leri yükler (bkz. Build'i çalıştırma). Birim testler doğrudan:
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
