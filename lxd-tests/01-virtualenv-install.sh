#!/bin/sh -eux

write_playbook() {
    cat > "$PLAYBOOK_FILE" << EOF
- hosts: home-assistant
  roles:
      - role: home-assistant
        ha_use_virtualenv: True
EOF
}

. lxd-tests/lib

write_playbook
run_test
