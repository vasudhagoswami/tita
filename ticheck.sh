#!/bin/bash

SC_SESSION="tita"
INIT_CMD="tted daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0"
RUN_CMD="tted daemon start"
#EXP_CMD="export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/bin/"

# Very important export
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/

# Install these dependencies
# sudo apt-get install snap
# sudo snap install jq

# Check latest version of tita
is_tita_update() {
    # ----------------------------
    # Automatically download the source binary
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


    # Get the currently installed version
    # export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/bin/
    version_output="$(tted --version)"
    # current_version="v$(echo "$version_output" | grep -oP 'Daemon:\s+\K[\d.]+')"
    LOCAL_VERSION="v$(echo "$version_output" | grep -oP 'titan-edge version \K[\d.]+')"

    echo "Local version: $LOCAL_VERSION"
    echo "Remote version: $VERSION"    
    # ----------------------------

    # Compare the versions
    if [ "$LOCAL_VERSION" == "$VERSION" ]; then
        # echo "The currently installed version $LOCAL_VERSION is up-to-date."
        return 1  # False, no update available
    else
        echo "A newer version $VERSION is available. Updating ..."

        # Do the basic things, go to the right folder
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
            return 1
        fi

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
