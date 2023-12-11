job "diagnostics" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"

    constraint {
        attribute = "${node.unique.name}"
        operator  = "regexp"
        value     = "macmini"
    }

    group "diagnostics" {

        count = 1

        restart {
            attempts = 0
            delay    = "30s"
        }

        network {
            port "whoami" {
                to     = 80
            }
        }

        task "diagnostics" {

            // env {
            //   KEY = "VALUE"
            // }

            driver = "docker"
            config {
                image    = "alpine:latest"
                hostname = "${NOMAD_JOB_NAME}"
                args     = [
                "/bin/sh",
                "-c",
                "chmod 755 /local/bootstrap.sh && /local/bootstrap.sh"
                ]
                volumes   = [
                    "${meta.nfsStorageRoot}/pi-cluster/tmp:/diagnostics",
                    "${meta.localStorageRoot}:/docker"
                ]
            } // docker config

            template {
                destination = "local/bootstrap.sh"
                data        = <<EOH
                #!/bin/sh

                apk update
                apk add --no-cache bash
                apk add --no-cache bind-tools
                apk add --no-cache curl
                apk add --no-cache git
                apk add --no-cache jq
                apk add --no-cache openssl
                apk add --no-cache iperf3
                apk add --no-cache nano
                apk add --no-cache wget

                tail -f /dev/null   # Keep container running
                EOH
            }

        } // task diagnostics

        // task "whoami" {
        //     driver = "docker"
        //     config {
        //       image         = "containous/whoami:latest"
        //       hostname      = "${NOMAD_TASK_NAME}"
        //       ports         = ["whoami"]

        //     } // /docker config

        //     service {
        //       port = "whoami"
        //       name = "${NOMAD_JOB_NAME}"
        //       provider = "nomad"
        //       tags = [
        //         "traefik.enable=true",
        //         "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
        //         "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
        //         "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
        //         "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
        //         "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare"
        //         ]
        //       check {
        //         type     = "http"
        //         path     = "/"
        //         interval = "90s"
        //         timeout  = "15s"
        //       }
        //       check_restart {
        //         limit           = 2
        //         grace           = "1m"
        //       }
        //     }
        //     resources {
        //         cpu    = 25 # MHz
        //         memory = 10 # MB
        //     }

        // } // /task whoami

    } // group
} // job
