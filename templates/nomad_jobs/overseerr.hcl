job "overseerr" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "service"

  // constraint {
  //   attribute = "${node.unique.name}"
  //   operator  = "regexp"
  //   value     = "rpi"
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

  group "overseerr" {

    count = 1

    restart {
      attempts = 0
      delay    = "30s"
    }

    network {
      port "overseerr" {
        to = "5055"
      }
    }

    task "overseerr" {

      env {
          PUID = "${meta.PUID}"
          PGID = "${meta.PGID}"
          TZ   = "America/New_York"
      }

      driver = "docker"
      config {
        image    = "ghcr.io/linuxserver/overseerr"
        hostname = "${NOMAD_JOB_NAME}"
        ports    = ["overseerr"]
        volumes  = [ "${meta.nfsStorageRoot}/pi-cluster/overseerr:/config" ]
      } // docker config

      service  {
        port = "overseerr"
        name = "${NOMAD_JOB_NAME}"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
          "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
          "traefik.http.routers.${NOMAD_JOB_NAME}.service=overseerr",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare",
          "traefik.http.routers.${NOMAD_JOB_NAME}.middlewares=authelia@file"
          ]

        check {
          type     = "tcp"
          port     = "overseerr"
          interval = "30s"
          timeout  = "4s"
        }

        check_restart {
          limit           = 0
          grace           = "1m"
        }
      } // service

      resources {
        cpu    = 1600 # MHz
        memory = 300 # MB
      } // resources

    } // task


  } // group


} // job
