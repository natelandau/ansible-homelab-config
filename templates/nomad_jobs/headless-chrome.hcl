job "headless-chrome" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"

    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "amd64"
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

  group "headless-chrome" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    network {
        port "port1" {
            static = "9222"
            to     = "9222"
        }
    }

    task "headless-chrome" {

      // env {
          // PUID        = "${meta.PUID}"
          // PGID        = "${meta.PGID}"
      // }

      driver = "docker"
      config {
          image    = "alpeware/chrome-headless-trunk:latest"
          hostname = "${NOMAD_JOB_NAME}"
          ports = ["port1"]
      } // docker config

      service  {
          port = "port1"
          name = "${NOMAD_JOB_NAME}"
          provider = "nomad"
          tags = [
              "traefik.enable=true",
              "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`chrome.{{ homelab_domain_name }}`)",
              "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
              "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
              "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
              "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare"
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

      // resources {
      //     cpu    = 100 # MHz
      //     memory = 300 # MB
      // } // resources

    } // task


  } // group


} // job
