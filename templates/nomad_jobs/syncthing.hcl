job "syncthing" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "service"

  constraint {
    attribute = "${node.unique.name}"
    operator  = "regexp"
    value     = "rpi"
  }

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

  group "syncthing" {

    restart {
      attempts = 0
      delay    = "30s"
    }

    network {
      port "webGUI" {
        to = "8384"
      }
      port "listen_tcp_udp" {
        static  = "22000"
        to      = "22000"
      }
      port "udp_proto_discovery" {
        static  = "21027"
        to      = "21027"
      }
    }

    task "syncthing" {

      env {
          PUID        = "${meta.PUID}"
          PGID        = "${meta.PGID}"
          TZ          = "America/New_York"
      }

      driver = "docker"
      config {
        image = "ghcr.io/linuxserver/syncthing"
        hostname = "${NOMAD_JOB_NAME}"
        volumes = [
          "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_JOB_NAME}:/config",
          "${meta.nfsStorageRoot}/${NOMAD_JOB_NAME}:/Sync"
        ]
        ports = ["webGUI","listen_tcp_udp","udp_proto_discovery"]
      } // docker config

      service  {
        port = "webGUI"
        name = "${NOMAD_JOB_NAME}"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
          "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
          "traefik.http.routers.${NOMAD_JOB_NAME}.service=syncthing",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare",
          "traefik.http.routers.${NOMAD_JOB_NAME}.middlewares=authelia@file"
          ]

        check {
          type     = "tcp"
          port     = "webGUI"
          interval = "30s"
          timeout  = "4s"
        }
        check_restart {
          limit = 0
          grace = "1m"
        }
      } // service

      resources {
        cpu    = 1200 # MHz
        memory = 300 # MB
      } // resources

    } // task


  } // group


} // job
