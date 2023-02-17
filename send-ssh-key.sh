# Author: Acenspades8086
# Description: This script defines a list of servers along with their associated user, IP, and port, and then copies your public SSH key to each server using ssh-copy-id. The list of servers is stored in an associative array called "servers" and the path to your private SSH key is defined by the "ssh_key" variable. The script loops through each server in the "servers" array and uses ssh-copy-id to copy your public SSH key to each server's authorized_keys file, so that you can log in to each server using your private key.
# License: MIT License

#!/bin/bash
# Define the list of servers and their associated user, IP, and port
declare -A servers=(
    ["server1"]="user1@192.168.1.100 -p 2020"
    ["server2"]="user2@192.168.1.101 -p 2222"
    ["server2"]="user2@192.168.1.101" # You don't need to specify if it uses the standard port 22.
)
# Ask for the username to use for the servers
read -p "Enter the Username to use for the servers: " username

# Define the path to the user's private SSH key
ssh_key="$HOME/.ssh/id_rsa"

# Check if the SSH key exists
if [ ! -f "$ssh_key" ]; then
    echo "SSH key file $ssh_key does not exist"
    exit 1
fi

# Start the ssh-agent and add the SSH key to it
eval "$(ssh-agent -s)"
read -s -p "Enter the passphrase for the ssh-key: " passphrase
echo
echo "$passphrase" | ssh-add -t 3600 "$ssh_key"

# Loop through each server and copy the SSH key
failed_servers=()
for server in "${!servers[@]}"; do
    user="${servers[$server]%%@*}"
    ssh_args="${servers[$server]#*@}"
    ssh_args="$username@$ssh_args"

    echo "Copying SSH key to $server..."

    # Check if the user's public key is already in the authorized_keys file on the remote server
    if ssh -o ConnectTimeout=30 -o PasswordAuthentication=no $ssh_args "grep -q $(cat $ssh_key) ~/.ssh/authorized_keys"; then
        echo "Public key already on $server"
        continue
    fi

    # Attempt to copy the user's public key to the remote server
    if ! ssh-copy-id -i "$ssh_key" -o StrictHostKeyChecking=no $ssh_args >/dev/null 2>&1; then
        # If ssh-copy-id fails, prompt for a local password and try again
        echo "$server requires local password"
        if ! ssh-copy-id -i "$ssh_key" -o StrictHostKeyChecking=no $ssh_args; then
            echo "$server failed"
            failed_servers+=("$server")
        else
            echo "$server success"
        fi
    else
        echo "$server success"
    fi
done

# Remove the SSH key from the agent
ssh-add -d "$ssh_key"

# Output the list of failed servers
if [ ${#failed_servers[@]} -gt 0 ]; then
    echo "Failed servers:"
    printf '%s\n' "${failed_servers[@]}"
fi