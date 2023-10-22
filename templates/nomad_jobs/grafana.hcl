job "grafana" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "service"

  // constraint {
  //     attribute = "${node.unique.name}"
  //     operator  = "regexp"
  //     value     = "macmini"
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

  group "grafana" {

    count = 1

    restart {
      attempts = 0
      delay    = "30s"
    }

    network {
      port "http" {}
    }


    task "grafana" {

      env {
        GF_PATHS_CONFIG = "/local/grafana.ini"
      }

      driver = "docker"
      config {
        image    = "grafana/grafana:latest"
        hostname = "${NOMAD_JOB_NAME}"
        ports    = ["http"]
        volumes  = ["${meta.nfsStorageRoot}/pi-cluster/grafana:/var/lib/grafana"]
      } // docker config

      template {
        destination = "local/grafana.ini"
        data        = <<EOH
          [server]
          domain = grafana.{{ homelab_domain_name }}
          {% raw %}http_port = {{ env "NOMAD_PORT_http" }}{% endraw +%}
          [analytics]
          reporting_enabled = false
          [security]
          admin_user = {{ my_username }}
          admin_password = {{ grafana_admin_password }}
          cookie_secure = true
          [users]
          allow_sign_up = false
          allow_org_create = false
          [smtp]
          enabled = true
          host = {{ email_smtp_host }}:{{ email_smtp_port}}
          user = {{ email_smtp_account }}
          password = {{ grafana_smtp_password }}
          skip_verify = true
          from_address = {{ my_email_address }}
          from_name = Grafana
          [log.file]
          level = info
          [date_formats]
          default_timezone = America/New_York
          [auth.proxy]
          enabled = true
          header_name = Remote-User
          header_property = username
          auto_sign_up = false
          sync_ttl = 60
        EOH
      }

      service {
        port = "http"
        name = "${NOMAD_JOB_NAME}"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
          "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
          "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare",
          "traefik.http.middlewares.${NOMAD_JOB_NAME}_logout_redirect.redirectregex.regex=${NOMAD_JOB_NAME}\\.{{ homelab_domain_name }}/logout$",
          "traefik.http.middlewares.${NOMAD_JOB_NAME}_logout_redirect.redirectregex.replacement=authelia.{{ homelab_domain_name }}/logout",
          "traefik.http.routers.${NOMAD_JOB_NAME}.middlewares=authelia@file,${NOMAD_JOB_NAME}_logout_redirect"
        ]

        check {
          type     = "http"
          port     = "http"
          path     = "/"
          interval = "90s"
          timeout  = "15s"
        }
        check_restart {
          limit           = 0
          grace           = "1m"
        }
      } // service

      resources {
        cpu    = 200 # MHz
        memory = 60  # MB
      }              // resources

    } // task grafana

  } // group


} // job
