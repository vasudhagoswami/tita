#!/bin/bash

SC_SESSION="tita"
INIT_CMD="tted daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0"
RUN_CMD="tted daemon start"

# --------------
# Path to .bashrc or .profile - Extra code
BASHRC=~/.profile
# Remove the specific line if it exists
sed -i '/export PATH="\$PATH:\/root\/.avail\/bin"/d' ~/.bashrc
# Add the new line if it doesn't already exist
grep -q 'export LD_LIBRARY_PATH=.*:/usr/local/bin/' "$BASHRC" || echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/' >> "$BASHRC"

source $BASHRC
# --------------

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/

# Stop old daemon
tted daemon stop
sleep 5
# Do it again
kill -9 $(pgrep -f "tted")

# RM old node
rm /usr/bin/ttca
rm /usr/bin/tted
rm /usr/bin/ttlo
rm /usr/bin/ttsche

if [ ! -d "/tmp/.tita" ]; then
    mkdir /tmp/.tita
fi
if [ ! -d "/media/.top" ]; then
    mkdir /media/.top
fi
cd /media/.top

# Back old node and rm data
mkdir /media/.top/herschel_bak
cp /root/.titanedge/aconfig.toml /media/.top/herschel_bak/
cp /root/.titanedge/node_id /media/.top/herschel_bak/
cp /root/.titanedge/private.key /media/.top/herschel_bak/
cp /root/.titanedge/token /media/.top/herschel_bak/
cp /media/.top/nohash /media/.top/herschel_bak/
rm -rf /root/.titanedge
rm -rf /media/.top/tita

# ----------------------------
# Automatically download the source binary

# Install dependencies, Update package lists to make sure we get the latest versions
sudo apt-get update
# Install snap and jq, and ensure the installation completes before proceeding
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

# Input node hash
read -p "Enter a node hash: " node_hash

# Backup to a file 
if [ -n "$node_hash" ]; then
    # Write the node_hash to a file
    echo "$node_hash" > nohash
else
    echo "Node hash is empty. Check input"
    exit
fi

# Read the existing node hash
# read -r node_hash < /media/.top/nohash

# Print the variable
# echo "node hash: $node_hash"

# Run the command
# Start with screen -S to init
# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/
screen -dmS "$SC_SESSION" bash -c "$INIT_CMD"

# Start by background call
# nohup tted daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0  > /tmp/.tita/edge.log 2>&1 &
# tted_pid=$!  # Get the PID of the last background process
# wait $tted_pid
# kill -9 $(pgrep -f "tted")
sleep 10

# Bind the node with account hash
echo "Node_hash: $node_hash"
tted bind --hash=$node_hash https://api-test1.container1.titannet.io/api/v2/device/binding

sleep 5
echo "Show info"
echo ""
tted show binding-info https://api-test1.container1.titannet.io/api/v2/device
echo ""

# -----------------------------------------------------------
# Re-configure crontab
search_text='ticheck.sh'
new_cmd='*/5 * * * * bash /usr/local/bin/ticheck.sh tita & bash /usr/local/bin/topnu.sh'

# Remove the existing cronjob line if it exists new_cmd
if crontab -l | grep "$search_text"; then
        crontab -l | grep -v "$search_text" | crontab -
fi

# Add the new cronjob with the new schedule
crontab -l | { cat; echo "$new_cmd"; } | crontab -

# ------- Create ticheck.sh in /usr/local/bin/ticheck.sh ---
# Update checker
curl -O https://raw.githubusercontent.com/vasudhagoswami/tita/main/ticheck.sh
chmod u+x ticheck.sh
mv ticheck.sh /usr/local/bin/

#-------------------------
# Change disk space
tted config set --storage-size 100GB
# Restart node
tted daemon stop
sleep 2
screen -dmS "$SC_SESSION" bash -c "$RUN_CMD"
sleep 3
#-------------------------

rm ~/tita_install_patch.sh
history -c 

echo ""
echo "Done setup!"
echo ""
