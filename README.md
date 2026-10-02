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
koşunun **Artifacts** bölümüne yükler (`insiders-windows-x86_64-…`, `insiders-linux-x86_64-…`). `test-*` etiketi
push'unda aynı build'ler testlerden sonra GitHub **Releases**'a ön sürüm olarak çıkar
(`Insiders-<etiket>-windows.zip`, `Insiders-<etiket>-linux.zip`). Repo özel olduğundan Release dosyalarını
yalnız repo erişimi olan indirebilir: Release'i proje sahibi indirir ve zip'i arkadaşlara (Discord, Drive vb.)
iletir.

```sh
tools/export.sh                  # şablonlar → windows → linux → duman koşusu
tools/export.sh windows          # yalnız bir adım: templates | windows | linux | smoke
tools/export.sh --debug windows smoke   # debug şablonuyla (test-* Release'leri böyle çıkar)
tools/ci_local.sh export         # aynı şey, yerel CI üzerinden (debug için: EXPORT_DEBUG=1 tools/ci_local.sh export)
```

- **Windows:** `build/windows/` klasörünü olduğu gibi kopyalayın, `Insiders.exe`'yi çift tıklayın. Oyun verisi
  exe'ye gömülüdür; `Insiders.console.exe` aynı oyunu günlük penceresiyle açar (sorun bildirirken onu kullanın).
  Build imzasız olduğundan SmartScreen uyarabilir: **Ek bilgi → Yine de çalıştır**. İlk kez host olunca Windows
  Güvenlik Duvarı sorar: **Özel** ve **Ortak** ağların ikisini de işaretleyin (ayrıntı: aşağıda Tailscale 4. adım).
- **Linux:** `tar xzf Insiders-linux-x86_64.tar.gz && ./Insiders.x86_64` (Vulkan ya da OpenGL 3.3 sürücüsü gerekir).
  Release zip'inden (`chmod +x`, zip'i izinleri korumayan bir araçla açtıysanız gerekir):
  `unzip Insiders-<etiket>-linux.zip && cd Insiders-<etiket>-linux && chmod +x Insiders.x86_64 && ./Insiders.x86_64`
- **Komut satırı:** build de proje argümanlarını alır (`--` sonrası, mimari S6), ör.
  `Insiders.console.exe -- --host --port=7777` ya da `Insiders.console.exe -- --join=100.64.0.2`;
  penceresiz host: `Insiders.console.exe --headless -- --host`.

## Arkadaşla internet üzerinden (Tailscale)

Faz 1-4'te bağlantı doğrudan adresle kurulur (ENet, UDP 7777); Steam daveti Faz 5'te gelir. Modemde port
yönlendirme gerekmesin diye herkes aynı [Tailscale](https://tailscale.com/download) ağına girer:

1. **Herkes** Tailscale'i kurup oturum açar. Host arkadaşlarını kendi tailnet'ine davet eder (yönetim panelinde
   **Users → Invite users**) ya da yalnız kendi makinesini paylaşır (**Machines → … → Share**).
2. **Host** oyunu açar, adını yazar; **Oturumu sen aç** kartında davet adresini görür (`100.x.y.z:7777`;
   Tailscale önce gelir) ve **Kopyala** ile arkadaşlarına (Discord vb.) gönderir. Kart "Tailscale yok" diyorsa
   Tailscale çalışmıyordur; adres yine de `tailscale ip -4` ile öğrenilebilir. Oyunda da Esc menüsünde aynı
   adres ve **Kopyala** vardır.
3. **Host** **Host ol**'a basar (port 7777). Güvenlik duvarı sorarsa 5. adıma bakın.
4. **Arkadaşlar** oyunu açar, gelen adresi kopyalayıp **Katıl** kartında **Yapıştır**'a basar (adres alanına
   `100.x.y.z` ya da `100.x.y.z:7777`, MagicDNS açıksa makine adı da yazılabilir), sonra **Katıl**. Port yalnız
   **Gelişmiş** altındadır (varsayılan 7777); adres `adres:port` biçimindeyse oradaki port geçerlidir. Ad ve son
   katılınan adres hatırlanır: sonraki açılışta tek tuşla katılınır. Başka tailnet'ten **paylaşılan** makineye
   yalnız tam ad (`makine.tailnet-adı.ts.net`; alıcının tailnet'inde MagicDNS açık olmalı) ya da `100.x.y.z` çalışır.
5. **Host, ilk kez (bir kerelik):** Windows'un "izin ver" penceresinde **Özel** ve **Ortak** ağların **ikisini
   de** işaretleyin; pencereyi **iptal etmeyin**. Tailscale kendi ağ bağdaştırıcısını her açılışta **Özel** (Private)
   profile alır ve `Tailscale-In` kuralıyla Tailscale adresinize gelen paketleri Özel profilde geçirir; yani
   Tailscale üzerinden host olmak için ayrı izin kuralı çoğu zaman gerekmez. Asıl risk, Insiders.exe için **Özel
   profilde bir Engelle kuralı**dır (pencere iptal edildiyse ya da yalnız Ortak seçildiyse Windows yazar): açık
   Engelle kuralı her izin kuralını ezer ve Tailscale yolunu da keser. Yalnız Özel seçilirse Ortak profilde Engelle
   oluşur; bu Tailscale'i etkilemez ama aynı yerel ağdan (Ortak profilli Wi-Fi/Ethernet) host olmayı engeller.
   Durumu salt okunur komutlarla görün (PowerShell, yönetici gerekmez):

   ```powershell
   Get-NetConnectionProfile                     # Tailscale satırı NetworkCategory: Private olmalı
   Get-NetFirewallRule -DisplayName *Insiders* | ft DisplayName,Action,Profile   # Block + Private/Any var mı?
   ```

   Engelle kuralı varsa yönetici PowerShell'de kaldırın, sonra exe'nin tam yoluyla gelen UDP 7777 izin kuralını
   ekleyin (tüm profiller):

   ```powershell
   Get-NetFirewallApplicationFilter -Program "C:\yol\Insiders.exe" | Get-NetFirewallRule | Where-Object Action -eq Block | Remove-NetFirewallRule
   New-NetFirewallRule -DisplayName "Insiders UDP 7777" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 7777 -Program "C:\yol\Insiders.exe"
   # izin kuralını kaldırmak için:
   Remove-NetFirewallRule -DisplayName "Insiders UDP 7777"
   ```

   `netsh` ile aynı izin kuralı ve kaldırması:

   ```bat
   netsh advfirewall firewall add rule name="Insiders UDP 7777" dir=in action=allow program="C:\yol\Insiders.exe" protocol=UDP localport=7777
   netsh advfirewall firewall delete rule name="Insiders UDP 7777"
   ```

   Konsol exe'siyle host olunuyorsa aynı adımları `Insiders.console.exe` için de yapın.
6. **Bağlanmıyorsa:** `tailscale ping <host-adı-ya-da-100.x>` yanıt veriyor mu? `tailscale status` satırında
   `relay` görünüyorsa trafik Tailscale aktarıcısından geçiyor: oyun çalışır ama ping artar (`direct` için UDP'yi
   engelleyen kurumsal/otel ağlarından kaçının). Host'ta 5. adımdaki iki kontrol komutu ne diyor (Tailscale
   Private mı, Insiders için Block kuralı var mı)? Herkes aynı build'i mi
   kullanıyor (protokol sürümü farklıysa host bağlantıyı reddeder)? Oyundaki ping göstergesi sürekli yüksekse
   `tailscale status`'a bakın.

HUD ping'i gösterir; oyun 150 ms RTT'ye kadar akıcı kalacak şekilde test edilir (Faz 1 çıkış kriteri).

**Test build'i notları:** Build imzasızdır; SmartScreen uyarırsa **Ek bilgi → Yine de çalıştır**. Sesler yer
tutucudur (ya da henüz yoktur). `test-*` Release zip'leri **debug build**'dir (debug şablonu): betik hataları
(`SCRIPT ERROR: …` + iz) ve çökmeler (`CrashHandlerException …`) günlük dosyasına yazılır; release build bunları
hiç yazmaz. **Sorun bildirirken** günlük dosyasını gönderin:
`%APPDATA%\Godot\app_userdata\Insiders\logs\godot.log` (Linux: `~/.local/share/godot/app_userdata/Insiders/logs/`);
her oturum yeni dosya açar, öncekiler tarihli adla aynı klasörde kalır.

## Test

```sh
tools/ci_local.sh                         # Godot getir → içe aktar → birim testler → araç testleri → ağ senaryoları (0 ve 150 ms)
tools/ci_local.sh unit                    # yalnız bir adım: godot | import | unit | tools | net | export
GODOT=/yol/godot tools/ci_local.sh        # kurulu bir Godot ile
```

İlk hatada sıfır olmayan kodla çıkar; push öncesi yeşil olmalı. GitHub Actions (`.github/workflows/ci.yml`)
aynı adımları `dev` ve `main` push'unda (ve `test-*` etiketinde) koşar; `export` varsayılan listede değildir, CI
onu yalnız `main` push'unda ve `test-*` etiketinde koşup build'leri yükler (bkz. Build'i çalıştırma). Birim testler doğrudan:
`godot --headless --path . -s res://tests/run_tests.gd -- --filter=smoke`
(testler `tests/unit/test_*.gd`, `extends TestCase`; yardımcılar `tests/t.gd`).

## Ekran görüntüsü

Headless renderer görüntü üretmez; `tools/screenshot.py` görüntüsü istenen peer'ları GPU'lu pencerede açar
(ekranlı bir masaüstü gerekir; CI'da ya da ekransız ortamda "atlandı" deyip 0 döner).

```sh
python tools/screenshot.py --scenario tests/net/store_walk.json --at 3,5.5,8      # store_a, 3 oyuncu, walk botları
python tools/screenshot.py --at 2,4 --clients 0 --bot host=res://tests/net/bots/wander.json --peers host
```

Çıktı `build/screens/<ad>/<peer>_<an>.png` (an = host başlangıcından saniye); her PNG pencere boyutunda
(`--window-size`, varsayılan 1280x720) ve boş/siyah olmadığı denetlenir; geçersiz olan `*_INVALID.png` adıyla
ayrılır. İstemci seviyeyi henüz yüklememişken düşen an hata değildir, "atlandı" satırıyla yazılır. Pencereli exe:
`--godot-gui`, `GODOT_GUI` ya da `GODOT` console exe'sinin yanındaki `*.exe`. Oyunun kendisi de doğrudan alabilir:
`-- --host --screenshot-at=2,4 --screenshot-dir=C:/yol --window-size=1280x720 --quit-after=5` (S6).
Bu argümanlar geliştirici aracıdır (export build'de de çalışır, oyuncuya yönelik değildir).

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
