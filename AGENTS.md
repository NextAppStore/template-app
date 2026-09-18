# AGENTS.md — Click-n-Deploy App-Template

Betriebsanleitung für autonome Coding-Agents und Dozierende, die eine neue App für den
AppStore entwickeln. Ziel: Ein funktionierendes, registrierbares App-Repository — ohne
Zwischenfragen.

**Lies zuerst Abschnitt 6 (Entscheidungsbefugnis).** Dort steht, was du allein entscheidest
und wann du anhältst.

---

## 1. Was eine App ist

Eine App ist ein **Git-Repository** mit:

```
my-app/
├── terraform/          ← Pflicht
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── packer/             ← Optional (eigenes VM-Image)
    ├── template.pkr.hcl
    ├── variables.pkr.hcl
    └── scripts/
        └── provision.sh
```

Die Plattform klont das Repo bei jedem Deploy auf einen **Git-Tag**, baut ggf. das
Packer-Image, und führt `terraform apply` gegen OpenStack aus. Was in `outputs.tf`
steht, erscheint im AppStore-UI und wird per Mail an die Endnutzer geschickt.

**Vollständige Spezifikation:** `README.md` in diesem Repo. Bei Widerspruch zwischen
`AGENTS.md` und `README.md` gewinnt die `README.md`.

---

## 2. Starterkit

Dieses Repo **ist** das Template. Nicht von null anfangen:

```bash
# Option A — GitHub Template (empfohlen)
# → "Use this template" → "Create a new repository"

# Option B — manuell klonen
git clone <diese-repo-url> my-app
cd my-app
rm -rf .git && git init
```

Danach nur anpassen, nicht neu schreiben.

---

## 3. Pflichtvertrag mit der Plattform

Diese Dinge sind nicht verhandelbar — die Plattform bricht sonst beim Deploy ab.

### 3.1 Pflicht-Variablen in `variables.tf`

```hcl
# Immer deklarieren — Worker injiziert Teams + User
variable "users" {
  description = "Per-team roster — vom Worker injiziert. @platform:internal"
  type = map(list(object({ email = string })))
  default = {}
}

# Nur wenn packer/ existiert — Worker setzt den Image-Namen
variable "image_name" {
  description = "Glance-Image-Name — vom Worker zur Apply-Zeit gesetzt. @platform:internal"
  type        = string
}

# Bei Multi-Packer-Images (packer/<key>/) — je ein Eintrag pro Subdirectory
variable "image_name_<key>" {
  description = "Glance-Image-Name des <key>-Images — @platform:internal"
  type        = string
}
```

### 3.2 Pflicht-Outputs in `outputs.tf`

Alle drei müssen deklariert sein — auch wenn sie leer sind:

```hcl
output "user_accounts" { sensitive = true; value = {} }
output "team_vms"      { value = {} }
output "teams_summary" { value = {} }
```

`user_accounts`-Key muss die Form `<team>-<username>` haben.
`team_vms` braucht `url` (Webanwendung) oder `ssh_command` (SSH) für klickbare Links im UI.

### 3.3 Provider

```hcl
provider "openstack" { cloud = "openstack" }
```

Der Profilname `openstack` in `clouds.yaml` ist fix — die Plattform setzt ihn so.

---

## 4. Wizard-Variablen steuern

Mit dem `@openstack`-Marker in der `description` einer Variable bestimmst du, welches
UI-Element der AppStore-Wizard rendert. Ohne Marker: freies Textfeld.

```
@openstack:<type>[:<mode>][:<multi>][:<var_scope>]
```

| `type`           | Wizard-Element          |
|------------------|-------------------------|
| `network`        | Netzwerk-Picker         |
| `flavor`         | Flavor-Picker           |
| `security_group` | Security-Group-Picker   |
| `floating_ip_pool` | Ext. Netzwerk-Picker  |
| `image`          | Glance-Image-Picker     |
| `keypair`        | Keypair-Picker          |
| `file`           | Datei-Upload            |

| `mode`   | Bedeutung           |
|----------|---------------------|
| `id`     | UUID zurückgeben    |
| `name`   | Name zurückgeben (Default) |

| `var_scope` | Bedeutung                              | Pflicht-HCL-Typ |
|-------------|----------------------------------------|-----------------|
| `all`       | Ein Wert für alle Teams (Default)      | beliebig        |
| `team`      | Einen Wert pro Team                    | `map(...)`      |
| `user`      | Einen Wert pro User                    | `map(...)`      |

**`@platform:internal`** — Variable aus dem Wizard ausblenden (für vom Worker injizierte Werte).

Beispiele:

```hcl
variable "network_uuid" {
  description = "Hauptnetzwerk @openstack:network:id"
  type        = string
}

variable "flavor_name" {
  description = "VM-Größe @openstack:flavor:name"
  type        = string
  default     = "gp1.small"
}

variable "team_flavor" {
  description = "@openstack:flavor:id:single:team Flavor pro Team"
  type        = map(string)
  default     = {}
}

variable "assignment_files" {
  description = "@openstack:file:all:pdf|docx Aufgabenstellung"
  type = map(object({
    name = string; content_b64 = string; content_type = string; size = number
  }))
  default = {}
}
```

**File-Variablen** dürfen nie in `count` oder `for_each` referenziert werden — beim
Destroy sind sie leer und Terraform würde Ressourcen fälschlich löschen.

---

## 5. Lokale Entwicklung und Checks

### Voraussetzungen

```bash
brew install terraform packer tflint tfsec   # macOS
winget install Hashicorp.Terraform Hashicorp.Packer  # Windows
```

`clouds.yaml` unter `~/.config/openstack/clouds.yaml` — Profilname muss `openstack` heißen.

### Zyklus

```bash
# Terraform
cd terraform
terraform fmt && terraform validate && terraform plan

# Packer (nur wenn packer/ existiert)
cd packer
packer fmt . && packer validate .
```

### CI (automatisch bei Push wenn Template genutzt)

| Workflow | Was wird geprüft |
|---|---|
| `terraform.yml` | `fmt`, `validate`, `tflint`, `tfsec` |
| `packer.yml` | `fmt`, `validate` |

---

## 6. Entscheidungsbefugnis

### Entscheide allein

- Ressourcen-Struktur in `main.tf` (wie viele VMs, welche Netzwerke)
- Provisioning-Skripte in `packer/scripts/`
- Welche Wizard-Variablen angeboten werden und mit welchem Marker
- `user-data.yaml.tpl` und cloud-init-Inhalte
- `locals` und interne Hilfsvariablen
- Kommentare und README-Inhalt

### Halte an und frag

1. **`@openstack`-Marker-Typ fehlt im Frontend** — neue Ressourcentypen müssen im
   Frontend-Repo und Backend-Repo gleichzeitig ergänzt werden (Vier-Stellen-Regel).
   Das ist Aufgabe des Plattform-Teams, nicht des App-Entwicklers.
2. **Pflicht-Outputs oder Pflicht-Variablen sollen weggelassen werden** — das bricht die
   Plattform; erst mit dem Plattform-Team absprechen.
3. **`clouds.yaml` oder OpenStack-Credentials** sollen committet werden — niemals tun,
   erst Situation klären.

---

## 7. App registrieren

```bash
# 1. Git-Tag erstellen (Semver, z.B. v1.0.0)
git tag v1.0.0 && git push origin v1.0.0

# 2. Bei privatem Repo: Collaborator hinzufügen
# GitHub → Settings → Collaborators → "six7clickndeploy"

# 3. Im AppStore registrieren
# AppStore → "App hinzufügen" → GitHub-URL eintragen
```

Release-Beschreibung muss enthalten: User-Management, VM-Struktur,
konfigurierbare Variablen, Änderungen in dieser Version.

---

## 8. Häufige Fehler

| Fehler | Ursache |
|---|---|
| `PackerTemplateDiscoveryError` | Subdirectory-Key enthält Großbuchstaben oder Sonderzeichen |
| `MARKER_SCOPED_REQUIRES_MAP` | `var_scope: team/user` aber HCL-Typ ist kein `map(...)` |
| Wizard zeigt `image_name` an | `@platform:internal` in der Description fehlt |
| Destroy löscht Ressourcen fälschlich | File-Variable in `for_each` referenziert |
| `clouds.yaml`-Profil nicht gefunden | Profilname ist nicht `openstack` |
| Multi-Image baut nicht | `packer/template.pkr.hcl` und `packer/<key>/` gleichzeitig vorhanden |
