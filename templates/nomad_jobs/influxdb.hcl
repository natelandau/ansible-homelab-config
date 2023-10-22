job "influxdb" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "service"

  // constraint {
  //   attribute = "${attr.cpu.arch}"
  //   operator  = "regexp"
  //   value     = "64"
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

  group "influxdbGroup" {
    count = 1
    network {
      port "httpAPI" {
        static = "{{ influxdb_port }}"
        to     = "8086"
      }
    }

    restart {
      attempts = 0
      delay    = "30s"
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

    task "influxdb" {

      env {
          PUID        = "${meta.PUID}"
          PGID        = "${meta.PGID}"
          TZ          = "America/New_York"
      }

      driver = "docker"
      config {
        image    = "influxdb:{{ influxdb_version }}"
        hostname = "${NOMAD_JOB_NAME}"
        ports    = ["httpAPI"]
        volumes  = [
          "${meta.localStorageRoot}/influxdb:/var/lib/influxdb"
        ]
      } // docker config

      service  {
        port = "httpAPI"
        name = "${NOMAD_JOB_NAME}"
        provider = "nomad"

        check {
          type     = "tcp"
          port     = "httpAPI"
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
        memory = 400 # MB
      } // resources

    } // /task influxdb

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
