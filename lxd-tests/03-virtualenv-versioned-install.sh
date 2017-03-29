#!/bin/sh -eux

write_playbook() {
    cat > "$PLAYBOOK_FILE" << EOF
- hosts: home-assistant
  roles:
      - role: home-assistant
        ha_version: 0.39.3
        ha_use_virtualenv: true
EOF
}

. lxd-tests/lib

write_playbook
run_test
