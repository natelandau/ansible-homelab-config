job "jellyfin" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"

    constraint {
        attribute = "${node.unique.name}"
        operator  = "regexp"
        value     = "macmini"
    }

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

    group "jellyfin" {

        count = 1

        restart {
            attempts = 0
            delay    = "30s"
        }

        network {
            port "webui" {
                static = "8096"
                to     = "8096"
            }
            port "udp1" {
                static = "7359"
                to     = "7359"
            }
        }

        task "jellyfin" {

            env {
                PUID = "${meta.PUID}"
                PGID = "${meta.PGID}"
                TZ   = "America/New_York"
            }

            driver = "docker"
            config {
                image              = "lscr.io/linuxserver/jellyfin:latest"
                image_pull_timeout = "10m"
                hostname           = "${NOMAD_TASK_NAME}"
                volumes            = [
                    "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_TASK_NAME}:/config",
                    "${meta.nfsStorageRoot}/media/media/movies:/data/movies",
                    "${meta.nfsStorageRoot}/media/media/tv:/data/tv"
                ]
                ports = ["webui", "udp1"]
            } // docker config

            service {
                port = "webui"
                name = "${NOMAD_TASK_NAME}"
                provider = "nomad"
                tags = [
                    "traefik.enable=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.entryPoints=web,websecure",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.service=${NOMAD_TASK_NAME}",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=cloudflare"
                ]

                check {
                    type     = "tcp"
                    port     = "webui"
                    interval = "30s"
                    timeout  = "4s"
                }

                check_restart {
                    limit           = 0
                    grace           = "1m"
                }

            } // service

            resources {
                cpu    = 2500 # MHz
                memory = 750 # MB
            } // resources

        } // task
    } // group
} // job
