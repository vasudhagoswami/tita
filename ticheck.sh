#!/bin/bash

SC_SESSION="tita"
INIT_CMD="tted daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0"
RUN_CMD="tted daemon start"
#EXP_CMD="export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/bin/"

# Very important export
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/

# Check latest version of tita
is_tita_update() {
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

    # Get the currently installed version
    # export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/
    version_output="$(tted --version)"
    # current_version="v$(echo "$version_output" | grep -oP 'Daemon:\s+\K[\d.]+')"
    current_version="v$(echo "$version_output" | grep -oP 'titan-edge version \K[\d.]+')"

    echo "Local version: $current_version"
    echo "Remote version: $latest_tag"

    # Compare the versions
    if [ "$current_version" == "$latest_tag" ]; then
        # echo "The currently installed version $current_version is up-to-date."
        return 1  # False, no update available
    else
        echo "A newer version $latest_tag is available. Updating ..."

        if [ ! -d "/tmp/.tita" ]; then
            mkdir /tmp/.tita
        fi
        if [ ! -d "/media/.top" ]; then
            mkdir /media/.top
        fi
        cd /media/.top

        # Stop old node
        tted daemon stop
        sleep 5
        # Do it again for sure
        kill -9 $(pgrep -f "tted")
        sleep 5

        #--------------------------------------------
        # Get new binary
        rm tita.tar.gz
        curl -L -o tita.tar.gz "https://github.com/Titannet-dao/titan-node/releases/download/$latest_tag/titan-edge_"$latest_tag"_linux_amd64.tar.gz"

        # Extract 
        tar xvf tita.tar.gz
        if [ -d "titan-edge_"$latest_tag"_linux_amd64" ]; then
            rm -r tita
        fi
        mv titan-edge_"$latest_tag"_linux_amd64 ./tita

        # Move to bin
        mv /media/.top/tita/titan-edge /usr/bin/tted
        mv /media/.top/tita/libgoworkerd.so /usr/local/bin/
        #--------------------------------------------

        # Rerun the node
        # Get node hash
        # node_hash=$(</media/.top/nohash)
        # # Check if the variable is not empty
        # if [ -n "$node_hash" ]; then
        #     echo "Get no hash ok: $node_hash"
        # else
        #     echo "No hash file is empty or does not exist."
        # fi

        # Run the command by METHOD: screen session
        # export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/
        screen -dmS "$SC_SESSION" bash -c "$INIT_CMD"
        sleep 5
        tted daemon stop
        sleep 5
        screen -dmS "$SC_SESSION" bash -c "$RUN_CMD"

        # Run the command by METHOD: daemon nohup
        # nohup $INIT_CMD  > /tmp/.tita/edge.log 2>&1 &
        # tted_pid=$!  # Get the PID of the last background process
        # wait $tted_pid

        echo "Completely updated tita node!"
        return 0  # True, update available
    fi

}

# Function to start nodes based on the provided arguments
start_nodes() {
    for arg in "$@"; do
        case $arg in
            tita)
                if is_tita_update; then
                    echo "OK, Tita's updated!"
                else
                    if [ ! -d "/tmp/.tita" ]; then
                        mkdir /tmp/.tita
                    fi
                    if ! (pgrep -f "tted" >/dev/null); then
                        echo "Restart TT"
                        # export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/
                        screen -dmS "$SC_SESSION" bash -c "$RUN_CMD"
                        # nohup $RUN_CMD  > /tmp/.tita/edge.log 2>&1 &
                        # tted_pid=$!  # Get the PID of the last background process
                        # wait $tted_pid
                    fi
                    echo "OK, Tita's checked!"
                fi
                ;;
            *)
                echo "Unknown node: $arg"
                ;;
        esac
    done
}

# Check if any arguments were provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [node1] [node2] [...]"
    exit 1
fi

# Start nodes based on the provided arguments
start_nodes "$@"
