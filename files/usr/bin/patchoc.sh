#!/bin/bash

if ! grep -q "Config Editor" $CONT && [ -f "/www/tinyfm/tinyfm.php" ]; then
    sed -i '87 i\	entry({"admin", "services", "openclash", "editor"}, template("openclash/editor"),_("Config Editor"), 90).leaf = true' $CONT
    cat << EOF > /usr/lib/lua/luci/view/openclash/editor.htm
<%+header%>
<div class="cbi-map">
<iframe id="editor" style="width: 100%; min-height: 100vh; border: none; border-radius: 2px;"></iframe>
</div>
<script type="text/javascript">
document.getElementById("editor").src = "http://" + window.location.hostname + "/tinyfm/tinyfm.php?p=etc/openclash";
</script>
<%+footer%>
EOF
elif grep -q "Config Editor" $CONT && [ ! -f "/www/tinyfm/tinyfm.php" ]; then
	sed -i '/Config Editor/d' $CONT
fi
echo "done."
