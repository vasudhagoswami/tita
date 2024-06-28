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
sleep 2
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
cp /root/.titanedge/config.toml /media/.top/herschel_bak/
cp /root/.titanedge/node_id /media/.top/herschel_bak/
cp /root/.titanedge/private.key /media/.top/herschel_bak/
cp /root/.titanedge/token /media/.top/herschel_bak/
cp /media/.top/nohash /media/.top/herschel_bak/
rm -rf /root/.titanedge
rm -rf /media/.top/tita

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

# --------------------------------------------------------------------
# Get the latest version from github
    # GitHub repository URL
    REPO_URL="https://api.github.com/repos/Titannet-dao/titan-node/tags"

    # Send a GET request to the GitHub API
    response=$(curl -s "$REPO_URL")

    # Check if the response is empty or if an error occurred
    if [ -z "$response" ]; then
        echo "Error: Unable to fetch tags from GitHub."
        exit 1
    fi

    # Parse the response to extract tag names
    tags=$(echo "$response" | grep -oP '"name": "\K[^"]+')

    # Get the latest tag
    latest_tag=$(echo "$tags" | head -n 1)

    echo "Latest version: $latest_tag"
# --------------------------------------------------------------------

# Replace the newest version $latest_tag to the string v0.1.16 
rm tita.tar.gz
echo "Downloading from: https://github.com/Titannet-dao/titan-node/releases/download/$latest_tag/titan-edge_"$latest_tag"_linux_amd64.tar.gz"
curl -L -o tita.tar.gz "https://github.com/Titannet-dao/titan-node/releases/download/$latest_tag/titan-edge_"$latest_tag"_linux_amd64.tar.gz"

# Extract
tar xvf tita.tar.gz
if [ -d "titan-edge_"$latest_tag"_linux_amd64" ]; then
    rm -rf /media/.top/tita
fi
mv titan-edge_"$latest_tag"_linux_amd64 ./tita

# Move to bin
mv /media/.top/tita/titan-edge /usr/bin/tted
mv /media/.top/tita/libgoworkerd.so /usr/local/bin/

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
screen -dmS "$SC_SESSION" bash -c "$RUN_CMD"
#-------------------------

rm ~/tita_install.sh
history -c 
