[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)

# Ansible Homelab Configuration

Repository for managing computers, services, and orchestration on my home LAN via Ansible. **These files are heavily customized for my unique set-up and preferences** and are published in the hopes they are helpful to someone as a reference. Do not expect them to work without heavy customization for your own use.

## Infrastructure

-   **[Protectli FW4B](https://protectli.com/vault-4-port/)** running [Opnsense](https://opnsense.org)
-   **Cisco SG250-26P** - 26 port managed POE switch
-   **Four RaspberryPi 4b** boards running Raspbian Lite
-   **Mac Mini** (2018) used for media conversion and serving, backups, and amd64 only Docker containers (why can't we have multi-arch everywhere people? Why?)
-   **Synology DS16+II** - 8TB in SHR with BTRFS

## Backups

-   Most jobs use NFS storage on the NAS for volume mounts. Jobs who require their storage to be available on a local machine are backed up to the NAS using custom shell scripts which are called as pre/post tasks in their Nomad job file. These custom scripts are written using these [shell script templates](https://github.com/natelandau/shell-scripting-templates)
-   Offsite backups are performed by [Arq Backup](https://www.arqbackup.com) which runs on the Mac Mini and performs nightly backups to B2. Backup restores are tested twice a year based on reminders in my to-do app. _This is NOT managed by this playbook._

## Service Architecture

-   [Hashicorp Consul](https://www.consul.io) provides a service mesh to allow intra-service discovery via DNS in the form of `[service_name].service.consul`.
-   [Hashicorp Nomad](https://www.nomadproject.io) provides container and service orchestration across all the RaspberryPis and the Mac Mini
-   [Traefik](https://traefik.io/traefik/) reverse proxies requests to services
-   [Authelia](https://www.authelia.com/) provides SSO
-   Traefik and Authelia are bundled in a single Nomad job named reverse_proxy.hcl

## Ansible Playbook

This playbook adds storage, services, applications, and configurations to a previously bootstrapped server. Configuring server access, users, security, basic packages, generic networking, etc. is out of scope. Once a server is bootstrapped, this playbook will:

-   **Update servers**: Packages via Homebrew (MacOS) or apt (Debian)
-   **Configure shared storage**: Adds shared NFS/SMB storage from a NAS
-   **Installs and configures specific services** which run on bare metal

    -   [Hashicorp Nomad](https://www.nomadproject.io) for service orchestration
    -   [Hashicorp Consul](https://www.consul.io) for a service mesh
    -   [Docker](https://www.docker.com) for containerization
    -   [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) for telemetry
    -   [Tdarr](https://tdarr.io) for automated video conversion
    -   Custom shell scripts for backups and house keeping

*   **Syncs Nomad and Docker Compose job files** to servers:
    -   [Authelia](https://www.authelia.com/) - Open-source full-featured authentication server
    -   [Changedetection.io](https://github.com/dgtlmoon/changedetection.io) - Website change detection monitoring and notification service
    -   [Diun](https://crazymax.dev/diun/) - Docker Image Update Notifier is a CLI application
    -   [FreshRSS](https://freshrss.org/) - A containerized RSS reader
    -   [Gitea](https://about.gitea.com/) - Slef-hodted Git service
    -   [Grafana](https://grafana.com/) - Operational dashboards
    -   [Grafana Loki](https://grafana.com/oss/loki/) - Log aggregation system
    -   [iCloud Drive Docker](https://github.com/mandarons/icloud-drive-docker) - Backup files and photos from Apple iCloud
    -   [InfluxDB](https://www.influxdata.com/) - Time series database
    -   [Lidarr](https://lidarr.audio/) - Music collection manager
    -   [Mealie](https://hay-kot.github.io/mealie/) - Recipe management
    -   [nginx](https://www.nginx.com/) - Web server
    -   [OpenVSCode Server](https://github.com/gitpod-io/openvscode-server) - Run VS Code on a remote machine
    -   [Overseerr](https://overseerr.dev/) - Media discovery and request management
    -   [Pi-Hole](https://pi-hole.net/) - Network-wide ad blocking
    -   [Plex](https://www.plex.tv/) - Media streaming
    -   [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/) - Log shipping agent
    -   [Prowlarr](https://github.com/Prowlarr/Prowlarr) - Indexer manager/proxy
    -   [Radarr](https://radarr.video/) - Movie collection manager
    -   [Readarr](https://readarr.com/) - ebook collection manager
    -   [Recyclarr](https://github.com/recyclarr/recyclarr) - Automatically sync TRaSH guides to your Sonarr and Radarr instances
    -   [sabNZBD](https://sabnzbd.org/) - Binary newsreader
    -   [Sonarr](https://sonarr.tv/) - TV collection manager
    -   [Syncthing](https://syncthing.net/) - Continuous file synchronization
    -   [Traefik](https://traefik.io/traefik/) - Reverse proxy
    -   [Uptime Kuma](https://github.com/louislam/uptime-kuma) - Monitoring tool
    -   [Whoogle](https://github.com/benbusby/whoogle-search) - Privacy-respecting metasearch engine
    -   [WikiJS](https://js.wiki/) - Powerful and extensible open source Wiki software

## Install

This repository should work on any computer with `ansible` installed.

To ensure correct versioning, I run it in a virtual environment managed by [Poetry](https://python-poetry.org/). To run it in a virtual environment follow these steps:

1. Ensure you have Python version >= 3.9 installed.
2. Install poetry `pip3 install poetry`
3. Clone this repository `git clone https://github.com/natelandau/ansible-homelab-config.git`
4. Use your terminal and enter the repository directory. On Linux/MacOS this is `cd ansible-homelab-config`
5. Type `poetry install`
6. Type `poetry shell`

Following these steps _should_ provision everything you need to get running.

## Running the playbook

1. Install the required roles: `ansible-galaxy install -r requirements.yml --force`
2. Add the vault password to `/.password_file`
3. Run the playbook: `ansible-playbook main.yml`

### Notes

-   Specify specific tags by appending `--tags [tag1],[tag2]`
-   Skip specific tags by using `--skip-tags [tag1],[tag2]`
-   To dry run use `--check --diff`

### Available Ansible Tags

The following tags are available in for this playbook

| Flag                  | Usage                                                       |
| --------------------- | ----------------------------------------------------------- |
| `backup`              | Copies backup scripts and configures cron                   |
| `clean`               | Removes nomad_jobs prior to syncing folder                  |
| `consul`              | Installs, upgrades, and provisions Consul                   |
| `docker`              | Installs Docker                                             |
| `jobs`                | Syncs orchestration job files (Nomad, Docker-Compose, etc.) |
| `logrotate`           | Configures log rotate oon the cluster leader                |
| `nomad`               | Installs, upgrades, and provisions Nomad                    |
| `packages`            | Ensure base packages are up-to-date                         |
| `prometheus_exporter` | Provisions Prometheus Node Exporter on hosts                |
| `repos`               | Runs `pull_all_repos` against `~/repos`                     |
| `sanity`              | Confirms we can connect to the target computer              |
| `storage`             | Mounts NFS storage for cluster                              |
| `tdarr`               | Installs and configures Tdarr                               |
| `telegraf`            | Installs and configures telegraf                            |
| `update`              | Shorthand for `packages`, `repos`, and `nomad jobs`         |

## Variables and Configuration

Variables are contained in two different files

-   `inventory.yml` - Server specific flags
-   `default_variables.yml` - Primary variables files

Additionally, a task named `interpolated_variables.yml` creates variables which have different values based on logical checks.

### inventory.yml

Server specific flags are managed in `inventory.yml`. All flags default to false for all hosts. To enable a flag for a specific host, add the variable and set the value to `true`. Available flags are:

```yaml
# Used to stagger cron jobs
cron_start_minute: "0"
# Run software which needs to run on a single device
is_cluster_leader: false
# Install and configure Consul
is_consul_client: false
# Run this server as a consul server
is_consul_server: false
# Install Docker compose and sync compose files
is_docker_compose_client: false
# Install and configure Nomad
is_nomad_client: false
# Run this server as a Nomad server
is_nomad_server: false
# Install Prometheus on this server
is_prometheus_node: false
# Install Telegraf on this server
is_telegraf_client: false
# Run this node as the Tdarr server
is_tdarr_server: false
# Run Tdarr client on this server
is_tdarr_node: false
# Mount NFS shared storage
is_shared_storage_client: false
# Manage apt-packages
manage_apt_packages_list: false
# Manage Homebrew (MacOS) packages
manage_homebrew_package_list: false
# If true, will always delete dir before syncing new jobs.  (run '--tags clean' )
clean_nomad_jobs: false
# Mac computer with an Arm chip
mac_arm: false
# Mac computer with an Intel chip
mac_intel: false
```

### default_variables.yml

Contains the majority of configuration variables. Specifically,

-   Version numbers - Bump a version number for a service which doesn't pull from `latest`.
-   Storage mount points
-   Service configuration variables
-   Apt and Homebrew package lists

## Additional Information

### Nomad Job Conventions

Nomad is used as the orchestration engine. The following conventions are used throughout the Nomad job files.

-   Nomad jobs are written in hcl and **contain jinja template variables**. _Important:_ These job files will not function until synced via Ansible
-   There are three types of variables within nomad jobs
    -   Jinja variables populated when Ansible syncs the jobs to disc.
    -   Nomad environment variables populated at runtime
    -   Nomad variables read from the node's Nomad configuration file
-   Templates stanzas
    -   Indented heredocs can be used using `value = <<-EOT` to analyses the lines in the sequence to find the one with the smallest number of leading spaces, and then trims that many spaces from the beginning of all of the lines.
    -   Nomad env variables or Consul key/values used in templates will reload jobs when configurations change dynamically
-   Tags in service stanzas integrate with Traefik via the Consul catalog

# Developing

-   This repository makes use of the wonderful Python [pre-commit](https://pre-commit.com/) package. To install, run `pre-commit install --install-hooks`

-   This repository uses [Commitizen](https://github.com/commitizen-tools/commitizen) to enforce conventional commits.
