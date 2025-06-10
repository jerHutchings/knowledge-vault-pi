#!/bin/bash
# Knowledge Vault Pi - Unified Install Script
# This script sets up a Raspberry Pi or Linux system with offline knowledge resources,
# allowing the user to choose what content to install interactively.

set -e

# Detect architecture and choose appropriate Kiwix tools
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"
if [[ "$ARCH" == "armv6l" || "$ARCH" == "armv7l" ]]; then
  echo "Installing Kiwix tools for 32-bit ARM..."
  KIWIX_URL="https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-armv6.tar.gz"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  echo "Installing Kiwix tools for 64-bit ARM..."
  KIWIX_URL="https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-arm64.tar.gz"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Check for lite flag
LITE=false
for arg in "$@"; do
  if [[ "$arg" == "--lite" ]]; then
    LITE=true
    echo "Running in lite mode. Only smaller files will be available."
  fi
done

# Create directories
mkdir -p ~/knowledge-vault/{zim,pdfs,maps,eBooks,scripts,index}
cd ~/knowledge-vault

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget unzip git recoll lighttpd dnsmasq hostapd dialog

# Install Kiwix tools
if ! wget "$KIWIX_URL" -O kiwix-tools.tar.gz; then
  echo "❌ Failed to download Kiwix tools."
fi
mkdir -p kiwix-tools && tar -xzf kiwix-tools.tar.gz -C kiwix-tools --strip-components=1

# Interactive content selection using dialog
HEIGHT=20
WIDTH=60
CHOICE_HEIGHT=10
BACKTITLE="Knowledge Vault Setup"
TITLE="Select Content to Install"
MENU="Choose content categories:"

OPTIONS=(
  1 "Wikipedia Simple (ZIM)" off  
  2 "Project Gutenberg (ZIM)" off
  3 "Health PDFs" off
  4 "Engineering PDFs" off
  5 "Offline Canada Maps (.osm.pbf)" off
  6 "Programming Guides (Python, Linux)" off
  7 "Recoll Search Index" off
  8 "Fix It Guides (ZIM)" off
  9 "LibreTexts STEM Library (ZIM)" off
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
    "8")
      if [ ! -f zim/ifixit_en_all_2025-03.zim ]; then
        if ! wget -O zim/ifixit_en_all_2025-03.zim https://download.kiwix.org/zim/ifixit/ifixit_en_all_2025-03.zim; then
          echo "❌ Failed to download Fix It ZIM."
        fi
      else
        echo "✔️ Fix It ZIM already downloaded."
      fi
      ;;
    "1")
      WIKI_ZIM=$(curl -s https://download.kiwix.org/zim/wikipedia/ | grep -Eo 'wikipedia_en_simple_all_maxi_[0-9\-]+\.zim' | tail -1)
      if [ ! -f zim/"$WIKI_ZIM" ]; then
        if ! wget -O zim/"$WIKI_ZIM" https://download.kiwix.org/zim/wikipedia/"$WIKI_ZIM"; then
          echo "❌ Failed to download Wikipedia ZIM."
        fi
      else
        echo "✔️ Wikipedia ZIM already downloaded."
      fi
      ;;
    "2")
      if [ ! -f zim/gutenberg_en_all.zim ]; then
        if ! wget -O zim/gutenberg_en_all.zim https://download.kiwix.org/zim/gutenberg/gutenberg_en_all_2023-08.zim; then
          echo "❌ Failed to download Gutenberg ZIM."
        fi
      else
        echo "✔️ Gutenberg ZIM already downloaded."
      fi
      ;;
    "3")
      if [ ! -f pdfs/Where\ there\ is\ no\ Doctor\ -\ David\ Werner.pdf ]; then
        if ! wget -P pdfs "http://www.frankshospitalworkshop.com/organisation/biomed_documents/Where%20there%20is%20no%20Doctor%20-%20David%20Werner.pdf"; then
          echo "❌ Failed to download Health PDF."
        fi
      else
        echo "✔️ Health PDF already downloaded."
      fi
      ;;
    "4")
      if $LITE; then
        echo "Skipping engineering PDFs in lite mode."
      else
        if [ ! -f pdfs/An\ Introduction\ to\ Mechanical\ Engineering.pdf ]; then
          if ! wget -P pdfs https://ftp.idu.ac.id/wp-content/uploads/ebook/tdg/DESIGN%20SISTEM%20DAYA%20GERAK/An%20Introduction%20to%20Mechanical%20Engineering.pdf; then
            echo "❌ Failed to download Engineering PDF."
          fi
        else
          echo "✔️ Intro to Mechanical Engineering PDF already downloaded."
        fi
      fi
      ;;
    "5")
      if [ ! -f maps/canada-latest.osm.pbf ]; then
        if ! wget -P maps https://download.geofabrik.de/north-america/canada-latest.osm.pbf; then
          echo "❌ Failed to download Canada map."
        fi
      else
        echo "✔️ Canada map already downloaded."
      fi
      ;;
    "6")
      if [ ! -f pdfs/eintr.pdf ]; then
        if ! wget -P pdfs https://www.gnu.org/software/emacs/manual/pdf/eintr.pdf; then
          echo "❌ Failed to download Programming guide."
        fi
      else
        echo "✔️ Programming guide already downloaded."
      fi
      ;;
    "7")
      echo "Indexing content with Recoll..."
      recollindex -c ~/knowledge-vault/index
      ;;
    "9")
      LT_ZIM=$(curl -s https://download.kiwix.org/zim/libretexts/ | grep -Eo 'libretexts_en_[a-z0-9_]+_[0-9\-]+\.zim' | tail -1)
      if [ ! -f zim/"$LT_ZIM" ]; then
        if ! wget -O zim/"$LT_ZIM" https://download.kiwix.org/zim/libretexts/"$LT_ZIM"; then
          echo "❌ Failed to download LibreTexts ZIM."
        fi
      else
        echo "✔️ LibreTexts ZIM already downloaded."
      fi
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

# Set permissions for vault directories
sudo chown -R www-data:www-data ~/knowledge-vault
sudo chmod -R 755 ~/knowledge-vault

# DONE
echo "✅ Knowledge Vault Pi setup complete. Access Kiwix at http://localhost:8080 or over Wi-Fi if enabled."
