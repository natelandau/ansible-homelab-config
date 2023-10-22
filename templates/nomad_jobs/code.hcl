job "code" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"

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

  group "code" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    network {
        port "port1" {
            // static = "80"
            to     = "3000"
        }
    }

    task "code" {

      env {
          PUID             = "${meta.PUID}"
          PGID             = "${meta.PGID}"
          TZ               = "America/New_York"
          SUDO_PASSWORD    = "{{ simple_web_password }}"
          PROXY_DOMAIN     = "code.{{ homelab_domain_name }}"
          CONNECTION_TOKEN = "1234"
          DOCKER_MODS      = "linuxserver/mods:code-server-python3|linuxserver/mods:code-server-shellcheck|linuxserver/mods:universal-git|linuxserver/mods:code-server-zsh"
          // CONNECTION_TOKEN  = supersecrettoken
          // CONNECTION_SECRET = supersecrettoken
      }

      driver = "docker"
      config {
          image    = "lscr.io/linuxserver/openvscode-server"
          hostname = "${NOMAD_JOB_NAME}"
          volumes  = [
            "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_JOB_NAME}:/config"
          ]
          ports = ["port1"]
      } // docker config

      service  {
          port = "port1"
          name = "${NOMAD_JOB_NAME}"
          provider = "nomad"
          tags = [
              "traefik.enable=true",
              "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
              "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
              "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
              "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
              "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare",
              "traefik.http.routers.${NOMAD_JOB_NAME}.middlewares=authelia@file,redirectScheme@file"
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
          cpu    = 1500 # MHz
          memory = 300 # MB
      } // resources

    } // task


  } // group


} // job
