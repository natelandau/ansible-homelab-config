## v0.2.0 (2023-02-07)

### Feat

- **services**: add fresshrss
- **jobs**: add recyclarr to keep sonarr/radarr profiles in sync
- **jobs**: diagnostics now includes whoami
- **jobs**: move changedetection to linuxserver.io docker image
- bump software versions

### Fix

- **inventory**: update python interpreter for pyenv
- **services**: bump versions
- **recyclarr**: pin to v2.x
- **ansible**: add FQDN to ansible tasks
- **authelia**: exclude ntp checks at startup
- **services**: bump versions
- **mounts**: explicitly state mounting nfs on boot
- **telegraf**: use bullseye deb repository for apt
- bump traefik version

### Refactor

- **jobs**: remove device specific constraints
