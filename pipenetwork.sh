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

# Menu opsi
while true; do
    echo "Opsi yang tersedia:"
    echo "1. Instal Node"
    echo "2. Cek logs"
    echo "3. Cek status Node"
    echo "4. Cek Earned Points"
    echo "5. Masukkan Referrals"
    echo "6. Restart Node"
    echo "7. Stop Node"
    echo "8. Keluar"

    # Meminta pilihan dari pengguna
    read -p "Masukkan nomor opsi (1-8): " option

    case $option in
        1)
            # Opsi 1: Instal dan setup Node (tanpa cek status layanan)
            echo "Memulai instalasi dan setup Node..."

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
            sudo systemctl restart pipenetwork

            # Menampilkan status setelah instalasi
            echo "Node berhasil diinstal dan layanan pipenetwork dimulai."
            ;;
        2)
            echo "Cek logs dengan perintah 'cd pipenetwork && ./pop --status'..."
            cd $HOME/pipenetwork && ./pop --status
            ;;
        3)
            echo "Cek status Node dengan perintah 'cd pipenetwork && ./pop --status'..."
            cd $HOME/pipenetwork && ./pop --status
            ;;
        4)
            echo "Cek Earned Points dengan perintah './pop --points-route'..."
            cd $HOME/pipenetwork && ./pop --points-route
            ;;
        5)
            read -p "Masukkan referral ID: " referral_id
            echo "Masukkan referral ID $referral_id dengan perintah './pop --signup-by-referral-route $referral_id'..."
            cd $HOME/pipenetwork && ./pop --signup-by-referral-route $referral_id
            ;;
        6)
            # Opsi 6: Restart Node
            echo "Merestart layanan pipenetwork..."
            sudo systemctl enable pipenetwork && \
            sudo systemctl restart pipenetwork
            echo "Layanan pipenetwork berhasil direstart."
            ;;
        7)
            # Opsi 7: Stop Node
            echo "Menghentikan dan menonaktifkan layanan pipenetwork..."
            sudo systemctl stop pipenetwork && sudo systemctl disable pipenetwork
            echo "Layanan pipenetwork berhasil dihentikan dan dinonaktifkan."
            ;;
        8)
            # Opsi 8: Keluar
            echo "Keluar..."
            exit 0
            ;;
        *)
            # Pilihan tidak valid, kembali ke menu
            echo "Opsi tidak valid. Kembali ke menu opsi tersedia."
            ;;
    esac
done
