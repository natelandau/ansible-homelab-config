job "chronograf" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "service"

  // constraint {
  //   attribute = "${node.unique.name}"
  //   operator  = "regexp"
  //   value     = "rpi(1|2|3)"
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

  group "chronograf" {

    restart {
      attempts = 0
      delay    = "30s"
    }

    network {
      port "chronografPort" {
        to = "8888"
      }
    }

    task "await-influxdb" {
      driver = "docker"

      config {
        image   = "busybox:latest"
        command = "sh"
        args = [
          "-c",
          "echo -n 'Waiting for influxdb.service.consul to come alive'; until nslookup influxdb.service.consul 2>&1 >/dev/null; do echo '.'; sleep 2; done"
        ]
        network_mode = "host"
      }

      resources {
        cpu    = 200
        memory = 128
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    } // /task

    task "chronograf" {

      // env {
      //   KEY = "VALUE"
      // }

      driver = "docker"
      config {
        image    = "chronograf:latest"
        hostname = "${NOMAD_JOB_NAME}"
        ports    = ["chronografPort"]
      } // docker config

      service {
        port = "chronografPort"
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
          port     = "chronografPort"
          interval = "30s"
          timeout  = "4s"
        }
        check_restart {
          limit           = 0
          grace           = "1m"
        }
      } // service

      // resources {
      //   cpu    = 40 # MHz
      //   memory = 10 # MB
      // } // resources

    } // task


  } // group


} // job
