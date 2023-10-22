job "TEMPLATE" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"

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

    group "TEMPLATE-db-group" {

        count = 1

        restart {
            attempts = 0
            delay    = "30s"
        }

        network {
            port "port1" {
                static = "80"
                to     = "80"
            }
        }

        task "TEMPLATE-db" {

            // constraint {
            //     attribute = "${node.unique.name}"
            //     operator  = "regexp"
            //     value     = "rpi(1|2|3)"
            // }

            env {
                // PUID        = "${meta.PUID}"
                // PGID        = "${meta.PGID}"
                // TZ                = "America/New_York"
            }

            driver = "docker"
            config {
              image    = ""
              hostname = "${NOMAD_JOB_NAME}1"
              volumes  = [
                "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_JOB_NAME}1:/data",
                "/etc/timezone:/etc/timezone:ro",
                "/etc/localtime:/etc/localtime:ro"
              ]
              ports = ["port1"]
            } // docker config

            service  {
              port = "port1"
              name = "${NOMAD_JOB_NAME}1"
              tags = [
                  "traefik.enable=true",
                  "traefik.http.routers.${NOMAD_JOB_NAME}1.rule=Host(`${NOMAD_JOB_NAME}1.{{ homelab_domain_name }}`)",
                  "traefik.http.routers.${NOMAD_JOB_NAME}1.entryPoints=web,websecure",
                  "traefik.http.routers.${NOMAD_JOB_NAME}1.service=${NOMAD_JOB_NAME}1",
                  "traefik.http.routers.${NOMAD_JOB_NAME}1.tls=true",,
                  "traefik.http.routers.${NOMAD_JOB_NAME}1.tls.certresolver=cloudflare",
                  "traefik.http.routers.${NOMAD_JOB_NAME}1.middlewares=authelia@file"
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
                  ignore_warnings = true
              }
          } // service

          // resources {
          //   cpu    = 40 # MHz
          //   memory = 10 # MB
          //   }
          } // resources

        } // task


    } // group

    group "TEMPLATE-app-group" {

        restart {
            attempts = 1
            delay    = "30s"
        }

        network {
            port "port2" {
                static = "443"
                to     = "443"
            }
        }

        task "await-TEMPLATEEdb" {
            driver = "docker"

            config {
                image        = "busybox:latest"
                command      = "sh"
                args         = ["-c", "echo -n 'Waiting for service'; until nslookup ${NOMAD_JOB_NAME}1.service.consul 2>&1 >/dev/null; do echo '.'; sleep 2; done"]
                network_mode = "host"
            }

            resources {
                cpu    = 200
                memory = 128
            }

            lifecycle {
                hook    = "prestart"
                sidecar = false
            }
        } // /task

        task "TEMPLATE" {

            // constraint {
            //   attribute = "${node.unique.name}"
            //   operator  = "regexp"
            //   value     = "rpi(1|2|3)"
            // }

            // env {
            //    PUID        = "${meta.PUID}"
            //    PGID        = "${meta.PGID}"
            //    TZ        = "America/New_York"
            // }

            driver = "docker"
            config {
                image    = ""
                hostname = "${NOMAD_TASK_NAME}"
                volumes  = [
                  "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_TASK_NAME}:/data",
                  "/etc/timezone:/etc/timezone:ro",
                  "/etc/localtime:/etc/localtime:ro"
                ]
              ports = ["port2"]
            }

            service {
                name = "${NOMAD_TASK_NAME}"
                port = "port2"
                provider = "nomad"
                tags = [
                  "traefik.enable=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${NOMAD_TASK_NAME}.{{ homelab_domain_name }}`)",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.entryPoints=web,websecure",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.service=${NOMAD_TASK_NAME}",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",,
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=cloudflare",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=authelia@file"
                    "traefik.http.routers.${NOMAD_TASK_NAME}.priority=1"
                  ]
                check {
                    type     = "http"
                    port     = "port2"
                    path     = "/"
                    interval = "5m"
                    timeout  = "1m"
                }
                check_restart {
                    limit           = 3
                    grace           = "1m"
                }
            } // service

            // resources {
            //   cpu    = 100 # MHz
            //   memory = 300 # MB
            // }
        } // TASK
    } // close group
} // job
