job "hishtory" {

    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"

# README
# https://github.com/linuxserver/docker-hishtory-server
# https://github.com/ddworken/hishtory/blob/master/README.md

    // constraint {
    //     attribute = "${node.unique.name}"
    //     operator  = "regexp"
    //     value     = "rpi(1|2|3)"
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

    group "hishtory" {

        count = 1

        restart {
            attempts = 0
            delay    = "30s"
        }

        network {
            port "port1" {
                to     = "8080"
            }
        }

        task "hishtory" {

            env {
                PUID               = "${meta.PUID}"
                PGID               = "${meta.PGID}"
                TZ                 = "America/New_York"
                HISHTORY_SQLITE_DB = "/config/hishtory.db"
            }

            driver = "docker"
            config {
                image              = "lscr.io/linuxserver/hishtory-server:latest"
                image_pull_timeout = "10m"
                hostname           = "${NOMAD_TASK_NAME}"
                volumes            = [
                    "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_TASK_NAME}:/config"
                ]
                ports = ["port1"]
            } // docker config

            service {
                port = "port1"
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
                    port     = "port1"
                    interval = "30s"
                    timeout  = "4s"
                }

                check_restart {
                    limit           = 0
                    grace           = "1m"
                }

            } // service

            resources {
                cpu    = 1800 # MHz
                memory = 800 # MB
            } // resources

        } // task


    } // group


} // job
