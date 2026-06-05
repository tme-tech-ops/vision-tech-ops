# vision-tech-ops

Single-deployment DAP blueprint that stands up the **object_detector_web**
live multi-camera object-detection web app on a freshly-provisioned Ubuntu
24.04 VM running on a NativeEdge (DDPC) Endpoint.

Unlike the layered `object-tech-ops` / `registry-tech-ops` blueprints (which
deploy an application onto a *separately* created VM), this blueprint creates
the **VM and the application together in a single deployment** on a single
node.

## What it deploys

1. **VM half** (`vm/`) — generates an SSH keypair, uploads the Ubuntu 24.04
   cloud image (from a `binary_configuration` secret), renders cloud-init +
   netplan, and creates a `dell.nodes.nativeedge.template.NativeEdgeVM` on the
   target Endpoint. USB passthrough is wired into the VM's `ports.usb`.
2. **App half** (`app/`) — clones
   `https://github.com/Chubtoad5/object_detector_web.git` onto the VM and runs
   its containerless `deploy.sh`, which installs three systemd services
   (`od-cameras`, `od-web`, `od-caddy`) behind Caddy TLS.

## USB camera passthrough

`use_passthrough` defaults to **true**. The **USB Device list** input is a
live picker populated from the target Endpoint's real hardware inventory
(`get_inventory` against `ece_service_tag`), so you select the exact USB port
your camera is plugged into. The selection is passed through to the VM and
`ENABLE_USB=true` is handed to `deploy.sh`, which loads `uvcvideo`, adds the
service user to the `video` group, and registers `/dev/video0`.

> ⚠️ **Known limitation:** raw hypervisor USB passthrough often cannot stream
> isochronous video into a guest. If the camera enumerates but delivers no
> frames, set the **RTSP Camera URL** input instead (run the camera as an
> RTSP source on a host that sees it natively).

## Prerequisites

- Deploy **bound to the target Endpoint environment** (so `ece_service_tag`
  resolves and the inventory pickers populate).
- DAP secrets created beforehand:
  - `os_image_secret` — `binary_configuration` pointing at the Ubuntu 24.04
    cloud image.
  - `vm_password` — `password` schema (SHA-512 VM console password).
  - the Azure Vision API key secret (referenced by `azure_vision_key`).
  - the web admin password secret (referenced by `admin_password`).

## Capabilities

`web_url`, `web_http_code`, `services_running`, `admin_user`, plus VM details
(`vm_ip`, `vm_name`, `vm_ssh_private_key`, `service_tag`, ...) and
`usb_passthrough_enabled` / `usb_devices`.

## Layout

```
vision-tech-ops/
├── vision_tech_ops.yaml   # entry point: imports, input_groups, labels
├── CHANGELOG.yaml
├── vm/                    # infrastructure (BS-006)
│   ├── definitions.yaml   # plugin imports + VM node templates
│   ├── inputs.yaml
│   ├── outputs.yaml
│   ├── scripts/
│   └── templates/
└── app/                   # application (BS-006)
    ├── definitions.yaml
    ├── inputs.yaml
    ├── outputs.yaml
    └── scripts/
```
