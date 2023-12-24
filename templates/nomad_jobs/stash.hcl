job "stash" {
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

  group "stashGroup" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    network {
        port "port1" {
            to     = "9999"
        }
    }

    task "stash" {

      env {
          PUID                = "${meta.PUID}"
          PGID                = "${meta.PGID}"
          TZ                  = "America/New_York"
          STASH_STASH         = "/data/"
          STASH_GENERATED     = "/generated/"
          STASH_METADATA      = "/metadata/"
          STASH_CACHE         = "/cache/"
          STASH_PORT          = "9999"
          STASH_EXTERNAL_HOST = "https://${NOMAD_JOB_NAME}.{{ homelab_domain_name }}"
      }

      driver = "docker"
      config {
          image    = "stashapp/stash:latest"
          hostname = "${NOMAD_JOB_NAME}"
          volumes  = [
            "${meta.nfsStorageRoot}/nate/.stash/cache:/cache",
            "${meta.nfsStorageRoot}/nate/.stash/config:/root/.stash",
            "${meta.nfsStorageRoot}/nate/.stash/generated:/generated",
            "${meta.nfsStorageRoot}/nate/.stash/media:/data",
            "${meta.nfsStorageRoot}/nate/.stash/metadata:/metadata",
            "${meta.nfsStorageRoot}/nate/.stash/blobs:/blobs",
            "/etc/timezone:/etc/timezone:ro"
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
          cpu    = 3000 # MHz
          memory = 400 # MB
      } // resources

    } // task


  } // group


} // job
