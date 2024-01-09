job "gitea" {
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

    constraint {
        distinct_hosts = true
    }

    group "gitea" {

        // constraint {
        //     attribute = "${node.unique.name}"
        //     operator  = "regexp"
        //     value     = "rpi"
        // }

        count = 1

        restart {
            attempts = 0
            delay    = "30s"
        }

        network {
            port "webui" {
                to     = "3000"
            }
            port "ssh" {
                to      = "22"
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


        task "gitea" {

            env {
                GITEA__mailer__ENABLED           = true
                GITEA__mailer__FROM              = "gitea@{{ homelab_domain_name }}"
                GITEA__mailer__PASSWD            = "{{ gitea_smtp_password }}"
                GITEA__mailer__PROTOCOL          = "smtp+starttls"
                GITEA__mailer__SMTP_ADDR         = "{{ email_smtp_host }}"
                GITEA__mailer__SMTP_PORT         = "{{ email_smtp_port_starttls }}"
                GITEA__mailer__SUBJECT_PREFIX    = "[Gitea]"
                GITEA__mailer__USER              = "{{ email_smtp_account }}"
                GITEA__repository__DEFAULT_REPO_UNITS = "repo.code,repo.releases,repo.issues,repo.pulls,repo.wiki,repo.projects,repo.packages" # add `repo.actions` to the list if enabling actions
                GITEA__server__DOMAIN            = "{{ homelab_domain_name }}"
                GITEA__server__ROOT_URL          = "https://${NOMAD_JOB_NAME}.{{ homelab_domain_name }}"
                GITEA__server__SSH_DOMAIN        = "${NOMAD_JOB_NAME}.{{ homelab_domain_name }}"
                GITEA__server__SSH_PORT          = "2222" # Traefik gitea-ssh entrypoint
                GITEA__server__START_SSH_SERVER  = false
                GITEA__service__ENABLE_NOTIFY_MAIL = true
                GITEA__time__DEFAULT_UI_LOCATION = "America/New_York"
                TZ                               = "America/New_York"
                USER_GID                         = "${meta.PGID}"
                USER_UID                         = "${meta.PUID}"
            }

            driver = "docker"
            config {
                image              = "gitea/gitea:{{ gitea_version }}"
                image_pull_timeout = "10m"
                hostname           = "${NOMAD_TASK_NAME}"
                volumes            = [
                    "${meta.localStorageRoot}/${NOMAD_JOB_NAME}:/data",
                    "/etc/timezone:/etc/timezone:ro",
                    "/etc/localtime:/etc/localtime:ro"
                ]
                ports = ["webui", "ssh"]
            } // docker config

            service {
                port = "webui"
                name = "${NOMAD_JOB_NAME}"
                provider = "nomad"
                tags = [
                    "traefik.enable=true",
                    "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
                    "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
                    "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
                    "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
                    "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare"
                    ]

                check {
                    type     = "tcp"
                    port     = "webui"
                    interval = "30s"
                    timeout  = "4s"
                }

                check_restart {
                    limit = 0
                    grace = "1m"
                }

            } // service

            service {
                port     = "ssh"
                name     = "gitea-ssh-svc"
                provider = "nomad"
                tags     = [
                    "traefik.enable=true",
                    "traefik.tcp.routers.gitea-ssh.rule=HostSNI(`*`)",
                    "traefik.tcp.routers.gitea-ssh.entrypoints=gitea-ssh",
                    "traefik.tcp.routers.gitea-ssh.service=gitea-ssh-svc"
                    ]
            } // service

            // resources {
            //     cpu    = 100 # MHz
            //     memory = 300 # MB
            // } // resources

        } // task gitea

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


    // group "action-runners" {

    //     constraint {
    //         attribute = "${node.unique.name}"
    //         operator  = "regexp"
    //         value     = "macmini"
    //     }

    //     constraint {
    //         distinct_hosts = true
    //     }

    //     count = 1

    //     restart {
    //         attempts = 0
    //         delay    = "30s"
    //     }

    //     network {
    //         port "cache" {
    //             to     = "8088"
    //         }
    //     }

    //     task "await-gitea" {

    //         lifecycle {
    //             hook = "prestart"
    //             sidecar = false
    //         }

    //         driver = "docker"

    //         config {
    //             image   = "busybox:latest"
    //             command = "/bin/sh"
    //             args     = [
    //                 "-c",
    //                 "chmod 755 /local/ping.sh && /local/ping.sh"
    //             ]
    //             network_mode = "host"
    //         }

    //         template {
    //             destination = "local/ping.sh"
    //             change_mode = "restart"
    //             data        = <<-EOH
    //             #!/bin/sh
    //             {% raw -%}
    //             {{ range nomadService "gitea" }}
    //             IP="{{ .Address }}"
    //             PORT="{{ .Port }}"
    //             {{ end }}
    //             {% endraw -%}

    //             until [ -n "${IP}" ] && [ -n "${PORT}" ]; do
    //                 echo "Waiting for Nomad to populate the service information..."
    //                 sleep 1
    //             done

    //             echo "Waiting for Gitea to start..."

    //             until nc -z "${IP}" "${PORT}"; do
    //                 echo "'nc -z ${IP} ${PORT}' is unavailable..."
    //                 sleep 1
    //             done

    //             echo "Gitea is up! Found at ${IP}:${PORT}"

    //             EOH
    //         }

    //     }

    //     task "gitea-action-runner" {

    //         env {
    //             CONFIG_FILE                     = "/local/config.yml"
    //             GITEA_INSTANCE_URL              = "https://${NOMAD_JOB_NAME}.{{ homelab_domain_name }}"
    //             GITEA_RUNNER_NAME               = "${node.unique.name}-action-runner"
    //             GITEA_RUNNER_REGISTRATION_TOKEN = "{{ gitea_runner_registration_token }}"
    //             PGID                            = "${meta.PGID}"
    //             PUID                            = "${meta.PUID}"
    //             TZ                              = "America/New_York"
    //         }

    //         driver = "docker"
    //         config {
    //             image              = "gitea/act_runner:latest"
    //             image_pull_timeout = "10m"
    //             hostname           = "${NOMAD_TASK_NAME}"
    //             volumes            = [
    //                 "${meta.nfsStorageRoot}/pi-cluster/gitea-action-runners:/data",
    //                 "/var/run/docker.sock:/var/run/docker.sock"
    //             ]
    //             ports = ["cache"]
    //         } // docker config

    //         template {
    //             destination   = "local/config.yml"
    //             env           = false
    //             change_mode   = "noop"
    //             data          = <<-EOH
    //             log:
    //                 # The level of logging, can be trace, debug, info, warn, error, fatal
    //                 level: info

    //             runner:
    //                 # Where to store the registration result.
    //                 {% raw %}file: .runner-{{ env "node.unique.name" }}{% endraw +%}
    //                 # Execute how many tasks concurrently at the same time.
    //                 capacity: 1
    //                 # Extra environment variables to run jobs.
    //                 envs:
    //                     A_TEST_ENV_NAME_1: a_test_env_value_1
    //                     A_TEST_ENV_NAME_2: a_test_env_value_2
    //                 # Extra environment variables to run jobs from a file.
    //                 # It will be ignored if it's empty or the file doesn't exist.
    //                 env_file: .env
    //                 # The timeout for a job to be finished.
    //                 # Please note that the Gitea instance also has a timeout (3h by default) for the job.
    //                 # So the job could be stopped by the Gitea instance if it's timeout is shorter than this.
    //                 timeout: 3h
    //                 # Whether skip verifying the TLS certificate of the Gitea instance.
    //                 insecure: false
    //                 # The timeout for fetching the job from the Gitea instance.
    //                 fetch_timeout: 5s
    //                 # The interval for fetching the job from the Gitea instance.
    //                 fetch_interval: 2s
    //                 # The labels of a runner are used to determine which jobs the runner can run, and how to run them.
    //                 # Like: ["macos-arm64:host", "ubuntu-latest:docker://node:16-bullseye", "ubuntu-22.04:docker://node:16-bullseye"]
    //                 # If it's empty when registering, it will ask for inputting labels.
    //                 # If it's empty when execute `daemon`, will use labels in `.runner` file.
    //                 labels: []

    //             cache:
    //                 # Enable cache server to use actions/cache.
    //                 enabled: false
    //                 # The directory to store the cache data.
    //                 # If it's empty, the cache data will be stored in $HOME/.cache/actcache.
    //                 dir: ""
    //                 # The host of the cache server.
    //                 # It's not for the address to listen, but the address to connect from job containers.
    //                 # So 0.0.0.0 is a bad choice, leave it empty to detect automatically.
    //                 {% raw %}host: "{{ env "NOMAD_IP_cache" }}"{% endraw +%}
    //                 # The port of the cache server.
    //                 {% raw %}port: {{ env "NOMAD_HOST_PORT_cache" }}{% endraw +%}
    //                 # The external cache server URL. Valid only when enable is true.
    //                 # If it's specified, act_runner will use this URL as the ACTIONS_CACHE_URL rather than start a server by itself.
    //                 # The URL should generally end with "/".
    //                 external_server: ""

    //             container:
    //                 # Specifies the network to which the container will connect.
    //                 # Could be host, bridge or the name of a custom network.
    //                 # If it's empty, act_runner will create a network automatically.
    //                 network: ""
    //                 # Whether to use privileged mode or not when launching task containers (privileged mode is required for Docker-in-Docker).
    //                 privileged: false
    //                 # And other options to be used when the container is started (eg, --add-host=my.gitea.url:host-gateway).
    //                 options:
    //                 # The parent directory of a job's working directory.
    //                 # If it's empty, /workspace will be used.
    //                 workdir_parent:
    //                 # Volumes (including bind mounts) can be mounted to containers. Glob syntax is supported, see https://github.com/gobwas/glob
    //                 # You can specify multiple volumes. If the sequence is empty, no volumes can be mounted.
    //                 # For example, if you only allow containers to mount the `data` volume and all the json files in `/src`, you should change the config to:
    //                 # valid_volumes:
    //                 #   - data
    //                 #   - /src/*.json
    //                 # If you want to allow any volume, please use the following configuration:
    //                 # valid_volumes:
    //                 #   - '**'
    //                 valid_volumes:
    //                     - '**'
    //                 # overrides the docker client host with the specified one.
    //                 # If it's empty, act_runner will find an available docker host automatically.
    //                 # If it's "-", act_runner will find an available docker host automatically, but the docker host won't be mounted to the job containers and service containers.
    //                 # If it's not empty or "-", the specified docker host will be used. An error will be returned if it doesn't work.
    //                 docker_host: ""
    //                 # Pull docker image(s) even if already present
    //                 force_pull: false

    //             host:
    //                 # The parent directory of a job's working directory.
    //                 # If it's empty, $HOME/.cache/act/ will be used.
    //                 workdir_parent:
    //             EOH
    //         }

    //         // service {
    //         //     port = "cache"
    //         //     name = "${NOMAD_TASK_NAME}"
    //         //     provider = "nomad"
    //         //     tags = [
    //         //         "traefik.enable=true",
    //         //         "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
    //         //         "traefik.http.routers.${NOMAD_TASK_NAME}.entryPoints=web,websecure",
    //         //         "traefik.http.routers.${NOMAD_TASK_NAME}.service=${NOMAD_TASK_NAME}",
    //         //         "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
    //         //         "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=cloudflare",
    //         //         "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=authelia@file"
    //         //         ]

    //         //     check {
    //         //         type     = "tcp"
    //         //         port     = "cache"
    //         //         interval = "30s"
    //         //         timeout  = "4s"
    //         //     }

    //         //     check_restart {
    //         //         limit           = 0
    //         //         grace           = "1m"
    //         //     }

    //         // } // service

    //         resources {
    //             cpu    = 400 # MHz
    //             memory = 600 # MB
    //         } // resources

    //     } // task gitea-action-runner

    // } // group action-runners

} // job
