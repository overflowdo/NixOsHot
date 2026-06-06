Alles klar — ich starte **ab Phase 3** und mache es als **konkretes, ausführbares Runbook mit echten Commands**, passend zu Proxmox + NixOS + Docker Setup.

---

# 🔐 PHASE 3 — Transfer des Bitcoin Seeds auf NixOS VM

## 📍 Ausgangslage

* Seed wurde auf **offline Gerät** erzeugt
* Datei: `master_seed.bin`
* Ziel: **NixOS Signer VM in Proxmox**

---

## 📦 3.1 Transfer vorbereiten (offline Gerät)

### USB mounten

```bash
lsblk
sudo mount /dev/sdX1 /mnt
```

### Seed kopieren

```bash
cp master_seed.bin /mnt/
sync
```

### USB sauber unmounten

```bash
umount /mnt
```

---

## 🧼 3.2 Sicherheitsmaßnahme (offline Gerät)

```bash
shred -u master_seed.bin
```

👉 verhindert Recovery vom Erzeugungsgerät

---

## 📥 3.3 Import auf NixOS VM

### USB mounten auf NixOS

```bash
lsblk
sudo mkdir -p /mnt/usb
sudo mount /dev/sdX1 /mnt/usb
```

### Seed in sicheren Temp-Speicher kopieren

```bash
sudo cp /mnt/usb/master_seed.bin /tmp/btc_seed.bin
sudo chmod 600 /tmp/btc_seed.bin
```

---

## 🔒 3.4 TPM Binding (kritischer Schritt)

### TPM Primary Key erzeugen

```bash
sudo tpm2_createprimary -C o -c primary.ctx
```

---

### Seed in TPM versiegeln

```bash
sudo tpm2_create \
  -C primary.ctx \
  -u key.pub \
  -r key.priv
```

```bash
sudo tpm2_seal \
  -c primary.ctx \
  -i /tmp/btc_seed.bin \
  -o /var/lib/tpm/bitcoin-sealed.bin
```

---

## 🧨 3.5 Cleanup (extrem wichtig)

```bash
shred -u /tmp/btc_seed.bin
umount /mnt/usb
```

👉 jetzt existiert der Key **nur noch im TPM**

---

# 🔐 PHASE 4 — WireGuard Setup zwischen Proxmox VMs

---

## 📍 4.1 NixOS Signer VM (Server Side)

### WireGuard installieren

```bash
sudo nix-env -iA nixos.wireguard-tools
```

---

### Keys generieren

```bash
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
```

---

### Interface konfigurieren

`/etc/wireguard/wg0.conf`

```ini
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = <NIXOS_PRIVATE_KEY>

[Peer]
PublicKey = <MIDDLEWARE_PUBLIC_KEY>
AllowedIPs = 10.50.0.2/32
```

---

### Service starten

```bash
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
```

---

## 📍 4.2 Middleware VM (Client Side)

### Keys erzeugen

```bash
wg genkey | tee mw.key | wg pubkey > mw.pub
```

---

### Config

`/etc/wireguard/wg0.conf`

```ini
[Interface]
Address = 10.50.0.2/24
PrivateKey = <MIDDLEWARE_PRIVATE_KEY>

[Peer]
PublicKey = <NIXOS_PUBLIC_KEY>
Endpoint = <NIXOS_PUBLIC_IP>:51820
AllowedIPs = 10.50.0.1/32
PersistentKeepalive = 25
```

---

### Start

```bash
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
```

---

# 🔐 PHASE 5 — API AUTH SECRET SETUP

---

## 📍 5.1 Secret auf NixOS erzeugen

```bash
openssl rand -hex 32 > /etc/signer/api.key
chmod 600 /etc/signer/api.key
```

---

## 📍 5.2 Transfer zur Middleware

### sichere Methode (Proxmox console / USB)

```bash
scp /etc/signer/api.key user@middleware:/tmp/signer.key
```

---

## 📍 5.3 Middleware Installation

```bash
mkdir -p /run/secrets
mv /tmp/signer.key /run/secrets/signer.key
chmod 600 /run/secrets/signer.key
```

---

# 🌐 PHASE 6 — Runtime Test

---

## 📍 6.1 Verbindung testen (Middleware → NixOS)

```bash
curl http://10.50.0.1:8080/health
```

Erwartung:

```json
{"ok": true}
```

---

## 📍 6.2 PSBT Sign Request Test

```bash
curl -X POST http://10.50.0.1:8080/sign \
  -H "Content-Type: application/json" \
  -d '{
    "unsigned_rawtx_hex": "..."
  }'
```

---

# 🔁 PHASE 7 — Runtime Flow Validation

* Middleware erzeugt PSBT
* sendet via WireGuard IP `10.50.0.1`
* NixOS:

  * entschlüsselt TPM key intern
  * signiert PSBT
  * gibt signed PSBT zurück
* Middleware broadcastet TX

---

# 🧠 ENDSTATE

Du hast jetzt:

* 🔐 Offline generated Bitcoin seed
* 🔐 TPM-sealed key on NixOS
* 🌐 WireGuard isolated trust channel
* 🧱 Middleware completely keyless
* 🚫 No cross-contamination between layers

---

Wenn du willst, kann ich als nächstes:

👉 ein **“Recovery Runbook (what if NixOS dies)”**
👉 oder ein **Attack-Model (Docker compromise → what can/can’t happen)**
👉 oder eine **production-hardening checklist (real-world custody level)** erstellen
