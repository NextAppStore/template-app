# AGENTS.md — Click-n-Deploy App Template

Operating manual for autonomous coding agents and instructors developing a new app for
the AppStore. Goal: a working, registrable app repository — without follow-up questions.

**Read section 6 first (Decision Authority).** It explains what you decide on your own
and when to stop and ask.

---

## 1. What an app is

An app is a **Git repository** containing:

```
my-app/
├── terraform/          ← Required
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── packer/             ← Optional (custom VM image)
    ├── template.pkr.hcl
    ├── variables.pkr.hcl
    └── scripts/
        └── provision.sh
```

The platform clones the repo at a **Git tag** for every deploy, optionally builds the
Packer image, and runs `terraform apply` against OpenStack. Whatever is declared in
`outputs.tf` appears in the AppStore UI and is emailed to end users.

**Full specification:** `README.md` in this repo. If `AGENTS.md` and `README.md`
disagree, `README.md` wins.

---

## 2. Starter kit

This repo **is** the template. Don't start from scratch:

```bash
# Option A — GitHub Template (recommended)
# → "Use this template" → "Create a new repository"

# Option B — clone manually
git clone <this-repo-url> my-app
cd my-app
rm -rf .git && git init
```

Then just adapt it — don't rewrite it.

---

## 3. Mandatory contract with the platform

These things are non-negotiable — the platform aborts the deploy otherwise.

### 3.1 Required variables in `variables.tf`

```hcl
# Always declare — worker injects teams + users
variable "users" {
  description = "Per-team roster — injected by the worker. @platform:internal"
  type = map(list(object({ email = string })))
  default = {}
}

# Only if packer/ exists — worker sets the image name
variable "image_name" {
  description = "Glance image name — set by the worker at apply time. @platform:internal"
  type        = string
}

# For multi-Packer images (packer/<key>/) — one entry per subdirectory
variable "image_name_<key>" {
  description = "Glance image name of the <key> image — @platform:internal"
  type        = string
}
```

### 3.2 Required outputs in `outputs.tf`

All three must be declared — even if empty:

```hcl
output "user_accounts" { sensitive = true; value = {} }
output "team_vms"      { value = {} }
output "teams_summary" { value = {} }
```

The `user_accounts` key must have the form `<team>-<username>`.
`team_vms` needs `url` (web app) or `ssh_command` (SSH) for clickable links in the UI.

### 3.3 Provider

```hcl
provider "openstack" { cloud = "openstack" }
```

The profile name `openstack` in `clouds.yaml` is fixed — the platform sets it this way.

---

## 4. Controlling wizard variables

The `@openstack` marker in a variable's `description` determines which UI element the
AppStore wizard renders. Without a marker: a free-text field.

```
@openstack:<type>[:<mode>][:<multi>][:<var_scope>]
```

| `type`           | Wizard element          |
|------------------|-------------------------|
| `network`        | Network picker          |
| `flavor`         | Flavor picker           |
| `security_group` | Security group picker   |
| `floating_ip_pool` | External network picker |
| `image`          | Glance image picker     |
| `keypair`        | Keypair picker          |
| `file`           | File upload             |

| `mode`   | Meaning              |
|----------|----------------------|
| `id`     | Return UUID          |
| `name`   | Return name (default) |

| `var_scope` | Meaning                                 | Required HCL type |
|-------------|------------------------------------------|--------------------|
| `all`       | One value for all teams (default)       | any                |
| `team`      | One value per team                      | `map(...)`         |
| `user`      | One value per user                      | `map(...)`         |

**`@platform:internal`** — hide the variable from the wizard (for values injected by the worker).

Examples:

```hcl
variable "network_uuid" {
  description = "Primary network @openstack:network:id"
  type        = string
}

variable "flavor_name" {
  description = "VM size @openstack:flavor:name"
  type        = string
  default     = "gp1.small"
}

variable "team_flavor" {
  description = "@openstack:flavor:id:single:team Flavor per team"
  type        = map(string)
  default     = {}
}

variable "assignment_files" {
  description = "@openstack:file:all:pdf|docx Assignment sheet"
  type = map(object({
    name = string; content_b64 = string; content_type = string; size = number
  }))
  default = {}
}
```

**File variables** must never be referenced in `count` or `for_each` — on destroy they
are empty and Terraform would incorrectly delete resources.

---

## 5. Local development and checks

### Prerequisites

```bash
brew install terraform packer tflint tfsec   # macOS
winget install Hashicorp.Terraform Hashicorp.Packer  # Windows
```

`clouds.yaml` under `~/.config/openstack/clouds.yaml` — the profile name must be `openstack`.

### Cycle

```bash
# Terraform
cd terraform
terraform fmt && terraform validate && terraform plan

# Packer (only if packer/ exists)
cd packer
packer fmt . && packer validate .
```

### CI (runs automatically on push when the template is used)

| Workflow | What is checked |
|---|---|
| `terraform.yml` | `fmt`, `validate`, `tflint`, `tfsec` |
| `packer.yml` | `fmt`, `validate` |

---

## 6. Decision authority

### Decide on your own

- Resource structure in `main.tf` (how many VMs, which networks)
- Provisioning scripts in `packer/scripts/`
- Which wizard variables are offered and with what marker
- `user-data.yaml.tpl` and cloud-init contents
- `locals` and internal helper variables
- Comments and README content

### Stop and ask

1. **`@openstack` marker type missing on the frontend** — new resource types must be
   added simultaneously in the frontend repo and backend repo (four-eyes rule). This is
   the platform team's responsibility, not the app developer's.
2. **Required outputs or required variables are meant to be omitted** — this breaks the
   platform; check with the platform team first.
3. **`clouds.yaml` or OpenStack credentials** are meant to be committed — never do this,
   clarify the situation first.

---

## 7. Registering an app

```bash
# 1. Create a Git tag (semver, e.g. v1.0.0)
git tag v1.0.0 && git push origin v1.0.0

# 2. For a private repo: add a collaborator
# GitHub → Settings → Collaborators → "six7clickndeploy"

# 3. Register in the AppStore
# AppStore → "Add app" → enter the GitHub URL
```

The release description must include: user management, VM structure,
configurable variables, changes in this version.

---

## 8. Common errors

| Error | Cause |
|---|---|
| `PackerTemplateDiscoveryError` | Subdirectory key contains uppercase letters or special characters |
| `MARKER_SCOPED_REQUIRES_MAP` | `var_scope: team/user` but the HCL type is not `map(...)` |
| Wizard shows `image_name` | `@platform:internal` missing from the description |
| Destroy incorrectly deletes resources | File variable referenced in `for_each` |
| `clouds.yaml` profile not found | Profile name is not `openstack` |
| Multi-image build fails | `packer/template.pkr.hcl` and `packer/<key>/` present at the same time |
