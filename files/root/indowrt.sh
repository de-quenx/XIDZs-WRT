#!/bin/sh

# Mendefinisikan jalur file
TTL_FILE="/etc/nftables.d/ttl65.nft"
INDOWRT_LUA="/usr/lib/lua/luci/controller/indowrt/indowrt.lua"
PAGE_HTM="/usr/lib/lua/luci/view/indowrt/page.htm"

# Fungsi untuk memeriksa dan menghapus file jika sudah ada
hapus_jika_ada() {
    local file_path="$1"
    if [ -e "$file_path" ]; then
        echo "Menghapus file yang sudah ada: $file_path"
        rm -f "$file_path"
    fi
}

# Menghapus file yang sudah ada jika ada
hapus_jika_ada "$TTL_FILE"
hapus_jika_ada "$INDOWRT_LUA"
hapus_jika_ada "$PAGE_HTM"

# Membuat file ttl65.nft dengan nilai TTL yang dinamis
buat_file_ttl() {
    local ttl_value="$1"
    echo "Membuat $TTL_FILE dengan nilai TTL: $ttl_value"
    mkdir -p "$(dirname "$TTL_FILE")"  # Pastikan direktori ada
    cat <<EOL > "$TTL_FILE"
## Fix TTL Indowrt
chain mangle_postrouting_ttl65 {
    type filter hook postrouting priority 300; policy accept;
    counter ip ttl set $ttl_value
}
chain mangle_prerouting_ttl65 {
    type filter hook prerouting priority 300; policy accept;
    counter ip ttl set $ttl_value
}
EOL
}

# Membuat file indowrt.lua
buat_indowrt_lua() {
    echo "Membuat $INDOWRT_LUA"
    mkdir -p "$(dirname "$INDOWRT_LUA")"  # Pastikan direktori ada
    cat <<EOL > "$INDOWRT_LUA"
module("luci.controller.indowrt.indowrt", package.seeall)

function index()
    entry({"admin", "network", "indowrt"}, call("render_page"), _("Fix TTL"), 100).leaf = true
end

function get_current_ttl()
    local output = luci.sys.exec("nft list chain inet fw4 mangle_postrouting_ttl65 2>/dev/null")
    if output and output:match("ip ttl set (%d+)") then
        return tonumber(output:match("ip ttl set (%d+)"))
    end
    return nil
end

function set_ttl(new_ttl)
    local ttl_file = "/etc/nftables.d/ttl65.nft"
    local ttl_rule = string.format([[
## Fix TTL
chain mangle_postrouting_ttl65 {
    type filter hook postrouting priority 300; policy accept;
    counter ip ttl set %d
}
chain mangle_prerouting_ttl65 {
    type filter hook prerouting priority 300; policy accept;
    counter ip ttl set %d
}
]], new_ttl, new_ttl)

    -- Menyimpan aturan baru ke file
    local f = io.open(ttl_file, "w")
    if f then
        f:write(ttl_rule)
        f:close()
    end

    -- Menerapkan aturan baru
    luci.sys.call("nft -f " .. ttl_file)
    luci.sys.call("/etc/init.d/firewall restart")
end

function render_page()
    local http = require "luci.http"
    local sys = require "luci.sys"
    local tpl = require "luci.template"
    local dispatcher = require "luci.dispatcher"

    -- Mengambil pengaturan TTL saat ini
    local current_ttl = get_current_ttl()

    -- Jika nilai TTL sudah dimasukkan, terapkan nilai TTL baru
    local ttl_value = http.formvalue("ttl_value")
    if ttl_value then
        ttl_value = tonumber(ttl_value)
        if ttl_value and ttl_value >= 1 and ttl_value <= 255 then
            set_ttl(ttl_value)
        end
    end

    tpl.render("indowrt/page", {
        current_ttl = current_ttl or "N/A",  -- Menampilkan TTL saat ini, atau N/A jika tidak ada
        ttl_value = ttl_value or current_ttl
    })
end
EOL
}

# Membuat file page.htm di direktori yang benar
buat_page_htm() {
    echo "Membuat $PAGE_HTM"
    mkdir -p "$(dirname "$PAGE_HTM")"  # Pastikan direktori ada
    cat <<EOL > "$PAGE_HTM"
<%+header%>

<h2>Fix TTL</h2>

<% if current_ttl ~= "N/A" then %>
    <div class="cbi-section">
        <h3>Pengaturan TTL Saat Ini: <%= current_ttl %></h3>
    </div>
<% else %>
    <div class="cbi-section">
        <h3>Tidak Ada TTL yang Ditetapkan</h3>
    </div>
<% end %>

<form method="post">
    <div class="cbi-section">
        <label for="ttl_value">Masukkan Nilai TTL:</label>
        <input type="number" id="ttl_value" name="ttl_value" min="1" max="255" value="<%= ttl_value %>" required>
    </div>
    <div class="cbi-section">
        <button class="cbi-button cbi-button-apply" type="submit">
            By Indowrt Klick
        </button>
    </div>
</form>

<%+footer%>
EOL
}

# Eksekusi utama skrip
# Mendapatkan nilai TTL dari input (default: 65 jika tidak ada)
TTL_VALUE="${1:-65}"

# Membuat file-file yang diperlukan
buat_file_ttl "$TTL_VALUE"
buat_indowrt_lua
buat_page_htm

# Menampilkan pesan sukses
echo "Semua file berhasil dibuat"

rm -- "$0"