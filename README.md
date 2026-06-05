# vision-tech-ops

Single-deployment DAP blueprint that stands up the **object_detector_web**
live multi-camera object-detection web app on a freshly-provisioned Ubuntu
24.04 VM running on a NativeEdge (DDPC) Endpoint.

Unlike the layered `object-tech-ops` / `registry-tech-ops` blueprints (which
deploy an application onto a *separately* created VM), this blueprint creates
the **VM and the application together in a single deployment** on a single
node.

The app runs analysis through **Azure AI Vision (Computer Vision)** and is
built to stay on the **F0 free tier** ($0) — see
[Azure Computer Vision setup](#azure-computer-vision-setup).

---

## Quick Start

A five-step path from nothing to a running camera wall. Details for each step
are linked inline.

1. **Get an Azure Computer Vision key + endpoint.** Create a **Free F0**
   Computer Vision resource and copy **KEY 1** and the **Endpoint** URL. Full
   walkthrough: [Azure Computer Vision setup](#azure-computer-vision-setup).

2. **Create the four DAP secrets** in the target tenant (Portal → **Secrets**).
   The blueprint only ever takes the secret **name** as input and resolves the
   value at runtime — see [Required secrets](#required-secrets):

   | Secret (suggested name) | Schema | Holds |
   |---|---|---|
   | `vision-os-image` | `binary_configuration` | Ubuntu 24.04 cloud image URL (see below) |
   | `vision-vm-password` | `password` | VM console login password |
   | `vision-azure-key` | `password` | Azure Computer Vision **KEY 1** |
   | `vision-admin-password` | `password` | Web UI admin password |

3. **Point the image secret at the recommended Ubuntu image.** In the
   `binary_configuration` secret, set `binary_image_url` directly to the
   public Ubuntu 24.04 cloud image — no credentials needed. See
   [Recommended Ubuntu image](#recommended-ubuntu-image).

4. **Deploy the blueprint, bound to the target Endpoint environment** (so
   `ece_service_tag` resolves and the hardware pickers populate). Fill in the
   secret names from step 2, the Azure **Endpoint URL**, the network segment,
   and the datastore. If you have a USB camera plugged into the Endpoint,
   leave **Enable device passthrough** on and pick its port from the **USB
   Device list**; otherwise set an **RTSP Camera URL** instead.

5. **Open the app.** When the deployment finishes, the `web_url` capability is
   the HTTPS URL. Log in as the **Web Admin Username** (`admin` by default)
   with the password from `vision-admin-password`. The TLS cert is self-signed
   by default — accept the one-time browser warning. Add more cameras live from
   the **🎥 Cameras** button.

> Want to validate the secrets/inputs locally first?
> `bpa blueprint lint --file vision_tech_ops.yaml` then
> `bpa blueprint validate-all --file vision_tech_ops.yaml`.

---

## What it deploys

1. **VM half** (`vm/`) — generates an SSH keypair, uploads the Ubuntu 24.04
   cloud image (from the `binary_configuration` secret), renders cloud-init +
   netplan, and creates a `dell.nodes.nativeedge.template.NativeEdgeVM` on the
   target Endpoint. USB passthrough is wired into the VM's `ports.usb`.
2. **App half** (`app/`) — clones
   `https://github.com/Chubtoad5/object_detector_web.git` onto the VM and runs
   its containerless `deploy.sh`, which installs three systemd services
   (`od-cameras`, `od-web`, `od-caddy`) behind Caddy TLS, wired to Azure AI
   Vision.

---

## Required secrets

Create these in the target DAP tenant **before** deploying (Portal →
**Secrets**, or via `dapctl`). The blueprint takes only the secret **name** as
an input and resolves the value at runtime with `get_secret` — secret values
are never stored in the blueprint.

| Referencing input | Schema | Holds |
|---|---|---|
| `os_image_secret` | `binary_configuration` | Ubuntu 24.04 cloud image location (see below) |
| `vm_password` | `password` | VM console login password |
| `azure_vision_key` | `password` | Azure Computer Vision **KEY 1** |
| `admin_password` | `password` | Web UI admin (basic-auth) password |

### Recommended Ubuntu image

The blueprint expects an **Ubuntu 24.04 cloud image**. The simplest, zero-cost
option is to point the secret **directly at Canonical's public cloud image** —
it is served over HTTPS with no authentication, so you do not need to stage a
copy or supply credentials.

Create the `binary_configuration` secret (e.g. `vision-os-image`) with these
fields:

| Field | Value |
|---|---|
| `binary_image_url` | `https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img` |
| `binary_image_version` | `24.04` |
| `binary_image_access_user` | *(leave empty — public image)* |
| `binary_image_access_token` | *(leave empty — public image)* |

> The `binary_image_url` field is what the VM half reads to download the boot
> image, so it must be the **full, direct** `.img` URL. If your Endpoint has no
> outbound internet, mirror that image onto an artifact host you control and
> point `binary_image_url` at the mirror (supplying `binary_image_access_user`
> / `binary_image_access_token` if the mirror requires auth).
>
> The `releases/24.04/release/` path always serves the **latest 24.04 LTS
> point release**. Pin to a fixed daily/point build (e.g.
> `.../releases/24.04/release-20240821/...`) if you need byte-for-byte
> reproducibility.

### Other secrets

- **`vm_password`** (`password` schema) — the password for the VM console
  login (`vm_user_name`, default `edgeuser`). It is bcrypt-hashed into
  cloud-init at deploy time.
- **`azure_vision_key`** (`password` schema) — Azure Computer Vision **KEY 1**
  from the [Azure setup](#azure-computer-vision-setup) below. Paired with the
  non-secret **Azure Vision Endpoint URL** input.
- **`admin_password`** (`password` schema) — the password for the web UI's
  basic-auth login (username comes from the **Web Admin Username** input,
  default `admin`).

---

## Azure Computer Vision setup

The app runs all analysis through **Azure AI Vision** (formerly Computer
Vision): object detection with bounding boxes, captions, tags, people, and OCR.
The **F0 free tier** is free forever — it throttles (HTTP 429) instead of
billing, so it **cannot incur cost** — and the app ships a per-feature
transaction meter plus a monthly budget guard so analysis never runs up a bill.

> This mirrors the upstream app's own guidance. For the authoritative
> reference (including cost/usage notes and the per-feature transaction
> meter), see **"Azure AI Vision & the free tier"** in the
> [object_detector_web README](https://github.com/Chubtoad5/object_detector_web#azure-ai-vision--the-free-tier).

### Get your key + endpoint

1. **Sign in to the Azure portal** at <https://portal.azure.com> (create a free
   account at <https://azure.microsoft.com> if needed — a card is required for
   identity verification, but the F0 tier below does not bill).
2. **Search for "Computer Vision"** in the top search bar and open it (under
   *Azure AI services* / *Marketplace*). It may also be listed as **Azure AI
   Vision**.
3. **Click *Create*** and fill in the basics:
   - **Resource group** — new (e.g. `object-detector`) or existing.
   - **Region** — one close to your Endpoint.
   - **Name** — a unique name (this becomes part of your endpoint URL).
   - **Pricing tier** — select **Free F0** (5,000 transactions/month). If F0 is
     greyed out you already have a free Computer Vision resource on the
     subscription — only one F0 is allowed per subscription.
   - Accept the Responsible AI notice, then **Review + create → Create**.
4. **Copy the key and endpoint.** Open the resource → **Keys and Endpoint**.
   Copy **KEY 1** and the **Endpoint** URL
   (`https://<your-resource-name>.cognitiveservices.azure.com/`).

### Wire it into the deployment

- Put **KEY 1** into the `azure_vision_key` **secret** (see
  [Required secrets](#required-secrets)) — never paste it as a plain input.
- Put the **Endpoint URL** into the **Azure Vision Endpoint URL** input
  (`azure_vision_endpoint`).
- Tune the remaining Azure inputs as needed:
  - **Azure Vision API Version** (`azure_api_version`) — `v4` (modern Image
    Analysis: objects, caption, people, OCR) or `v3.2` (legacy; adds
    Brands/Color).
  - **Azure Monthly Transaction Budget** (`azure_monthly_budget`, default
    `4500`) and **Azure Budget Mode** (`azure_budget_mode`: `soft` warns,
    `hard` blocks) — the in-app guard. The F0 cap is 5,000/month.
  - **Detection feature toggles** (`feature_objects`, `feature_caption`,
    `feature_ocr`, `feature_people`), **Confidence Threshold**, and
    **Draw Bounding Boxes** set the deploy-time defaults; every one is also
    switchable live in the UI's **⚙ Settings**.

> **Each enabled feature = one Azure transaction per analyzed frame.**
> Auto-analyze is off by default; keep intervals generous and rely on the
> budget guard to stay within the free tier.

---

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
> RTSP source on a host that sees it natively — e.g. `mediamtx` + `ffmpeg`).

---

## Capabilities

`web_url`, `web_http_code`, `services_running`, `admin_user`, plus VM details
(`vm_ip`, `vm_name`, `vm_ssh_private_key`, `service_tag`, ...) and
`usb_passthrough_enabled` / `usb_devices`.

---

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
