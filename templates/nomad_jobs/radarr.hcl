job "radarr" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"

    // constraint {
    //   attribute = "${node.unique.name}"
    //   operator  = "regexp"
    //   value     = "rpi3"
    // }

    update {
        max_parallel      = 1
        health_check      = "checks"
        min_healthy_time  = "10s"
        healthy_deadline  = "5m"
        progress_deadline = "10m"
        auto_revert       = true
        canary            = 0
        stagger           = "30s"
    }

    group "radarrGroup" {

        restart {
            attempts = 0
            delay    = "10m"
        }

        network {
            port "radarr" {
                to = "7878"
            }
        }

        task "create_filesystem" {
        // Copy the most recent backup into place on the local computer.  sonarr will not work with
        // its database in an NFS share

        driver = "raw_exec"
        config {
            # When running a binary that exists on the host, the path must be absolute
            command = "${meta.restoreCommand}"
            args    = [
                "${meta.restoreCommand1}",
                "${meta.restoreCommand2}",
                "${NOMAD_JOB_NAME}",
                "${meta.restoreCommand3}"
            ]
        }

        lifecycle {
            hook    = "prestart"
            sidecar = false
        }

        } // /task create_filesystem

        task "radarr" {

            env {
                PUID = "${meta.PUID}"
                PGID = "${meta.PGID}"
                TZ   = "America/New_York"
                //DOCKER_MODS = "linuxserver/mods:universal-cron|linuxserver/mods:universal-mod2"
                //UMASK_SET = 022 #optional
            }

            driver = "docker"
            config {
                image      = "ghcr.io/linuxserver/radarr:develop"
                hostname   = "${NOMAD_JOB_NAME}"
                force_pull = true
                ports      = ["radarr"]
                volumes    = [
                "${meta.localStorageRoot}/${NOMAD_JOB_NAME}:/config",
                "${meta.nfsStorageRoot}/media:/media"
                ]
            } // docker config

            service  {
                port     = "radarr"
                name     = "${NOMAD_JOB_NAME}"
                provider = "nomad"
                tags     = [
                    "traefik.enable=true",
                    "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
                    "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
                    "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
                    "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
                    "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare"
                ]

                check {
                    type     = "tcp"
                    port     = "radarr"
                    interval = "30s"
                    timeout  = "4s"
                }

                check_restart {
                    limit           = 0
                    grace           = "1m"
                }
            } // service

            resources {
                cpu    = 2000 # MHz
                memory = 400 # MB
            } // resources

        } // /task radarr

        task "save_configuration" {
            driver = "raw_exec"
            config {
                # When running a binary that exists on the host, the path must be absolute
                command = "${meta.backupCommand}"
                args    = [
                    "${meta.backupAllocArg1}",
                    "${meta.backupAllocArg2}",
                    "${meta.backupAllocArg3}",
                    "${meta.backupAllocArg4}",
                    "${meta.backupAllocArg5}",
                    "${NOMAD_JOB_NAME}",
                    "${meta.backupAllocArg6}"
                ]
            }
            lifecycle {
                hook    = "poststop"
                sidecar = false
            }
        } // /task save_configuration

    } // group
} // job
