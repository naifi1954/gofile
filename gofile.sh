#!/usr/bin/env bash
set -e

BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/gofile"
SCRIPT_PATH="$BIN_DIR/gofile"

mkdir -p "$BIN_DIR" "$CONFIG_DIR"

# Pastikan requests terinstall
pip install --user --quiet requests

# Tulis script utama
cat > "$SCRIPT_PATH" << 'PYEOF'
#!/usr/bin/env python3
import sys
import os
import json
import requests

CONFIG_DIR = os.path.expanduser("~/.config/gofile")
TOKEN_FILE = os.path.join(CONFIG_DIR, "token")


def get_token():
    if os.environ.get("GOFILE_TOKEN"):
        return os.environ["GOFILE_TOKEN"]
    if os.path.isfile(TOKEN_FILE):
        with open(TOKEN_FILE) as f:
            t = f.read().strip()
            return t if t else None
    return None


def get_server():
    resp = requests.get("https://api.gofile.io/servers")
    resp.raise_for_status()
    data = resp.json()
    if data["status"] != "ok":
        raise RuntimeError(f"Gagal ambil server: {data}")
    return data["data"]["servers"][0]["name"]


def upload(filepath, token=None, folder_id=None):
    if not os.path.isfile(filepath):
        print(f"File tidak ditemukan: {filepath}", file=sys.stderr)
        sys.exit(1)

    server = get_server()
    url = f"https://{server}.gofile.io/contents/uploadfile"

    data = {}
    if token:
        data["token"] = token
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
        print("Pemakaian: gofile <file> [--folder FOLDER_ID] [--no-token]", file=sys.stderr)
        sys.exit(1)

    filepath = sys.argv[1]
    folder_id = None
    use_token = True

    args = sys.argv[2:]
    i = 0
    while i < len(args):
        if args[i] == "--folder" and i + 1 < len(args):
            folder_id = args[i + 1]
            i += 2
        elif args[i] == "--no-token":
            use_token = False
            i += 1
        else:
            i += 1

    token = get_token() if use_token else None
    data = upload(filepath, token=token, folder_id=folder_id)

    print(json.dumps(data, indent=2))
    print("\nDownload page:", data.get("downloadPage"))
    if data.get("directLink"):
        print("Direct link:", data.get("directLink"))


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
echo "Kalau punya token Gofile (dari gofile.io > Profile > API), simpan dengan:"
echo "  echo 'TOKEN_KAMU' > $TOKEN_FILE"
echo ""
echo "Lalu jalankan (buka terminal baru atau 'source ~/.bashrc' dulu):"
echo "  gofile namafile.zip"
