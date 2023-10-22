
job "TEMPLATE" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "service"

  // constraint {
  //   attribute = "${node.unique.name}"
  //   operator  = "regexp"
  //   value     = "rpi4"
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

  group "TEMPLATE-group" {

    count = 1

    restart {
      attempts = 0
      delay    = "10m"
    }

    network {
      port "port1" {
        static = ""
        to     = ""
      }
    }

    task "create_filesystem" {
      // Copy the most recent backup into place on the local computer.  sonarr will not work with
      // its database in an NFS share

      driver = "raw_exec"
      config {
        # When running a binary that exists on the host, the path must be absolute
        command = "${meta.restoreCommand}"
        args    = [
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

    task "TEMPLATE" {

      env {
        PUID = "${meta.PUID}"
        PGID = "${meta.PGID}"
        TZ   = "America/New_York"
      }

      driver = "docker"
      config {
        image    = ""
        hostname = "${NOMAD_TASK_NAME}"
        ports    = ["port1"]
        volumes = [
          "${meta.localStorageRoot}/${NOMAD_TASK_NAME}:/config"
        ]

      } // docker config

      service {
        port = "port1"
        name = "${NOMAD_TASK_NAME}"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
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
        cpu    = 1000 # MHz
        memory = 400  # MB
      }               // resources

    } // /task ${NOMAD_JOB_NAME}

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
