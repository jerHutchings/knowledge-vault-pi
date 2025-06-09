#!/bin/bash
# Knowledge Vault Pi - Unified Install Script
# This script sets up a Raspberry Pi or Linux system with offline knowledge resources,
# allowing the user to choose what content to install interactively.

set -e

# Create directories
mkdir -p ~/knowledge-vault/{zim,pdfs,maps,eBooks,scripts,index}
cd ~/knowledge-vault

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget unzip git recoll lighttpd dnsmasq hostapd dialog

# Install Kiwix tools
wget https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-arm64.tar.gz
mkdir -p kiwix-tools && tar -xzf kiwix-tools_linux-arm64.tar.gz -C kiwix-tools --strip-components=1

# Interactive content selection using dialog
HEIGHT=20
WIDTH=60
CHOICE_HEIGHT=10
BACKTITLE="Knowledge Vault Setup"
TITLE="Select Content to Install"
MENU="Choose content categories:"

OPTIONS=(
  1 "Wikipedia Simple (ZIM)"
  2 "Khan Academy (ZIM)"
  3 "Project Gutenberg (ZIM)"
  4 "Health PDFs"
  5 "Engineering PDFs"
  6 "Offline Canada Maps (.osm.pbf)"
  7 "Programming Guides (Python, Linux)"
  8 "Recoll Search Index"
)

CHOICES=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --checklist "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear

for CHOICE in $CHOICES; do
  case $CHOICE in
    "1")
      wget -O zim/wikipedia_simple_all_maxi.zim https://download.kiwix.org/zim/wikipedia/wikipedia_simple_all_maxi.zim
      ;;
    "2")
      wget -O zim/khan-academy_en_all.zim https://download.kiwix.org/zim/khan-academy_en_all.zim
      ;;
    "3")
      wget -O zim/gutenberg_en_all.zim https://download.kiwix.org/zim/gutenberg/gutenberg_en_all.zim
      ;;
    "4")
      wget -P pdfs https://hesperian.org/wp-content/uploads/pdf/en_where_there_is_no_doctor_2015/en_where_there_is_no_doctor_2015.pdf
      ;;
    "5")
      wget -P pdfs https://ocw.mit.edu/courses/mechanical-engineering/2-003sc-engineering-dynamics-fall-2011/Engineering_Dynamics.pdf
      ;;
    "6")
      wget -P maps https://download.geofabrik.de/north-america/canada-latest.osm.pbf
      ;;
    "7")
      wget -P pdfs https://www.gnu.org/software/emacs/manual/pdf/eintr.pdf
      ;;
    "8")
      echo "Indexing content with Recoll..."
      recollindex -c ~/knowledge-vault/index
      ;;
  esac
  sleep 1
done

# Set up local HTTP server for Kiwix
cat <<EOF | sudo tee /etc/lighttpd/conf-available/99-kiwix.conf
server.document-root = "/home/pi/knowledge-vault/zim"
server.port = 8080
EOF

sudo lighttpd-enable-mod 99-kiwix
sudo systemctl restart lighttpd

# DONE
echo "✅ Knowledge Vault Pi setup complete. Access Kiwix at http://localhost:8080 or over Wi-Fi if enabled."
