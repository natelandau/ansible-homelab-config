job "changedetection" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"

  constraint {
    attribute = "${attr.cpu.arch}"
    operator  = "regexp"
    value     = "64"
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

  group "changedetection" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    network {
        port "webUI" {
            to      = "5000"
        }
    }

    task "changedetection" {

      env {
          TZ          = "America/New_York"
          PUID        = "${meta.PUID}"
          PGID        = "${meta.PGID}"
          BASE_URL    = "https://changes.{{ homelab_domain_name }}"
      }

      driver = "docker"
      config {
          image     = "lscr.io/linuxserver/changedetection.io:latest"
          hostname  = "${NOMAD_JOB_NAME}"
          volumes   = [
                        "${meta.nfsStorageRoot}/pi-cluster/changedetection:/config",
                      ]
          ports     = ["webUI"]
      } // docker config

      service  {
          port = "webUI"
          name = "${NOMAD_JOB_NAME}"
          provider = "nomad"
          tags = [
              "traefik.enable=true",
              "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`changes.{{ homelab_domain_name }}`)",
              "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
              "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
              "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
              "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare"
            ]

          check {
              type     = "http"
              path     = "/"
              interval = "30s"
              timeout  = "4s"
          }
          check_restart {
              limit           = 0
              grace           = "1m"
          }
      } // service

      resources {
          cpu    = 100 # MHz
          memory = 150 # MB
      } // resources

    } // task changedetection
  } // group
} // job
