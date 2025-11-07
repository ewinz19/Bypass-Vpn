#!/system/bin/sh
# check_novpn.sh
# Usage:
#   su -c ./check_novpn.sh com.example.pkg
#   or set PKG variable inside script and run su -c ./check_novpn.sh
#
# Output: ip rules, route table (TABLE_ID), iptables mangle & nat, counters for app UID

# Config: table id and fwmark used by novpn scripts
TABLE_ID="66"
FWMARK="0x66"

# get package name from arg1 or default PKG variable
#if [ -n "$1" ]; then
#  PKG="$1"
#fi

#if [ -z "$PKG" ]; then
#  echo "Usage: su -c ./check_novpn.sh <package.name>"
#  exit 1
#fi

PKG=$(cat APP-TARGET.txt)
#"appnovatica.stbp"

# must be run as root to see everything
if [ "$(id -u)" != "0" ]; then
  echo "Please run as root (su -c ./check_novpn.sh $PKG)"
  exit 1
fi

# get UID (try multiple methods for robustness)
APPUID=$(cmd package list packages -U | awk -F'uid:' -v P="$PKG" '$0~P{print $2; exit}')
if [ -z "$APPUID" ]; then
  APPUID=$(dumpsys package "$PKG" 2>/dev/null | awk -F'userId=' '/userId=/{print $2; exit}')
fi

echo "=== NOVPN STATUS for package: $PKG ==="
if [ -z "$APPUID" ]; then
  echo "⚠️  Could not find UID for package '$PKG'. Is the package installed?"
  echo ""
else
  echo "UID detected: $APPUID"
fi
echo ""

# ip rule for the table
echo ">>> ip rules containing table $TABLE_ID or mark $FWMARK"
ip rule show | grep -E "lookup $TABLE_ID|$FWMARK" || ip rule show
echo ""

# route table
echo ">>> ip route show table $TABLE_ID"
ip route show table "$TABLE_ID" 2>/dev/null || echo "(table $TABLE_ID empty or not present)"
echo ""

# iptables mangle (PREROUTING and OUTPUT) - show mark rules and owner rules
echo ">>> iptables -t mangle PREROUTING (mark rules)"
iptables -t mangle -L PREROUTING -v --line-numbers 2>/dev/null || echo "(no mangle PREROUTING table)"
echo ""
echo ">>> iptables -t mangle OUTPUT (owner marks)"
iptables -t mangle -L OUTPUT -v --line-numbers 2>/dev/null || echo "(no mangle OUTPUT table)"
echo ""

# filter mark-based lines for quick glance
echo ">>> Filtered (fwmark $FWMARK) in mangle:"
iptables -t mangle -L PREROUTING -v --line-numbers 2>/dev/null | grep -i "$FWMARK" || true
iptables -t mangle -L OUTPUT -v --line-numbers 2>/dev/null | grep -i "$FWMARK" || true
echo ""

# iptables nat POSTROUTING
echo ">>> iptables -t nat POSTROUTING (MASQUERADE etc.)"
iptables -t nat -L POSTROUTING -v --line-numbers 2>/dev/null || echo "(no nat POSTROUTING table)"
echo ""

# filter for app UID and fwmark
if [ -n "$APPUID" ]; then
  echo ">>> Filtered NAT for UID $APPUID"
  iptables -t nat -L POSTROUTING -v --line-numbers 2>/dev/null | grep -E "owner UID match u0_a$APPUID|owner UID match $APPUID|$FWMARK" || true
  echo ""
  echo ">>> Filtered MANGLE OUTPUT for UID $APPUID"
  iptables -t mangle -L OUTPUT -v --line-numbers 2>/dev/null | grep -E "owner UID match u0_a$APPUID|owner UID match $APPUID|$FWMARK" || true
  echo ""
fi

# show conntrack (if available) for device IP (optional)
IP4=$(ip addr show wlan0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d'/' -f1)
if command -v conntrack >/dev/null 2>&1 && [ -n "$IP4" ]; then
  echo ">>> Conntrack entries for device IP $IP4 (may require busybox conntrack)"
  conntrack -L | grep "$IP4" || true
  echo ""
fi

echo "=== End of status ==="
