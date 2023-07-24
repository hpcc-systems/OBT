#!/bin/bash


cat <<EOF >>/etc/security/limits.conf
* hard core unlimited
EOF


