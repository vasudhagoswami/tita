#!/bin/bash

SC_SESSION="tita"
INIT_CMD="tted daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0"
RUN_CMD="tted daemon start"

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/

# Stop old daemon
tted daemon stop
sleep 5
# Do it again
kill -9 $(pgrep -f "tted")

# RM old node
rm /usr/bin/tted

if [ ! -d "/tmp/.tita" ]; then
    mkdir /tmp/.tita
fi
if [ ! -d "/media/.top" ]; then
    mkdir /media/.top
fi
cd /media/.top

# ----------------------------
# Automatically download the source binary

# Install dependencies, Update package lists to make sure we get the latest versions
command_exists() {
    which "$1" >/dev/null 2>&1
}
if !(command_exists snap); then 
    sudo apt-get install -y snapd
   # Enable and start snapd service
    sudo systemctl enable --now snapd.socket
    sudo systemctl start snapd.socket
    echo "snap is just installed successfully."
else
    echo "Snap is already installed"
fi
if !(command_exists jq); then 
    sudo snap install jq
    echo "jq is just installed successfully."
else
    echo "jq is already installed"
fi

# GitHub repository
REPO="Titannet-dao/titan-node"

# Fetch the latest release data from GitHub API
echo "Fetching the latest release data..."
RELEASE_DATA=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")

# Extract the tag name and convert it to version (e.g., 0.1.19 -> v0.1.19)
TAG_NAME=$(echo "$RELEASE_DATA" | jq -r '.tag_name')
VERSION="$TAG_NAME"

# Extract asset names and URLs with the specific pattern
echo "Parsing release data..."
ASSET_NAME=$(echo "$RELEASE_DATA" | jq -r '.assets[] | select(.name | contains("edge") and contains("_linux_amd64.tar.gz")) | .name')
ASSET_URL=$(echo "$RELEASE_DATA" | jq -r '.assets[] | select(.name | contains("edge") and contains("_linux_amd64.tar.gz")) | .browser_download_url')

# Check if the asset is found
if [ -n "$ASSET_NAME" ]; then
    # Construct the download file name with version
    DOWNLOAD_FILE="tita.tar.gz"

    echo "Found asset: $ASSET_NAME"
    echo "Version: $VERSION"
    echo "Download URL: $ASSET_URL"
    echo "Download file name: $DOWNLOAD_FILE"

    # Download the asset
    echo "Downloading $ASSET_NAME as $DOWNLOAD_FILE..."
    rm $DOWNLOAD_FILE
    curl -L -o "$DOWNLOAD_FILE" "$ASSET_URL"
    echo "Download completed: $DOWNLOAD_FILE"
    echo ""

    # Extract the file and process data
    tar xvf $DOWNLOAD_FILE
    if ls *titan*linux*amd64* 1> /dev/null 2>&1; then
        rm -rf tita
        mv *titan*linux*amd64* ./tita
    fi   

else
    echo "No matching asset found."
    exit 1
fi
# ----------------------------

# Move to bin
mv /media/.top/tita/titan-edge /usr/bin/tted
mv /media/.top/tita/libgoworkerd.so /usr/local/bin/

# Run the command by METHOD: screen session
# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/
screen -dmS "$SC_SESSION" bash -c "$INIT_CMD"
sleep 8
tted daemon stop
sleep 8
screen -dmS "$SC_SESSION" bash -c "$RUN_CMD"

sleep 5
echo "Show info"
echo ""
tted show binding-info https://api-test1.container1.titannet.io/api/v2/device
echo ""

# ------- Update ticheck.sh in /usr/local/bin/ticheck.sh ---
# Update checker
curl -O https://raw.githubusercontent.com/vasudhagoswami/tita/main/ticheck.sh
chmod u+x ticheck.sh
mv ticheck.sh /usr/local/bin/

rm ~/update.sh
history -c 

echo ""
echo "Done, updated!"
echo ""
