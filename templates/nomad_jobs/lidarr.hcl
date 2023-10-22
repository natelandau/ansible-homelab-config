job "lidarr" {
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
    healthy_deadline  = "10m"
    progress_deadline = "15m"
    auto_revert       = true
    canary            = 0
    stagger           = "30s"
  }

  group "lidarrGroup" {

    count = 1

    restart {
      attempts = 0
      delay    = "10m"
    }

    network {
      port "lidarr" {
        to      = "8686"
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

    task "lidarr" {

      env {
          PUID        = "${meta.PUID}"
          PGID        = "${meta.PGID}"
          TZ          = "America/New_York"
          //DOCKER_MODS = "linuxserver/mods:universal-cron|linuxserver/mods:universal-mod2"
          //UMASK_SET = 022 #optional
      }

      driver = "docker"
      config {
        image    = "linuxserver/lidarr:latest"
        hostname = "${NOMAD_JOB_NAME}"
        ports    = ["lidarr"]
        volumes  = [
          "${meta.localStorageRoot}/lidarr:/config",
          "${meta.nfsStorageRoot}/media:/media"
        ]
      } // docker config

      service  {
        port = "lidarr"
        name = "${NOMAD_JOB_NAME}"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
          "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
          "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare"
          ]

        check {
          type     = "tcp"
          port     = "lidarr"
          interval = "30s"
          timeout  = "4s"
        }
        check_restart {
          limit           = 0
          grace           = "10m"
        }
      } // service

      resources {
        cpu    = 2000 # MHz
        memory = 400 # MB
      } // resources

    } // /task lidarr main task

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
