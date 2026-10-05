# kube-prometheus-stack

## NAS Deployments

### node-exporter

```yaml
services:
    node-exporter:
        command:
            - "--path.rootfs=/host/root"
            - "--path.procfs=/host/proc"
            - "--path.sysfs=/host/sys"
            - "--path.udev.data=/host/root/run/udev/data"
            - "--web.listen-address=0.0.0.0:9100"
            - >-
                --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)
        image: quay.io/prometheus/node-exporter:v1.9.0
        network_mode: host
        ports:
            - "9100:9100"
        restart: always
        volumes:
            - /:/host/root:ro
            - /proc:/host/proc:ro
            - /sys:/host/sys:ro
```

### smartctl-exporter

No `--smartctl.device-exclude`/`--smartctl.device-include`: kernel names (`sdX`)
change between boots. The original `--smartctl.device-exclude=sdc` hid the boot
SSD, but after the 2026-09-18 reboot `sdc` was a Vault mirror disk, which then went
unmonitored. The boot SSD reads cleanly, so nothing needs excluding.

```yaml
services:
    smartctl-exporter:
        image: quay.io/prometheuscommunity/smartctl-exporter:v0.13.0
        ports:
            - "9633:9633"
        privileged: True
        restart: always
        user: root
```
