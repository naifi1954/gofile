#!/usr/bin/env bash
set -e

BIN_DIR="$HOME/.local/bin"
SCRIPT_PATH="$BIN_DIR/gofile"

mkdir -p "$BIN_DIR"

# Pastikan requests terinstall
sudo apt install python3 && sudo apt install python3-pip -y
pip install --user --quiet requests

# Tulis script utama
cat > "$SCRIPT_PATH" << 'PYEOF'
#!/usr/bin/env python3
import sys
import os
import json
import requests


def get_server():
    resp = requests.get("https://api.gofile.io/servers")
    resp.raise_for_status()
    data = resp.json()
    if data["status"] != "ok":
        raise RuntimeError(f"Gagal ambil server: {data}")
    return data["data"]["servers"][0]["name"]


def upload(filepath, folder_id=None):
    if not os.path.isfile(filepath):
        print(f"File tidak ditemukan: {filepath}", file=sys.stderr)
        sys.exit(1)

    server = get_server()
    url = f"https://{server}.gofile.io/contents/uploadfile"

    data = {}
    if folder_id:
        data["folderId"] = folder_id

    filesize = os.path.getsize(filepath)
    print(f"Uploading {filepath} ({filesize/1024/1024:.2f} MB) ke server {server}...", file=sys.stderr)

    with open(filepath, "rb") as f:
        files = {"file": (os.path.basename(filepath), f)}
        resp = requests.post(url, data=data, files=files)

    resp.raise_for_status()
    result = resp.json()

    if result["status"] != "ok":
        print(f"Upload gagal: {result}", file=sys.stderr)
        sys.exit(1)

    return result["data"]


def main():
    if len(sys.argv) < 2:
        print("Pemakaian: gofile <file> [--folder FOLDER_ID]", file=sys.stderr)
        sys.exit(1)

    filepath = sys.argv[1]
    folder_id = None

    args = sys.argv[2:]
    i = 0
    while i < len(args):
        if args[i] == "--folder" and i + 1 < len(args):
            folder_id = args[i + 1]
            i += 2
        else:
            i += 1

    data = upload(filepath, folder_id=folder_id)

    print(json.dumps(data, indent=2))
    print("\nDownload page:", data.get("downloadPage"))


if __name__ == "__main__":
    main()
PYEOF

chmod +x "$SCRIPT_PATH"

# Pastikan ~/.local/bin ada di PATH via .bashrc
if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "Menambahkan ~/.local/bin ke PATH di .bashrc"
fi

echo ""
echo "Setup selesai."
echo "Command terpasang di: $SCRIPT_PATH"
echo ""
