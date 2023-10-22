job "nzbhydra" {
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

  group "nzbhydra" {

    restart {
      attempts = 0
      delay    = "30s"
    }

    network {
      port "hydra_port" {
        to      = "5076"
      }
    }

    task "nzbhydra" {

      env {
          PUID        = "${meta.PUID}"
          PGID        = "${meta.PGID}"
          TZ          = "America/New_York"
          //DOCKER_MODS = "linuxserver/mods:universal-cron|linuxserver/mods:universal-mod2"
      }

      driver = "docker"
      config {
        image = "ghcr.io/linuxserver/nzbhydra2:latest"
        hostname = "${NOMAD_JOB_NAME}"
        ports = ["hydra_port"]
        volumes   = [
          "${meta.nfsStorageRoot}/pi-cluster/nzbhydra:/config"
        ]
      } // docker config

      service  {
        port = "hydra_port"
        name = "${NOMAD_JOB_NAME}"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`hydra.{{ homelab_domain_name }}`)",
          "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
          "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare"
          ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }
        check_restart {
          limit = 0
          grace = "1m"
        }
      } // service

      resources {
        cpu    = 600 # MHz
        memory = 400 # MB
      } // resources

    } // task


  } // group


} // job
