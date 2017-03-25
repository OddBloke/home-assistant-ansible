#!/bin/sh -eux

SSH_KEY="$1"
DISTRO="$2"

CONTAINER_REMOTE=local
CONTAINER_NAME="ha-ansible-test-$(date "+%Y%m%d-%H%M")-$(mktemp -u XXXX)"
INVENTORY_FILE="$(mktemp)"
PLAYBOOK_FILE="$(mktemp -u XXXX)"

prepare_container_for_ansible() {
    echo "Distro should override this."
    exit 1
}

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. "$SCRIPTPATH/$DISTRO"

launch_container() {
    lxc launch "$IMAGE_NAME" "$CONTAINER_REMOTE":"$CONTAINER_NAME"
    #trap 'lxc delete --force $CONTAINER_REMOTE:$CONTAINER_NAME' EXIT
}

configure_container_access() {
    # Use SSH key for private repo access
    lxc exec "$CONTAINER_REMOTE":"$CONTAINER_NAME" -- mkdir -p /root/.ssh
    lxc file push "$SSH_KEY" "$CONTAINER_REMOTE":"$CONTAINER_NAME"/root/.ssh/authorized_keys
    lxc exec "$CONTAINER_REMOTE":"$CONTAINER_NAME" chmod 700 /root/.ssh
    lxc exec "$CONTAINER_REMOTE":"$CONTAINER_NAME" chmod 600 /root/.ssh/authorized_keys
    lxc exec "$CONTAINER_REMOTE":"$CONTAINER_NAME" chown root:root /root/.ssh/authorized_keys
}

wait_for_network() {
    start_time="$(date +%s)"
    cut_off_time="$((start_time + 60))"  # Wait for a minute
    while ! lxc exec "$CONTAINER_REMOTE":"$CONTAINER_NAME" -- $(network_test) > /dev/null 2>&1; do
        if [ "$(date +%s)" -gt $cut_off_time ]; then
            echo "Networking didn't appear within a minute of container launch"
            exit 1
        fi
        sleep 5
    done
}

write_inventory() {
    IP_ADDRESS="$(lxc info "$CONTAINER_REMOTE":"$CONTAINER_NAME" | grep eth0 | grep "inet[^6]" | cut -f 3)"
    cat > "$INVENTORY_FILE" << EOF
[home-assistant]
$IP_ADDRESS   ansible_user=root
EOF
}

write_playbook() {
    cat > "$PLAYBOOK_FILE" << EOF
- hosts: home-assistant
  roles:
      - home-assistant
EOF
}

run_ansible() {
    ansible-playbook --ssh-common-args "-o StrictHostKeyChecking=no" -i "$INVENTORY_FILE" "$PLAYBOOK_FILE"
}

wait_for_ha() {
    start_time="$(date +%s)"
    cut_off_time="$((start_time + 60))"  # Wait for a minute
    while ! curl "http://$IP_ADDRESS:8123" | grep "<title>Home Assistant</title>" > /dev/null 2>&1; do
        if [ "$(date +%s)" -gt $cut_off_time ]; then
            echo "HA didn't come up within a minute of container launch"
            exit 1
        fi
        sleep 5
    done
}

launch_container
configure_container_access
wait_for_network
prepare_container_for_ansible
write_inventory
write_playbook
run_ansible
wait_for_ha
