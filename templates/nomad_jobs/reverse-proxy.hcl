job "reverse-proxy" {
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

    group "authelia-group" {

        constraint {
            attribute = "${node.unique.name}"
            operator  = "regexp"
            value     = "rpi"
        }

        restart {
            attempts = 0
            delay    = "30s"
        }

        network {
            port "authelia-port" {
                to     = 9091
            }
        }

        task "authelia" {

            env {
                TZ                = "America/New_York"
                PUID              = "${meta.PUID}"
                PGID              = "${meta.PGID}"
            }

            driver = "docker"
            config {
                image              = "authelia/authelia:{{ authelia_version }}"
                hostname           = "authelia"
                ports              = ["authelia-port"]
                image_pull_timeout = "10m"
                volumes  = [ "${meta.nfsStorageRoot}/pi-cluster/authelia:/config" ]
                args     = [
                    "--config",
                    "/local/authelia/config.yml"
                ]
            } // docker config

            template {
                destination = "local/authelia/users.yml"
                env         = false
                change_mode = "restart"
                perms       = "644"
                data        = <<-EOH
                    ---
                    ###############################################################
                    #                         Users Database                      #
                    ###############################################################

                    # This file can be used if you do not have an LDAP set up.
                    users:
                        {{ authelia_user1_name }}:
                            displayname: "{{ authelia_user1_name }}"
                            password: "$argon2id$v=19$m=65536,t=1,p={{ authelia_user1_password }}"
                            email: {{ authelia_user1_email }}
                            groups:
                                - admins
                                - dev
                    EOH
            }

            template {
                destination = "local/authelia/config.yml"
                env         = false
                change_mode = "restart"
                perms       = "644"
                data        = <<-EOH
                    ---
                    ## The theme to display: light, dark, grey, auto.
                    theme: auto

                    jwt_secret: {{ authelia_jwt_secret}}
                    default_redirection_url: https://authelia.{{ homelab_domain_name}}

                    server:
                        host: 0.0.0.0
                        port: 9091
                        path: ""
                        buffers:
                            read: 4096
                            write: 4096
                        timeouts:
                            read: 15s
                            write: 15s
                            idle: 30s
                        enable_pprof: false
                        enable_expvars: false
                        disable_healthcheck: false

                    log:
                        level: info
                        format: text
                        # file_path: "/config/log.txt"
                        keep_stdout: false

                    totp:
                        issuer: authelia.com

                    authentication_backend:
                        password_reset:
                            disable: false
                        file:
                            path: /local/authelia/users.yml
                            password:
                                algorithm: argon2id
                                iterations: 1
                                salt_length: 16
                                parallelism: 8
                                memory: 64

                    access_control:
                        default_policy: deny
                        networks:
                        - name: internal
                          networks:
                            - 10.0.0.0/8
                            #- 172.16.0.0/12
                            #- 192.168.0.0/18
                        rules:
                            # Rules applied to everyone
                            - domain: "*.{{ homelab_domain_name }}"
                              policy: two_factor
                              networks:
                                - internal

                    session:
                        name: authelia_session
                        domain: {{ homelab_domain_name }}
                        same_site: lax
                        secret: {{ authelia_session_secret }}
                        expiration: 1h
                        inactivity: 15m
                        remember_me_duration: 1w

                    regulation:
                        max_retries: 5
                        find_time: 10m
                        ban_time: 15m

                    storage:
                        encryption_key: {{ authelia_sqlite_encryption_key}}
                        local:
                            path: /config/db.sqlite3

                    notifier:
                        smtp:
                            username: {{ email_smtp_account }}
                            password: {{ authelia_smtp_password }}
                            host: {{ email_smtp_host }}
                            port: {{ email_smtp_port }}
                            sender: "Authelia <{{ my_email_address }}>"
                            subject: "[Authelia] {title}"
                            startup_check_address: {{ my_email_address }}

                    ntp:
                        address: "time.cloudflare.com:123"
                        version: 3
                        max_desync: 3s
                        disable_startup_check: true
                        disable_failure: true
                    EOH
            }

            service  {
                port = "authelia-port"
                name = "${NOMAD_TASK_NAME}"
                provider = "nomad"
                tags = [
                    "traefik.enable=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`authelia.{{ homelab_domain_name }}`)",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.entryPoints=web,websecure",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.service=${NOMAD_TASK_NAME}",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=cloudflare",
                    "traefik.http.middlewares.authelia-headers.headers.customResponseHeaders.Cache-Control=no-store",
                    "traefik.http.middlewares.authelia-headers.headers.customResponseHeaders.Pragma=no-cache",
                    "traefik.http.routers.authelia.middlewares=authelia-headers"
                    ]

                check {
                    type     = "tcp"
                    port     = "authelia-port"
                    interval = "30s"
                    timeout  = "4s"
                }

                check_restart {
                    limit           = 0
                    grace           = "1m"
                }
            } // service

            resources {
                cpu    = 200 # MHz
                memory = 1000 # MB
            }

        } // task authelia

    } // authelia-group

    group "reverse-proxy-group" {
        constraint {
            attribute = "${node.unique.name}"
            value     = "rpi1"
        }

        restart {
            attempts = 0
            delay    = "30s"
        }

        network {
            port "whoami" {
                to     = 80
            }
            port "dashboard" {
                static = 8080
                to     = 8080
            }
            port "web" {
                static = 80
                to     = 80
            }
            port "websecure" {
                static = 443
                to     = 443
            }
            port "externalwebsecure" {
                static = 4430
                to     = 4430
            }
            port "ssh" { # Used for gitea
                static = 2222
                to     = 2222
            }
        }

        task "whoami" {
            driver = "docker"
            config {
                image              = "containous/whoami:latest"
                hostname           = "${NOMAD_TASK_NAME}"
                image_pull_timeout = "10m"
                ports              = ["whoami"]

            } // /docker config

            service {
                port = "whoami"
                name = "${NOMAD_TASK_NAME}"
                provider = "nomad"
                tags = [
                    "traefik.enable=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${NOMAD_TASK_NAME}.{{ homelab_domain_name }}`)",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.entryPoints=web,websecure",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.service=${NOMAD_TASK_NAME}",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=cloudflare",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=authelia@file"
                ]
                check {
                    type     = "http"
                    path     = "/"
                    interval = "90s"
                    timeout  = "15s"
                }
                check_restart {
                    limit = 2
                    grace = "1m"
                }
            }
            resources {
                cpu    = 25 # MHz
                memory = 10 # MB
            }

        } // /task whoami

        task "traefik" {

            env {
                PUID              = "${meta.PUID}"
                PGID              = "${meta.PGID}"
                TZ                = "America/New_York"
                CF_API_EMAIL      = "{{ my_email_address }}"
                CF_DNS_API_TOKEN  = "{{ traefik_cf_api_token }}"
            }

            driver = "docker"
            config {
                image              = "traefik:v{{ traefik_version }}"
                hostname           = "traefik"
                ports              = ["dashboard", "web", "websecure","externalwebsecure", "ssh"]
                volumes            = [ "${meta.nfsStorageRoot}/pi-cluster/traefik/acme:/acme" ]
                image_pull_timeout = "10m"
                args     = [
                    "--global.sendAnonymousUsage=false",
                    "--global.checkNewVersion=false",
                    "--entryPoints.gitea-ssh.address=:2222",
                    "--entryPoints.web.address=:80",
                    "--entryPoints.websecure.address=:443",
                    "--entryPoints.externalwebsecure.address=:4430",
                    "--entrypoints.web.http.redirections.entryPoint.to=websecure",
                    "--entrypoints.web.http.redirections.entryPoint.scheme=https",
                    "--entrypoints.web.http.redirections.entryPoint.permanent=true",
                    "--providers.file.filename=/local/traefik/siteconfigs.toml",
                    "--providers.file.watch=true",
                    "--providers.consulcatalog=true",
                    "--providers.consulcatalog.endpoint.address=http://${NOMAD_IP_web}:8500",
                    "--providers.consulcatalog.prefix=traefik",
                    "--providers.consulcatalog.exposedbydefault=false",
                    "--providers.nomad=true",
                    "--providers.nomad.endpoint.address=http://${NOMAD_IP_web}:4646",
                    // "--metrics=true",
                    // "--metrics.influxdb=true",
                    // "--metrics.influxdb.address=influxdb.service.consul:{{ influxdb_port }}",
                    // "--metrics.influxdb.protocol=http",
                    // "--metrics.influxdb.pushinterval=10s",
                    // "--metrics.influxdb.database=homelab",
                    // "--metrics.influxdb.retentionpolicy=2day",
                    // "--metrics.influxdb.addentrypointslabels=true",
                    // "--metrics.influxdb.addserviceslabels=true",
                    "--accesslog=true",
                    "--log=true",
                    "--log.level=ERROR",
                    "--api=true",
                    "--api.dashboard=true",
                    "--api.insecure=true",
                    "--certificatesresolvers.cloudflare.acme.email={{ my_email_address }}",
                    "--certificatesresolvers.cloudflare.acme.storage=/acme/acme-${node.unique.name}.json",
                    "--certificatesresolvers.cloudflare.acme.dnschallenge=true",
                    "--certificatesresolvers.cloudflare.acme.dnschallenge.provider=cloudflare",
                    "--certificatesresolvers.cloudflare.acme.dnschallenge.delaybeforecheck=10",
                    "--certificatesresolvers.cloudflare.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53"
                ]
            } // docker config

            template {
                destination   = "local/traefik/httpasswd"
                env           = false
                change_mode   = "noop"
                data          = <<-EOH
                    {{ my_username }}:{{ traefik_http_pass_me }}
                    family:{{ traefik_http_pass_family }}
                EOH
            }

            template {
                destination   = "local/traefik/httpasswdFamily"
                env           = false
                change_mode   = "noop"
                data          = <<-EOH
                    {{ my_username }}:{{ traefik_http_pass_me }}
                    family:{{ traefik_http_pass_family }}
                EOH
            }

            template {
                destination = "local/traefik/siteconfigs.toml"
                env         = false
                change_mode = "noop"
                data        = <<-EOH
                    [http]
                    [http.middlewares]
                        [http.middlewares.compress.compress]

                        [http.middlewares.localIPOnly.ipWhiteList]
                            sourceRange = ["10.0.0.0/8"]

                        [http.middlewares.redirectScheme.redirectScheme]
                            scheme = "https"
                            permanent = true

                        [http.middlewares.authelia.forwardAuth]
                            address = {% raw %}"http://{{ range nomadService "authelia" }}{{ .Address }}:{{ .Port }}{{ end }}{% endraw %}/api/verify?rd=https://authelia.{{ homelab_domain_name }}"
                            trustForwardHeader = true
                            authResponseHeaders = ["Remote-User", "Remote-Groups", "Remote-Name", "Remote-Email"]

                        [http.middlewares.basicauth.basicauth]
                            usersfile = "/local/traefik/httpasswd"
                            removeHeader = true

                        [http.middlewares.basicauth-family.basicauth]
                            usersfile = "/local/traefik/httpasswdFamily"
                            removeHeader = true

                        [http.middlewares.allowFrame.headers]
                            customFrameOptionsValue = "allow-from https://home.{{ homelab_domain_name }}"

                    [http.routers]

                        [http.routers.consul]
                            rule = "Host(`consul.{{ homelab_domain_name }}`)"
                            service = "consul"
                            entrypoints = ["web","websecure"]
                        [http.routers.consul.tls]
                            certResolver = "cloudflare" # From static configuration

                    [http.services]

                        [http.services.consul]
                            [http.services.consul.loadBalancer]
                                passHostHeader = true
                            [[http.services.consul.loadBalancer.servers]]
                                url = "http://consul.service.consul:8500"

                EOH
            }

            service  {
                port = "dashboard"
                name = "${NOMAD_TASK_NAME}"
                provider = "nomad"
                tags = [
                    "traefik.enable=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${NOMAD_TASK_NAME}.{{ homelab_domain_name }}`)",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.entryPoints=web,websecure",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.service=${NOMAD_TASK_NAME}",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=cloudflare",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=authelia@file,redirectScheme@file"
                ]

                check {
                    type     = "tcp"
                    port     = "dashboard"
                    interval = "30s"
                    timeout  = "4s"
                }

                check_restart {
                    limit = 0
                    grace = "1m"
                }
            } // service

            resources {
                cpu    = 140 # MHz
                memory = 100 # MB
            } // resources

        } // task traefik

        // task "promtail-traefik" {

        //   driver = "docker"
        //   config {
        //       image    = "grafana/promtail"
        //       hostname = "promtail-traefik"
        //       volumes  = [
        //           "/mnt/pi-cluster/logs:/traefik"
        //       ]
        //       args         = [
        //           "-config.file",
        //           "/local/promtail-config.yaml",
        //           "-print-config-stderr",
        //       ]
        //   } // docker config

        //   template {
        //     destination = "local/promtail-config.yaml"
        //     env         = false
        //     data = <<-EOH
        //       server:
        //         http_listen_port: 9080
        //         grpc_listen_port: 0

        //       positions:
        //         filename: /alloc/positions.yaml

        //       {% raw -%}
        //       clients:
        //         - url: http://{{ range nomadService "loki" }}{{ .Address }}:{{ .Port }}{{ end }}/loki/api/v1/push
        //         {% endraw %}

        //       scrape_configs:
        //         - job_name: traefik
        //           static_configs:
        //           - targets:
        //               - localhost
        //             labels:
        //               job: traefik_access
        //               {% raw %}host: {{ env "node.unique.name" }}{% endraw +%}
        //               __path__: "/alloc/logs/traefik.std*.0"
        //           pipeline_stages:
        //             - regex:
        //                 expression: '^(?P<remote_addr>[\w\.]+) - (?P<remote_user>[^ ]*) \[(?P<time_local>.*)\] "(?P<method>[^ ]*) (?P<request>[^ ]*) (?P<protocol>[^ ]*)" (?P<status>[\d]+) (?P<body_bytes_sent>[\d]+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)" (?P<request_number>[^ ]+) "(?P<router>[^ ]+)" "(?P<server_URL>[^ ]+)" (?P<response_time_ms>[^ ]+)ms$'
        //             - labels:
        //                 method:
        //                 status:
        //                 router:
        //                 response_time_ms:

        //       EOH
        //   } // template

        //   lifecycle {
        //     hook    = "poststart"
        //     sidecar = true
        //   }

        //   resources {
        //     cpu    = 30 # MHz
        //     memory = 30 # MB
        //   } // resources

        // } // promtail sidecar task

    } // reverse-proxy-group
}
