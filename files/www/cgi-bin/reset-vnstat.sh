#!/bin/sh

echo "Content-Type: text/plain"
echo ""

# Execute the reset command
/www/vnstati/vnstati.sh >/dev/null 2>&1
rm -f /etc/vnstat/vnstat.db
service vnstat restart
sleep 2
/www/vnstati/vnstati.sh

echo "Reset completed"