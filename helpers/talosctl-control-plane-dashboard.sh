#!/usr/bin/env bash

cd ../cluster-config
talosctl dashboard \
--nodes $MASTER_IP \
--endpoints $MASTER_IP \
--talosconfig=rendered/talosconfig
