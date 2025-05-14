#!/bin/bash
echo -e 'power on\ndefault-agent\npair DD:DA:50:D0:21:8D\nconnect DD:DA:50:D0:21:8D\ntrust DD:DA:50:D0:21:8D\nagent off\nquit' | bluetoothctl
