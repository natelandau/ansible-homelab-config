job "sabnzbd" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"

    constraint {
        attribute = "${node.unique.name}"
        operator  = "regexp"
        value     = "macmini"
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

  group "sabnzbd" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    network {
        port "http" {
            static = "8080"
            to     = "8080"
        }

    }

    task "sabnzbd" {

      env {
          PUID        = "${meta.PUID}"
          PGID        = "${meta.PGID}"
          TZ          = "America/New_York"
          DOCKER_MODS = "linuxserver/mods:universal-cron"
      }

      driver = "docker"
      config {
          image    = "ghcr.io/linuxserver/sabnzbd"
          hostname = "${NOMAD_TASK_NAME}"
          volumes  = [
            "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_TASK_NAME}:/config",
            "${meta.nfsStorageRoot}/media/downloads/nzb:/nzbd",
            "${meta.nfsStorageRoot}/media/downloads/temp:/incomplete-downloads",
            "${meta.nfsStorageRoot}/media/downloads/complete:/downloads",
            "${meta.nfsStorageRoot}/nate:/nate",
            "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_TASK_NAME}/startup-scripts:/custom-cont-init.d"
          ]
          ports = ["http"]
      } // docker config

      service {
          port = "http"
          name = "${NOMAD_TASK_NAME}"
          provider = "nomad"
          tags = [
              "traefik.enable=true",
              "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`sab.{{ homelab_domain_name }}`)",
              "traefik.http.routers.${NOMAD_TASK_NAME}.entryPoints=web,websecure",
              "traefik.http.routers.${NOMAD_TASK_NAME}.service=${NOMAD_TASK_NAME}",
              "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
              "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=cloudflare"
            //   "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=authelia@file"
            ]

          check {
              type     = "tcp"
              port     = "http"
              interval = "30s"
              timeout  = "4s"
          }
          check_restart {
              limit           = 0
              grace           = "1m"
          }
      } // service

      resources {
          cpu    = 5000 # MHz
          memory = 1000 # MB
      } // resources

    } // task


  } // group


} // job
