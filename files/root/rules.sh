#!/bin/sh

FILE_TARGET="/lib/udev/rules.d/77-mm-cinterion-port-types.rules"
FILE_INSERT="/root/modem"
TMP_FILE="/tmp/new.rules"
INSERT_LINE=70

[ ! -f "$FILE_TARGET" ] && touch "$FILE_TARGET"

awk -v insertfile="$FILE_INSERT" -v lineno="$INSERT_LINE" '
  NR == lineno {
    print ""
    while ((getline line < insertfile) > 0) print line
  }
  { print }
' "$FILE_TARGET" > "$TMP_FILE" && mv "$TMP_FILE" "$FILE_TARGET"

# remove file rules
rm -f "$FILE_INSERT"

# remove script
rm -f "$0"