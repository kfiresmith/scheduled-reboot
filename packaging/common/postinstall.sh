#!/bin/bash

set -Eeuo pipefail

# Both scripts execute as root and source/execute these paths without a
# trust prompt at runtime (they do verify root-ownership and no group/other
# write access before use, and will refuse to run otherwise) -- but enforce
# the correct ownership/modes here too, regardless of how this package was
# built or whether it's being reinstalled/upgraded over a tampered tree.
chown root:root \
    /usr/local/bin/scheduled-reboot \
    /usr/local/bin/post-reboot \
    /etc/default/scheduled-reboot \
    /etc/systemd/system/post-reboot.service
chmod 0755 /usr/local/bin/scheduled-reboot /usr/local/bin/post-reboot
chmod 0644 /etc/default/scheduled-reboot /etc/systemd/system/post-reboot.service

chown root:root /etc/scheduled-reboot /etc/scheduled-reboot/pre-reboot \
    /etc/scheduled-reboot/post-reboot /etc/scheduled-reboot/on-pre-reboot-failure
chmod 0755 /etc/scheduled-reboot /etc/scheduled-reboot/pre-reboot \
    /etc/scheduled-reboot/post-reboot /etc/scheduled-reboot/on-pre-reboot-failure

systemctl enable post-reboot.service
