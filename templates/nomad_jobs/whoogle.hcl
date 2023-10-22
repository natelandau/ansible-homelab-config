job "whoogle" {
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

  group "whoogle" {

    restart {
      attempts = 0
      delay    = "30s"
    }

    network {
      port "whoogle" {
        to = "5000"
      }
    }

    task "whoogle" {

      env {
        WHOOGLE_CONFIG_BLOCK           = "pinterest.com"
        WHOOGLE_CONFIG_DISABLE         = "1"
        WHOOGLE_CONFIG_GET_ONLY        = "1"
        WHOOGLE_CONFIG_LANGUAGE        = "lang_en"
        WHOOGLE_CONFIG_NEW_TAB         = "0"
        WHOOGLE_CONFIG_SEARCH_LANGUAGE = "lang_en"
        WHOOGLE_CONFIG_THEME           = "light"
        WHOOGLE_CONFIG_URL             = "https://${NOMAD_JOB_NAME}.{{ homelab_domain_name }}"
        WHOOGLE_CONFIG_VIEW_IMAGE      = "1"
        WHOOGLE_RESULTS_PER_PAGE       = "20"
      }

      driver = "docker"
      config {
        image    = "benbusby/whoogle-search:latest"
        hostname = "${NOMAD_JOB_NAME}"
        ports    = ["whoogle"]
      } // docker config

      service {
        port = "whoogle"
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
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "4s"
        }

        check_restart {
          limit           = 0
          grace           = "1m"
        }
      } // service

      // resources {
      //   cpu    = 100 # MHz
      //   memory = 300 # MB
      // } // resources

    } // task


  } // group


} // job
