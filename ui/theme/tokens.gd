class_name ThemeTokens
extends RefCounted
## Tema token'ları (S9 — docs/notes/mimari.md). Renkler yalnız buradan ve ui/theme/noir.tres'ten okunur.
## IS-003 stub'ı: temel palet; noir paletini ve diğer token'ları arayuz US-003'te tamamlar.
## GAMEPLAY_* ve PLAYER_COLORS oyun için anlamlıdır, her tonda aynı kalır.

const BG := Color("#0f1114")
const FG := Color("#e6e2d8")
const MUTED := Color("#7a7e86")
const ACCENT := Color("#c9a24b")
const WALL := Color("#2c2f36")
const FLOOR := Color("#1a1c21")

const GAMEPLAY_ALERT := Color("#d8453a")
const GAMEPLAY_CASH := Color("#58b368")

## Oyuncu renkleri, katılım sırasıyla (en fazla 4 oyuncu).
const PLAYER_COLORS: Array[Color] = [
	Color("#4f9ddf"),
	Color("#e48a3a"),
	Color("#a77fd8"),
	Color("#45b8aa"),
]
