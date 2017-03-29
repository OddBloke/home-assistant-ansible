#!/bin/sh -eux

write_playbook() {
    cat > "$PLAYBOOK_FILE" << EOF
- hosts: home-assistant
  roles:
      - home-assistant
EOF
}

. lxd-tests/lib

write_playbook
run_test
