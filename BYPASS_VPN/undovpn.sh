#!/system/bin/sh
# undo_novpn.sh — hapus aturan novpn
#by born30

PKG=$(cat APP-TARGET.txt)
#PKG="appnovatica.stbp"
TABLE_ID="66"
FWMARK="0x66"

if [ "$(id -u)" != "0" ]; then
  echo "Run as root (su)."
  exit 1
fi

APPUID=$(cmd package list packages -U | awk -F'uid:' -v P="$PKG" '$0~P{print $2; exit}')
if [ -z "$APPUID" ]; then
  APPUID=$(dumpsys package "$PKG" 2>/dev/null | awk -F'userId=' '/userId=/{print $2; exit}')
fi

echo "=== UNDO NOVPN for $PKG (UID $APPUID) ==="

# remove marks/rules/nat
iptables -w -t mangle -D OUTPUT -m owner --uid-owner "$APPUID" -j MARK --set-mark "$FWMARK" 2>/dev/null || true
iptables -w -t mangle -D PREROUTING -j MARK --set-mark "$FWMARK" 2>/dev/null || true
iptables -w -t nat -D POSTROUTING -m mark --mark "$FWMARK" -o wlan0 -j MASQUERADE 2>/dev/null || true
iptables -w -t nat -D POSTROUTING -o wlan0 -m owner --uid-owner "$APPUID" -j MASQUERADE 2>/dev/null || true
ip rule del uidrange "$APPUID"-"$APPUID" lookup "$TABLE_ID" 2>/dev/null || true
ip rule del fwmark "$FWMARK" lookup "$TABLE_ID" 2>/dev/null || true
ip route flush table "$TABLE_ID" 2>/dev/null || true
ip route flush cache 2>/dev/null || true

echo "✅ Undo selesai."
