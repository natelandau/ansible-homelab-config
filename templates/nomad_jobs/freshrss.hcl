job "freshrss" {
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

  group "freshrss" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    network {
        port "port1" {
            to     = "80"
        }
    }

    task "freshrss" {

      env {
          PUID        = "${meta.PUID}"
          PGID        = "${meta.PGID}"
          TZ          = "America/New_York"
      }

      driver = "docker"
      config {
          image    = "lscr.io/linuxserver/freshrss"
          hostname = "${NOMAD_TASK_NAME}"
          volumes  = [ "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_TASK_NAME}:/config" ]
          ports = ["port1"]
      } // docker config

      service  {
          port = "port1"
          name = "${NOMAD_TASK_NAME}"
          provider = "nomad"
          tags = [
              "traefik.enable=true",
              "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`rss.{{ homelab_domain_name }}`)",
              "traefik.http.routers.${NOMAD_TASK_NAME}.entryPoints=web,websecure",
              "traefik.http.routers.${NOMAD_TASK_NAME}.service=${NOMAD_TASK_NAME}",
              "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
              "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=cloudflare",
              "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=authelia@file"
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
          cpu    = 100 # MHz
          memory = 300 # MB
      } // resources

    } // task


  } // group


} // job
