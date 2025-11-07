#!/system/bin/sh
# novpn.sh — jalankan sebagai root (su)
# Tujuan: Mengecualikan 1 APK agar bypass VPN dan keluar via wlan0
# Strategi:
#  - buat routing table khusus (TABLE_ID)
#  - tambahkan ip rule uidrange -> table
#  - tandai paket: (1) mangle PREROUTING mark semua, (2) optional owner match
#  - NAT berdasarkan fwmark (MASQUERADE) dan owner fallback
#  - lakukan cleanup aman sebelum menambah aturan
#by Born30

PKG=$(cat APP-TARGET.txt)
TABLE_ID="66"
FWMARK="0x66"

# check root
if [ "$(id -u)" != "0" ]; then
  echo "Script harus dijalankan sebagai root (su)."
  exit 1
fi

echo "=== NOVPN: Mengecualikan $PKG dari VPN ==="

# get uid (try multiple methods)
APPUID=$(cmd package list packages -U | awk -F'uid:' -v P="$PKG" '$0~P{print $2; exit}')
if [ -z "$APPUID" ]; then
  APPUID=$(dumpsys package "$PKG" 2>/dev/null | awk -F'userId=' '/userId=/{print $2; exit}')
fi
if [ -z "$APPUID" ]; then
  echo "❌ Gagal menemukan UID untuk $PKG"
  exit 1
fi
echo "UID = $APPUID"

# find gateway: prefer table wlan0, then main, then guess from IP
GW=$(ip route show table wlan0 2>/dev/null | awk '/default/ {print $3; exit}')
if [ -z "$GW" ]; then
  GW=$(ip route show table main 2>/dev/null | awk '/default/ {print $3; exit}')
fi
if [ -z "$GW" ]; then
  IP4=$(ip addr show wlan0 2>/dev/null | awk '/inet /{print $2; exit}')
  if [ -n "$IP4" ]; then
    NET=$(echo "$IP4" | cut -d'/' -f1 | cut -d'.' -f1-3)
    GW="${NET}.1"
  fi
fi

if [ -z "$GW" ]; then
  echo "❌ Gagal menentukan gateway wlan0. Pastikan Wi‑Fi aktif."
  exit 1
fi
echo "Gateway wlan0 = $GW"

# ---------------------------
# CLEANUP (safe)
# ---------------------------
echo "Membersihkan aturan lama (jika ada)..."
iptables -w -t mangle -D OUTPUT -m owner --uid-owner "$APPUID" -j MARK --set-mark "$FWMARK" 2>/dev/null || true
iptables -w -t mangle -D PREROUTING -j MARK --set-mark "$FWMARK" 2>/dev/null || true
iptables -w -t nat -D POSTROUTING -m owner --uid-owner "$APPUID" -o wlan0 -j MASQUERADE 2>/dev/null || true
iptables -w -t nat -D POSTROUTING -m mark --mark "$FWMARK" -o wlan0 -j MASQUERADE 2>/dev/null || true
ip rule del uidrange "$APPUID"-"$APPUID" lookup "$TABLE_ID" 2>/dev/null || true
ip rule del fwmark "$FWMARK" lookup "$TABLE_ID" 2>/dev/null || true
ip route flush table "$TABLE_ID" 2>/dev/null || true

# ---------------------------
# SETUP routing table & rule
# ---------------------------
echo "Membuat route default di table $TABLE_ID via $GW dev wlan0 ..."
ip route add default via "$GW" dev wlan0 table "$TABLE_ID" 2>/dev/null || ip route replace default via "$GW" dev wlan0 table "$TABLE_ID" 2>/dev/null || true

# prefer uidrange rule (higher priority than Android netd rules)
echo "Menambahkan ip rule uidrange untuk UID $APPUID -> table $TABLE_ID (priority 9999)..."
ip rule add uidrange "$APPUID"-"$APPUID" lookup "$TABLE_ID" priority 9999 2>/dev/null || true

# also add fwmark rule fallback with high priority (lower number = higher priority)
ip rule del fwmark "$FWMARK" lookup "$TABLE_ID" 2>/dev/null || true
ip rule add fwmark "$FWMARK" lookup "$TABLE_ID" priority 100 2>/dev/null || true

# ---------------------------
# MARKING: try several ways (owner + prerouting universal)
# ---------------------------
echo "Memasang iptables marking (PREROUTING + owner fallback)..."
# mark early in PREROUTING for all packets (broad) — will mark traffic entering stack
iptables -w -t mangle -A PREROUTING -j MARK --set-mark "$FWMARK" 2>/dev/null || true

# also try marking OUTPUT by owner (if it matches)
iptables -w -t mangle -A OUTPUT -m owner --uid-owner "$APPUID" -j MARK --set-mark "$FWMARK" 2>/dev/null || true

# ---------------------------
# NAT: prefer fwmark-based MASQUERADE inserted before other chains
# ---------------------------
echo "Menambahkan NAT (MASQUERADE) berbasis mark di posisi paling depan POSTROUTING..."
# insert mark-based NAT as first rule
iptables -w -t nat -I POSTROUTING 1 -m mark --mark "$FWMARK" -o wlan0 -j MASQUERADE 2>/dev/null || true
# add owner-based fallback (some kernels support owner)
iptables -w -t nat -A POSTROUTING -o wlan0 -m owner --uid-owner "$APPUID" -j MASQUERADE 2>/dev/null || true

# refresh routing cache
ip route flush cache 2>/dev/null || true

# force-stop app so new sockets are created under new routing
echo "Memaksa stop aplikasi agar koneksi baru dibuat..."
am force-stop "$PKG" 2>/dev/null || true
sleep 1

echo "✅ Selesai — periksa status:"
echo "  ip rule show | grep $TABLE_ID"
echo "  ip route show table $TABLE_ID"
echo "  iptables -t mangle -L PREROUTING,OUTPUT -v --line-numbers"
echo "  iptables -t nat -L POSTROUTING -v --line-numbers"
echo ""
echo "Jika app masih tidak konek, jalankan:"
echo "  iptables -t mangle -L PREROUTING -v --line-numbers"
echo "  iptables -t mangle -L OUTPUT -v --line-numbers"
echo "  iptables -t nat -L POSTROUTING -v --line-numbers"
