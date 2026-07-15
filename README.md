# Runbook – Key A VM / Hot-Signer

***

## Ziel

Dieses Runbook beschreibt den operativen Standardprozess für die Key‑A‑VM als automatisierter Hot‑Signer innerhalb der Wallet‑Architektur und deren Installation und Integration ins Basissystem.
Key A ist Bestandteil des Hot-Kontexts und signiert Transaktionen initial, bevor diese in den Cold‑Wallet‑Prozess übergeben werden.
Die Key‑A‑VM ist vom Basissystem getrennt und verarbeitet ausschließlich PSBTs.

Der Standardmodus ist:
* Das Basissystem kommuniziert ausschließlich mit der Key‑A‑VM.
* Die Kommunikation erfolgt über WireGuard.
* Jede API-Anfrage wird zusätzlich per HMAC authentifiziert.
* Die Key‑A‑VM akzeptiert ausschließlich PSBTs.
* Das Schlüsselmaterial verlässt die VM zu keinem Zeitpunkt.
* Die Entropie für den Private Key ist im TPM versiegelt.
* Die Signierung erfolgt vollautomatisch in einem Docker‑Container.
* Bereits verarbeitete PSBTs werden über einen Deduplication Check erkannt.

## Systemhärtung – operative Auswirkungen

Die Key-A-VM ist über NixOS deklarativ gehärtet (nftables default-drop, Kernel-Härtung,
lockKernelModules, kein Auto-Mount, systemd-boot-Editor deaktiviert). Betrieblich relevant:

* **Festplattenverschlüsselung (LUKS):** Bei jedem Start wird eine Disk-Passphrase abgefragt.
* **Erreichbarkeit:** Die VM ist – anders als die Cold-Signer – nicht air-gapped, sondern
  ausschließlich über den WireGuard-Port (UDP 51820) und den Tunnel erreichbar; sämtlicher
  übriger Verkehr wird verworfen.
* **Login:** Benutzer `user` mit dem beim Setup gesetzten Passwort (kein Standardpasswort).

***

## Rollen und Systeme
### Key‑A‑VM

Die Key‑A‑VM ist der automatisierte Signer für Key A.

Aufgaben:
* Entgegennahme von PSBTs über eine HTTP API
* HMAC‑Prüfung eingehender Requests
* SHA256 Überprüfung der Integrität von übermittelten PSBTs
* Deduplication Check über gespeicherte PSBT IDs
* Entsiegelung der Entropie über TPM
* Ableitung des Privaten Keys im RAM
* Signierung über embit
* Rückgabe der signierten PSBT

Die Key‑A‑VM enthält:
* den Docker‑basierten Signer
* die TPM‑Artefakte
* das HMAC Secret
* WireGuard Konfiguration
* den internen und öffentlichen Wallet‑Descriptor
* den Xpub von Key A
* Wallet‑Metadaten
* Master Fingerprint
  
***

### Basissystem

Das Basissystem ist nicht Bestandteil der Key‑A‑VM.
Es kommuniziert ausschließlich über den definierten WireGuard‑Kanal mit Key A.

Aufgaben:
* Erstellung der PSBT
* Übergabe der PSBT an Key A
* Empfang der signierten PSBT
* Weiterverarbeitung im Hot‑Wallet‑Kontext

Regeln:
* Das Basissystem erhält keinen Zugriff auf private Schlüssel.
* Das Basissystem kommuniziert nicht direkt mit dem TPM.
* Das Basissystem tauscht im Setup nur WireGuard-, HMAC- und Wallet-Metadaten aus über ein physisches Wechsel-Medium aus.
* Im operativen Betrieb werden ausschließlich PSBTs übertragen.

***
### Docker‑Signer
Der Signierungsprozess läuft innerhalb eines Docker‑Containers.

Aufgaben:
* Bereitstellung der `/sign` API
* Prüfung des HMAC Headers
* Prüfung des SHA256 Hashes der PSBT
* Speicherung der PSBT ID zur Deduplikation
* Policy‑Prüfung
* TPM‑Unseal
* Signatur mit Key A

Der Container verwendet:
* FastAPI für die HTTP API
* embit für PSBT‑Verarbeitung und Signierung
* PostgreSQL beziehungsweise die definierte Datenbank für gesehene PSBT IDs
* TPM Tools für das Entsiegeln der Entropie

***

### TPM

Der TPM dient zur Absicherung der Entropie, aus der der Private Key rekonstruiert wird.

Aufgaben:
* Versiegelung der 32‑Byte Entropie
* Bindung der Entsiegelung an PCR 4, 8, 9, 11
* Freigabe der Entropie nur bei passendem Systemzustand

Das TPM speichert nicht die 24 Wörter.
Die 24 Wörter werden nur initial zur physischen Sicherung ausgegeben.

***

### Wechselmedium

Das Wechselmedium dient ausschließlich dem kontrollierten Setup‑Austausch zwischen Key‑A‑VM und Basissystem.

Regeln:
* Nur ein dediziertes Medium verwenden.
* Vor jedem neuen Setup‑Vorgang alte Daten entfernen.
* Das Medium nach jedem Schritt sauber aushängen.
* Operative PSBT‑Signierung erfolgt nicht über das Wechselmedium, sondern über WireGuard und API.

***

## Phase 0 – Einmaliges Setup

### Voraussetzungen

Vor dem Setup müssen folgende Voraussetzungen erfüllt sein:

* NixOS ist auf der Key‑A‑VM installiert.
* Docker ist verfügbar.
* WireGuard ist eingerichtet oder wird über die deklarative Konfiguration vorbereitet.
* Das Wechselmedium ist verfügbar.
* Das Basissystem besitzt eine eigene WireGuard Peer‑Konfiguration.
* Die Key‑A‑VM besitzt Zugriff auf einen TPM.
* Die Signer‑Dateien liegen unter `/etc/nixos/`.
* Der Docker‑Container kann über `docker compose` gebaut werden.

***

### 0.1 Initialisierung der Key‑A‑VM

Die Initialisierung der Signer‑Identität erfolgt über einen systemd One‑Shot Service vollautomatisiert.
```bash
signer-init
```

Die Manuellen Schritte können wie folgt repliziert werden:
Der Service wird beim Systemstart ausgeführt und wartet auf:
* Docker
* WireGuard
* Netzwerk
* DNS / nss-lookup

Der Service prüft zuerst, ob die Initialisierung bereits durchgeführt wurde.
```bash
/var/lib/signer/initialized
```

Wenn diese Datei existiert, wird die Initialisierung nicht erneut ausgeführt.
Ablauf:
1. Warten auf abhängige Dienste
2. Anlegen der Verzeichnisse:
```bash
/var/lib/signer
/var/lib/signer/tpm
```

3. Build des Docker‑Containers:
```bash
docker compose build
```

4. Start des Docker‑Containers:
```bash
docker compose up -d
```

5. Erzeugung des Seeds:
```bash
python3 /psbt-signer/scripts/setup/genSeed.py
```

6. Erstellung der Walletdaten:
```bash
python3 /psbt-signer/scripts/setup/genWallet.py
```

7. Kopieren der TPM‑Artefakte aus dem Container:
```bash
seal.pub
seal.priv
sealed.ctx
pcr.policy
```

8. Abschluss der Initialisierung:
```bash
touch /var/lib/signer/initialized
```

Hinweis:
Die Initialisierung ist bewusst als einmaliger Vorgang umgesetzt. Dadurch wird verhindert, dass Seed, Wallet oder TPM‑Artefakte unbeabsichtigt neu erzeugt werden.

***

### 0.2 Seed erzeugen und im TPM versiegeln

Der Seed wird innerhalb des Docker‑Containers über das Setup‑Script erzeugt.
```bash
/psbt-signer/scripts/setup/genSeed.py
```

Ablauf:
1. Es werden 32 Byte Entropie erzeugt.
2. Aus dieser Entropie wird eine BIP‑39 Mnemonic mit 24 Wörtern abgeleitet.
3. Die 24 Wörter werden zur physischen Sicherung ausgegeben.
4. Die 24 Wörter werden nicht im TPM gespeichert.
5. Die 32‑Byte Entropie wird im TPM versiegelt.

Hinweis: 
Eine 24 Wörter Mnemonic seed phrase übersteigt das maximum von 128 byte für TPM.
Auch kann es sein, das TPM nicht nativ, die Kurve des Bitcoin Algorithmus unterstützt, weshalb sich für die Speicherung der Entropie entschieden wurde

TPM‑Ablauf:
1. Erstellung eines Primary Keys
2. Start einer Trial Authorization Session
3. Erzeugung einer PCR‑Policy auf Basis von PCR 4, 8, 9, 11
4. Versiegelung der Entropie
5. Speichern der TPM‑Artefakte

Ergebnis:
```bash
/psbt-signer/tpm/seal.pub
/psbt-signer/tpm/seal.priv
/psbt-signer/tpm/sealed.ctx
/psbt-signer/tpm/pcr.policy
```

Hinweis:
Die Entsiegelung ist an den Systemzustand gebunden. Verändert sich der relevante PCR‑Zustand, kann die Entropie nicht erfolgreich entschlüsselt werden.

Empfehlung:
Der 24 Wörter mnemonic Seed phrase wird in der Doku der one-Shot Initialisierung erstellt und anschließend als Datei auf dem Desktop gespeichert.
Es wird empfohlen diese physisch zu notieren:
```bash
/Desktop/SEED_PHRASE.txt
```

Zudem sollte die Datei daraufhin durch das folgende Skript kontrolliert gelöscht werden:
```bash
/home/user/Desktop/scripts/seed_delete.sh
```

***

### 0.3 Walletdaten erzeugen

Nach der TPM‑Initialisierung wird die Wallet aus der entsiegelten Entropie erzeugt.

Script:
```bash
/psbt-signer/scripts/setup/genWallet.py
```

Ablauf:
1. Entropie wird über TPM entsiegelt.
2. Daraus wird die BIP‑39 Mnemonic rekonstruiert.
3. Daraus wird der Seed gebildet.
4. Daraus wird der HD Root Key erzeugt.
5. Der Key wird über folgende Pfade abgeleitet:
```bash
m/84h/1h/0h
m/48h/1h/0h/2h
```

6. Die Xpubs werden erzeugt.
7. Die öffentlichen Deskriptoren werden erstellt.

***

#### BIP84 Single-Signer (Hot)
Interner und Externer Descriptor‑Format:
```bash
wpkh([fingerprint/84h/1h/0h]xpub/{0,1}/*)
```

Hinweis:
Der interne und Externe Deskriptor wird benötigt um Transaktion auf und vom dem Wallet konstruieren zu können

Ergebnis:
```bash
/psbt-signer/run/wallets/descriptor.public.txt
/psbt-signer/run/wallets/xpub.txt
/psbt-signer/run/wallets/metadata.json
```

***

#### BIP48 Multisig-Cosigner (Cold)

`genWallet.py` leitet aus derselben Entropie zusätzlich den Cosigner-Schlüssel
für das 2-aus-3-Cold-Wallet ab. Verwendet wird BIP48, Script-Typ 2
(P2WSH, natives SegWit):

```bash
m/48h/1h/0h/2h
```

Key-Origin-Expression (geht 1:1 in den `wsh(sortedmulti(...))`-Descriptor
des Cold-Wallets ein):

```bash
[fingerprint/48h/1h/0h/2h]xpub/<0;1>/*
```

Zusätzliche Ergebnis-Dateien (die 84h-Dateien bleiben unverändert):

```bash
/psbt-signer/run/wallets/descriptor.multisig.txt
/psbt-signer/run/wallets/xpub.multisig.txt
/psbt-signer/run/wallets/metadata.multisig.json
```

Wichtig: Für das Cold-Multisig ist ausschließlich der **48h**-Anteil zu verwenden, nicht der 84h-Single-Sig-xpub. 
Beide stammen aus demselben Seed, gehören aber zu unterschiedlichen Ableitungspfaden. 
Ein 84h-xpub unter einem 48h-Origin-Label führt dazu, dass Key A die Cold-PSBT nicht signieren kann.

***

Die Metadata Datei enthält:
* Network
* Master Fingerprint
* Pfad zur Xpub‑Datei
* öffentlichen Descriptor

Hinweis:
Die Konfiguration ist aktuell auf Testnet (selbe Konfiguration wie Regtest) ausgelegt. 
Für den späteren Produktiven Betrieb muss dies auf mainnet umgestellt werden, wobei dies direkt in der Docker Compose für alle Skripte geändert werden kann.
```bash
NETWORK = "test"
```

***

### 0.4 HMAC Secret erzeugen

Das HMAC Secret wird durch einen eigenen systemd One‑Shot Service erzeugt.
```bash
generate-hmac-secret
```

Speicherort:
```bash
/var/lib/signer/hmac.secret
```

Ablauf:
1. Prüfen, ob bereits ein Secret existiert.
2. Falls nicht vorhanden, wird ein neues 32‑Byte Secret erzeugt.
3. Das Secret wird als Hex‑String gespeichert.
4. Die Dateirechte werden restriktiv gesetzt.
```bash
chown root:1000
chmod 0440
```

Zweck:
* Authentifizierung eingehender API‑Requests
* Integritätsprüfung der Kommunikation
* Absicherung zusätzlich zu WireGuard

***

### 0.5 WireGuard Keypair erzeugen

Das WireGuard Keypair wird beim ersten Start über einen systemd Service erzeugt.
```bash
wg-keygen
```

Ergebnis:
```bash
/var/lib/wireguard/private.key
/var/lib/wireguard/public.key
```

Konfiguration:
```bash
wg0
10.10.0.2/24
51820
```

Hinweis:
Der Private Key verbleibt auf der Key‑A‑VM. Exportiert wird ausschließlich der Public Key.

***

### 0.6 Netzwerkhärtung

Die Netzwerkkonfiguration folgt dem Prinzip `policy drop`.
Erlaubt sind:
* Loopback
* bereits etablierte Verbindungen
* Traffic über `wg0`
* UDP 51820 für WireGuard Handshake

Nicht erlaubt ist:
* sonstiger eingehender Traffic
* sonstiger ausgehender Traffic

Regeln:
```bash
iif lo accept
ct state established,related accept
iifname "wg0" accept
iifname "eth0" udp dport 51820 accept
```
```bash
oif lo accept
ct state established,related accept
oifname "wg0" accept
oifname "eth0" udp sport 51820 accept
```

Hinweis:
Die Key‑A‑VM bleibt damit technisch erreichbar, aber ausschließlich über den definierten WireGuard‑Pfad.

***

### 0.7 Export der Key‑A‑Informationen

Die für das Basissystem benötigten Informationen werden über ein dediziertes Wechselmedium exportiert.
Genutzt werden kann das vollautomatische Script, welches direkt die später benötigt Nomenklatur und Ordnerstruktur erzeugt:
```bash
wgHMAC_export.sh
```

Voraussetzungen:
* USB‑Medium ist vorhanden
* Label des Mediums ist:
```bash
USB
```

Hinweis:
Das Medium kann vollautomatisch formatiert und benannt werden über:
```bash
psbt/setup/format-USB.sh
```

* folgende Dateien existieren im Scope des Export-Scripts:
```bash
/var/lib/wireguard/public.key
/var/lib/signer/hmac.secret
/var/lib/signer/wallets/xpub.txt
/var/lib/signer/wallets/descriptor.public.txt
/var/lib/signer/wallets/metadata.json
/var/lib/signer/wallets/metadata.multisig.json
```

Ablauf:

1. USB‑Medium einstecken
2. ggf. wipen
3. Script ausführen:
```bash
sudo wgHMAC_export.sh
```

3. Das Script mountet das Medium unter:
```bash
/mnt/usb
```

4. Die benötigten Zielverzeichnisse werden erstellt:
```bash
/mnt/usb/communication
/mnt/usb/wallet/hot
/mnt/usb/wallet/cold
```

5. WireGuard Daten werden geschrieben nach:
```bash
/mnt/usb/communication/wireguard/wireguard.signer.json
```

6. HMAC Secret wird geschrieben nach:
```bash
/mnt/usb/communication/signer-hmac.secret
```

7. Walletdaten werden geschrieben nach:
```bash
/mnt/usb/wallet/hot/xpub.txt
/mnt/usb/wallet/hot/descriptor.public.txt
/mnt/usb/wallet/hot/metadata.json
/mnt/usb/wallet/cold/keyA.meta.json
```

8. Das Wechselmedium kann im Basissystem eingehangen werden, um WireGuard Peer, HMAC Secret und Wallet‑Informationen zu extrahieren.

Hinweis:
Es wird ausschließlich öffentliches Wallet‑Material exportiert. Das HMAC Secret dient nur der API‑Authentifizierung. Private Schlüsselmaterialien werden nicht exportiert.

***

### 0.8 WireGuard Peer des Basissystems importieren

Der WireGuard Peer des Basissystems wird über das Wechselmedium vollautomatisch importiert über.
```bash
wgPeer_setup.sh
```

Voraussetzung:
folgende Datei auf dem Wechsel-Medium
```bash
/mnt/usb/communication/wireguard/wireguard.wallet.json
```

Hinweis: 
Diese kann auf dem Basis-System vollautomatisch über wgPeer_export.sh mit der richtigen Nomenklatur und Orderstruktur auf dem USB exportierd werden

Ablauf:
1. USB‑Medium einstecken
2. Script ausführen:
```bash
sudo wgPeer_setup.sh
```

3. Das Script liest:
```bash
wallet_public_key
wallet_ip
```

4. Die WireGuard Konfiguration wird geschrieben nach:
```bash
/etc/wireguard/wg0.conf
```

5. Der Peer wird auf dem Interface gesetzt:
```bash
wg set wg0 peer ...
```

Ergebnis:
Die Key‑A‑VM akzeptiert danach den definierten WireGuard Peer des Basissystems.

Hinweis:
Dies kann in folgendem befehl kontrolliert werden. Siehe "latest handshake"
```bash
sudo wg show
```

Ein Rotieren dieses Schlüssel ist möglich mit
```bash
/home/user/Desktop/scripts/wg-rotate.sh
```

Dies erstellt einen neuen privaten und öffentlichen wireguard Schlüssel und baut diesen als Interface Teil in das wg0 Interface ein.
Dieser Schlüssel muss auf demselben Weg wie zurvor beschrieben im Basis-System wieder integriert werden.

***

## 1. Signierungsprozess

### 1.1 Empfang der PSBT

Die Key‑A‑VM stellt eine HTTP API bereit.
Diese wird im Basis-System durch einen die BIP21- oder PSBT-Schnittstelle oder durch einen OPA refill ausgelöst.
Endpoint:
```bash
POST /sign
```

Der Request enthält:
* PSBT als Base64
* SHA256 Hash der PSBT
* PSBT ID
  
Header:
```bash
X-Timestamp
X-Nonce
X-Signature
```

Regeln:
* Requests ohne gültige HMAC Signatur werden abgewiesen.
* Ungültige JSON Bodies werden abgewiesen.
* Requests ohne PSBT werden abgewiesen.
* PSBTs mit abweichendem SHA256 Hash werden abgewiesen.

***

### 1.2 HMAC Prüfung

Das Secret wird im Container geladen aus:

```bash
/psbt-signer/run/secrets/hmac.secret
```

Die Prüfung erfolgt vor jeder weiteren Verarbeitung.
Zweck:
* Authentizität des Senders prüfen
* Manipulation des Request Body erkennen
* Replay‑Risiken durch Timestamp und Nonce reduzieren

Wenn die Prüfung fehlschlägt, wird der Request mit `401` abgelehnt.

***

### 1.3 SHA256 Prüfung

Vor der Signierung wird der Hash der empfangenen PSBT geprüft.

Ablauf:
1. PSBT Base64 decodieren
2. SHA256 über die PSBT‑Bytes bilden
3. Vergleich mit dem gelieferten Hash

Wenn der Hash nicht übereinstimmt:
```bash
sha256 mismatch (PSBT tampering detected)
```
Die PSBT wird nicht signiert.

***

### 1.4 Deduplication Check

Vor der Signierung wird die PSBT ID gespeichert.

Regel:
* Ist die PSBT ID bereits vorhanden, wird nicht erneut signiert.

Antwort:
```bash
ALREADY_PROCESSED
```

Zweck:
* Verhindern mehrfacher Verarbeitung identischer PSBTs
* Schutz gegen Replay‑Abläufe
* klare Nachvollziehbarkeit bereits gesehener Signiervorgänge

Dazu wird die Nonce in redis für den Gültigkeitszeitraum des Timestamps persistiert und kann so ein wiederholtes Übermitteln der Nonce erkennen und abblocken.

***

### 1.5 PSBT Policy Check

Vor der Signierung wird die PSBT strukturell geprüft.
Prüfungen:
* Transaktion muss vorhanden sein
* Inputs müssen vorhanden sein
* Jeder Input benötigt `witness_utxo`
* Jeder Input benötigt BIP32 Derivations
* Outputs müssen gültige Werte größer 0 besitzen

Fehler führen zum Abbruch der Signierung.

Hinweis:
Diese Policy ersetzt keine vollständige fachliche Transaktionsprüfung durch den Gesamtprozess im Basisprozess, verhindert aber strukturell ungültige PSBTs im Signer.
Dies ist implementiert im Basis-System durch Bitcoin Core und Open Policy Agent

***

### 1.6 Entsiegelung aus dem TPM

Für jeden Signiervorgang wird die Entropie aus dem TPM entsiegelt.
Ablauf:
1. Prüfen, ob der TPM Kontext existiert:
```bash
/psbt-signer/tpm/sealed.ctx
```

2. Start einer Policy Session
3. Laden des aktuellen PCR‑4, -8, -9, -11 Zustands
4. Entsiegelung mit:
```bash
tpm2_unseal
```

5. Flush der TPM Session
6. Entfernen des Session Contexts

Regel:
Die Session wird immer bereinigt, auch wenn ein Fehler auftritt.

Hinweis:
Wenn PCR 4, 8, 9, 11 nicht dem erwarteten Zustand entspricht, schlägt der TPM Zugriff fehl.
Dies soll der Fall sein, wenn ein rebuild + switch in NixOS vorgenommen wurde, mit dem ein Angreifer das system hardening entfernen hätte können.

***

### 1.7 Signierung über embit

Nach erfolgreichem TPM‑Unseal wird die Entropie zur Erstellung des Signaturschlüssels genutzt.
Ablauf:
1. Entropie aus TPM lesen
2. Mnemonic daraus rekonstruieren
3. Seed erzeugen
4. HD Root Key erzeugen
5. PSBT validieren
6. PSBT mit Root Key signieren

Implementierung über embit:
```bash
psbt.sign_with(root)
```

Regeln:
* Schlüsselmaterial wird nur im RAM verarbeitet.
* Der Seed wird nicht persistent gespeichert.
* Der Private Key wird nicht exportiert.
* Das Schlüsselmaterial verlässt die VM nicht.
* Nach jeder Erzeugung des Elements tiefer in der Kette des Schlüsselmaterials wird die Referenz auf das höhere Element direkt aus dem RAM gelöscht.

***

### 1.8 Antwortverhalten

Es wird die signierte PSBT mit dem SHA256 Hash zurückgegeben
```bash
psbt
sha256
```

### 1.9 Weiterverarbeitung auf dem Basis-System
Diese wird anschließend von dem Basis-System basierend auf dem Wallet-Typen (Hot oder Cold) weiterverarbeitet

Hot-Wallet Transaktion werden direkt über Bitcoin Core finalisiert und schließend auf der blockchain broadcasted.

Für Cold-Wallets wird ein menschlicher Operant benachrichtigt, der den manuellen Workflows des Cold-Wallets fortsetzt.
Es folgt die Signatur durch Key B oder Key C und anschließend die Finalisierung und Broadcasting im Basis-System

***

# 2. Operative Regeln

* Key A ist Bestandteil des Hot‑Kontexts.
* Die Key‑A‑VM ist vom Basissystem getrennt.
* Das Basissystem kommuniziert als einziges System mit Key A.
* Die Kommunikation erfolgt ausschließlich über WireGuard.
* Alle API Requests müssen per HMAC authentifiziert sein.
* Es werden ausschließlich PSBTs verarbeitet.
* Das Schlüsselmaterial verlässt die VM nicht.
* Entropie wird im TPM versiegelt.
* Entsiegelung ist an PCR 4, 8, 9, 11 gebunden.
* Der Private Key wird nur im RAM rekonstruiert.
* Bereits verarbeitete PSBT IDs werden erkannt.
* Doppelte PSBTs werden nicht erneut signiert.
* Setup‑Daten werden über USB ausgetauscht.
* Private Schlüssel werden nicht über USB exportiert.
* Der Refill Workflow bleibt nach Key A nicht finalisiert.
* Der Hot‑Workflow kann direkt eine Raw Transaction zurückgeben.

***

# 3. Hilfsprogramme

Die bereitgestellten Skripte unterstützen den operativen Ablauf und die initiale Einrichtung der Key‑A‑VM.
Sie ersetzen keine Sicherheitsentscheidung, sondern automatisieren definierte Setup‑ und Betriebsaufgaben.
Alle Skripte sind auf den festgelegten Pfaden auszuführen.

***

## setup/setup.sh

Zweck:

* installiert beziehungsweise konfiguriert das NixOS‑Basissystem
* bereitet die Key‑A‑VM für den Signer‑Betrieb vor
* stellt die Grundlage für Docker, WireGuard und die weiteren Services bereit

Einsatz:
* initiales Setup der VM
* reproduzierbarer Aufbau der Systemumgebung

***

## /home/user/Desktop/scripts/mnt\_usb.sh

Zweck:
* standardisiertes Mounten des Wechselmediums
* konsistenter Mount‑Pfad
```bash
/mnt/usb
```

Einsatz:
* vor Export oder Import von Setup‑Artefakten
* beim kontrollierten Austausch mit dem Basissystem
* Teil der vollautomatischen Scripten
* Für einfache manuelle Vorgänge des Operator

***

## /home/user/Desktop/scripts/umnt\_usb.sh

Zweck:

* standardisiertes Aushängen des Wechselmediums
* Synchronisieren + sicheres Entfernen

***

## /home/user/Desktop/scripts/format-usb.sh &lt;gerät&gt;

Zweck:

* vollständige Bereinigung des Mediums
* Entfernen alter PSBTs und Artefakte
* vergibt das Volume-Label `USB`

Einsatz:

* Zielgerät explizit angeben (z. B. `/dev/disk/by-id/...`), mit Sicherheitsabfrage
* vor Beginn eines neuen Prozesses
* bei Unsicherheiten über den Zustand des Mediums

***

## /home/user/Desktop/scripts/wgHMAC\_export.sh

Zweck:
* Export der Key‑A‑Kommunikationsdaten
* Export des HMAC Secrets
* Export der öffentlichen Walletinformationen

Exportiert:
```bash
/communication/wireguard/wireguard.signer.json
/communication/signer-hmac.secret
/wallet/hot/xpub.txt
/wallet/hot/descriptor.public.txt
/wallet/hot/metadata.json
/wallet/cold/keyA.meta.json
```

Einsatz:
* initialer Austausch mit dem Basissystem
* Einrichtung des Basissystems für die Kommunikation mit Key A
* Übergabe des öffentlichen Key‑A‑Anteils für Wallet‑Konfigurationen

Hinweis:
Es werden keine privaten Schlüssel exportiert.

***

## /home/user/Desktop/scripts/wgPeer\_setup.sh

Zweck:

* Import des WireGuard Peers des Basissystems
* Erstellung beziehungsweise Aktualisierung der WireGuard Konfiguration
* Aktivierung des Peer‑Eintrags auf `wg0`

Liest:
```bash
/communication/wireguard/wireguard.wallet.json
```

Schreibt:
```bash
/etc/wireguard/wg0.conf
```

Einsatz:
* nach Export der Basissystem‑Peer‑Daten
* bei Neuaufbau der Peer‑Beziehung
* bei Wechsel des Basissystems

***

## /home/user/Desktop/scripts/wg-rotate.sh

Zweck:

* Rotation des WireGuard-Keypairs der Key-A-VM (Interface `wg0`)
* Erzeugung eines neuen Private- und Public-Keys
* Live-Anwendung des neuen Private-Keys auf `wg0`, ohne bestehende Peers zu verwerfen
* Sicherung der alten Keys und Konfiguration

Schreibt:
```bash
/var/lib/wireguard/private.key
/var/lib/wireguard/public.key
/etc/wireguard/wg0.conf            # PrivateKey-Zeile, falls Datei vorhanden
/var/lib/wireguard/backup/         # timestamped Sicherung der alten Keys/Config
```

***

## /home/user/Desktop/scripts/seed\_delete.sh

Zweck:

* Import des WireGuard Peers des Basissystems
* Erstellung beziehungsweise Aktualisierung der WireGuard Konfiguration
* Aktivierung des Peer‑Eintrags auf `wg0`

Liest:
```bash
/communication/wireguard/wireguard.wallet.json
```

Schreibt:
```bash
/etc/wireguard/wg0.conf
```

Einsatz:
* nach Export der Basissystem‑Peer‑Daten
* bei Neuaufbau der Peer‑Beziehung
* bei Wechsel des Basissystems

***

## systemd-Services: signer-init

Zweck:
* Initialisierung der Signer‑Identität
* Build und Start des Docker‑Containers
* Erzeugung von Seed und Wallet
* Kopieren der TPM‑Artefakte
* Markieren des Systems als initialisiert

Schreibt:
```bash
/var/lib/signer/initialized
```

Einsatz:
* automatisch beim ersten Systemstart
* nicht manuell erneut ausführen, wenn das System bereits initialisiert ist

***

## systemd-Services: generate-hmac-secret

Zweck:
* Erzeugung des HMAC Secrets
* restriktive Speicherung für den Signer

Schreibt:
```bash
/var/lib/signer/hmac.secret
```

Einsatz:
* automatisch beim Setup
* Grundlage für die Authentifizierung der API‑Requests

***

## systemd-Services: wg-keygen
Zweck:
* Erzeugung des WireGuard Keypairs
* Bereitstellung der Schlüssel für `wg0`

Schreibt:
```bash
/var/lib/wireguard/private.key
/var/lib/wireguard/public.key
```

Einsatz:
* automatisch vor Start von WireGuard
* Grundlage für den Peer‑Austausch mit dem Basissystem

***

# 4. Sicherheitsmodell

### 4.1 Kommunikationssicherheit
Die Kommunikation zwischen Basissystem und Key‑A‑VM ist zweistufig abgesichert.

Schicht 1:
* WireGuard Tunnel
* definierte Peers
* eingeschränkte Ports

Schicht 2:
* HMAC Signatur
* Timestamp
* Nonce
* SHA256 Prüfung der PSBT

Dadurch wird verhindert, dass beliebige Systeme Signieranfragen an Key A senden können.

***

### 4.2 Schlüsselmaterial

Das Schlüsselmaterial wird nicht dauerhaft als Private Key gespeichert.

Speicherprinzip:
* TPM speichert versiegelte Entropie
* Mnemonic wird nur temporär rekonstruiert
* Seed wird nur temporär rekonstruiert
* Private Key wird nur im RAM gebildet
* keine Persistenz auf Disk

***

### 4.3 TPM Bindung

Die Entsiegelung nutzt PCR 4, 8, 9, 11.
Dadurch ist die Entsiegelung an den erwarteten Systemzustand gebunden.
Wenn sich der relevante Boot‑ oder Policy‑Zustand ändert, schlägt die Entsiegelung fehl.
Dadurch sollen manipulationen des System erkannt und vor Extraktion des Schlüsselmaterials geschützt werden

***

### 4.4 PSBT‑Policy
Die Policy prüft die Mindeststruktur der PSBT.

Geprüft wird:
* vorhandene Transaktion
* vorhandene Inputs
* Witness UTXO je Input
* BIP32 Derivation je Input
* gültige Output‑Werte

Ungültige PSBTs werden nicht signiert.

***

### 4.5 Deduplication

Jede PSBT ID wird gespeichert.
Bereits bekannte PSBT IDs führen zu:
```bash
ALREADY_PROCESSED
```

Dadurch wird verhindert, dass dieselbe PSBT mehrfach verarbeitet wird.

***

# 5. Ergebnis

Nach erfolgreichem Setup stellt die Key‑A‑VM einen isolierten und automatisierten Signer bereit.
Damit bildet die Key‑A‑VM den automatisierten Signaturpunkt des Hot‑Kontexts, ohne das private Schlüsselmaterial an das Basissystem zu übergeben.



***
