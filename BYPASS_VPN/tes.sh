for t in $(ip rule show | awk '{print $NF}' | sort -u); do
  gw=$(ip route show table $t 2>/dev/null | awk '/default/ {print $3}')
  [ -n "$gw" ] && echo "Tabel $t -> gateway $gw"
done
