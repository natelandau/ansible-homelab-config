job "uptimekuma" {
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

  group "uptimekumaGroup" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    network {
        port "web" {
            to      = "3001"
        }
    }

    task "create_filesystem" {
      // Copy the most recent backup into place on the local computer.  sonarr will not work with
      // its database in an NFS share

      driver = "raw_exec"
      config {
        # When running a binary that exists on the host, the path must be absolute
        command = "${meta.restoreCommand}"
        args = [
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

    task "uptimekuma" {

      // env {
          // PUID        = "${meta.PUID}"
          // PGID        = "${meta.PGID}"
      // }

      driver = "docker"
      config {
          image     = "louislam/uptime-kuma:latest"
          hostname  = "${NOMAD_JOB_NAME}"
          volumes   = [ "${meta.localStorageRoot}/uptimekuma:/app/data" ]
          ports     = ["web"]
      } // docker config

      service  {
          port = "web"
          name = "${NOMAD_JOB_NAME}"
          provider = "nomad"
          tags = [
              "traefik.enable=true",
              "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`uptime.{{ homelab_domain_name }}`)",
              "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
              "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
              "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
              "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare"
            ]

          check {
              type     = "tcp"
              port     = "web"
              interval = "30s"
              timeout  = "4s"
          }
          check_restart {
              limit           = 0
              grace           = "1m"
          }
      } // service

      resources {
          cpu    = 400 # MHz
          memory = 100 # MB
      } // resources

    } // task

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
} // job
