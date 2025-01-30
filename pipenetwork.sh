#!/bin/bash

# Menampilkan ASCII Art untuk "Saandy"
echo "
  ██████ ▄▄▄     ▄▄▄      ███▄    █▓█████▓██   ██▓
▒██    ▒▒████▄  ▒████▄    ██ ▀█   █▒██▀ ██▒██  ██▒
░ ▓██▄  ▒██  ▀█▄▒██  ▀█▄ ▓██  ▀█ ██░██   █▌▒██ ██░
  ▒   ██░██▄▄▄▄█░██▄▄▄▄██▓██▒  ▐▌██░▓█▄   ▌░ ▐██▓░
▒██████▒▒▓█   ▓██▓█   ▓██▒██░   ▓██░▒████▓ ░ ██▒▓░
▒ ▒▓▒ ▒ ░▒▒   ▓▒█▒▒   ▓▒█░ ▒░   ▒ ▒ ▒▒▓  ▒  ██▒▒▒ 
░ ░▒  ░ ░ ▒   ▒▒ ░▒   ▒▒ ░ ░░   ░ ▒░░ ▒  ▒▓██ ░▒░ 
░  ░  ░   ░   ▒   ░   ▒     ░   ░ ░ ░ ░  ░▒ ▒ ░░  
      ░       ░  ░    ░  ░        ░   ░   ░ ░     
                                    ░     ░ ░     
"

# Cek apakah port 8003 digunakan, hentikan proses yang menggunakannya
echo "Memeriksa apakah port 8003 sedang digunakan..."
PID=$(lsof -t -i:8003)

if [ -n "$PID" ]; then
    echo "Port 8003 sedang digunakan oleh proses dengan PID $PID. Menghentikan proses..."
    kill -9 $PID
else
    echo "Port 8003 tidak digunakan. Melanjutkan..."
fi

# Cek apakah layanan DCDND ada, hentikan dan nonaktifkan jika ada, jika tidak lewati
if systemctl list-units --type=service --state=active | grep -q "dcdnd.service"; then
    echo "Menghentikan layanan DCDND..."
    systemctl stop dcdnd && systemctl disable dcdnd
else
    echo "Layanan DCDND tidak ditemukan, melewati..."
fi

# Buat direktori $HOME/pipenetwork
echo "Membuat folder $HOME/pipenetwork..."
mkdir -p $HOME/pipenetwork

# Membuat folder untuk cache unduhan
echo "Membuat folder cache unduhan $HOME/pipenetwork/download_cache..."
mkdir -p $HOME/pipenetwork/download_cache

# Meminta tautan unduhan binary v2
echo "Masukkan tautan unduhan binary v2 dari email (harus dimulai dengan https):"
read -r binary_url

# Validasi URL dan unduh binary
if [[ $binary_url == https* ]]; then
    echo "Mengunduh binary pop..."
    wget -O $HOME/pipenetwork/pop "$binary_url"
    chmod +x $HOME/pipenetwork/pop
    echo "Binary diunduh dan dibuat dapat dieksekusi."
else
    echo "URL tidak valid. Pastikan tautan dimulai dengan 'https'."
    exit 1
fi

# Meminta jumlah RAM (minimal 4GB)
read -p "Masukkan jumlah RAM yang ingin dibagikan (min 4GB): " RAM
if [ "$RAM" -lt 4 ]; then
  echo "RAM harus minimal 4GB. Keluar."
  exit 1
fi

# Meminta ruang disk maksimal (minimal 100GB)
read -p "Masukkan ruang disk maksimal yang digunakan (min 100GB): " DISK
if [ "$DISK" -lt 100 ]; then
  echo "Ruang disk harus minimal 100GB. Keluar."
  exit 1
fi

# Meminta kunci publik pengguna
read -p "Masukkan kunci publik Anda: " PUBKEY

# Menentukan path file layanan systemd
SERVICE_FILE="/etc/systemd/system/pipenetwork.service"

# Membuat file layanan systemd
echo "Membuat file $SERVICE_FILE..."
cat <<EOF | sudo tee $SERVICE_FILE > /dev/null
[Unit]
Description=Pipe Network Node Service
After=network.target
Wants=network-online.target

[Service]
User=$USER
ExecStart=$HOME/pipenetwork/pop \
    --ram=$RAM \
    --pubKey $PUBKEY \
    --max-disk $DISK \
    --cache-dir $HOME/pipenetwork/download_cache
Restart=always
RestartSec=5
LimitNOFILE=65536
LimitNPROC=4096
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dcdn-node
WorkingDirectory=$HOME/pipenetwork

[Install]
WantedBy=multi-user.target
EOF

# Memuat ulang systemd, mengaktifkan dan memulai layanan pipenetwork
echo "Memuat ulang daemon systemd dan memulai layanan pipenetwork..."
sudo systemctl daemon-reload && \
sudo systemctl enable pipenetwork && \
sudo systemctl restart pipenetwork && \
journalctl -u pipenetwork -fo cat
