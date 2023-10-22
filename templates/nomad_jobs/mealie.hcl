job "mealie" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"


    constraint {
      attribute = "${attr.cpu.arch}"
      regexp = "amd64"
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

  group "mealie" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    network {
        port "port1" {
            // static = "80"
            to     = "80"
        }
    }

    task "mealie" {

      env {
          PUID                    = "${meta.PUID}"
          PGID                    = "${meta.PGID}"
          TZ                      = "America/New_York"
          RECIPE_PUBLIC           = "true"
          RECIPE_SHOW_NUTRITION   = "true"
          RECIPE_SHOW_ASSETS      = "true"
          RECIPE_LANDSCAPE_VIEW   = "true"
          RECIPE_DISABLE_COMMENTS = "false"
          RECIPE_DISABLE_AMOUNT   = "false"
          DB_ENGINE               = "sqlite"  # 'sqlite', 'postgres'
          BASE_URL                = "https://${NOMAD_JOB_NAME}.{{ homelab_domain_name }}"
          AUTO_BACKUP_ENABLED     = "true"

      }

      driver = "docker"
      config {
          image    = "hkotel/mealie:latest"
          hostname = "${NOMAD_TASK_NAME}"
          volumes  = [
            "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_TASK_NAME}:/app/data"
          ]
          ports = ["port1"]
      } // docker config

      service  {
          port = "port1"
          name = "${NOMAD_TASK_NAME}"
          provider = "nomad"
          tags = [
              "traefik.enable=true",
              "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${NOMAD_JOB_NAME}.{{ homelab_domain_name }}`)",
              "traefik.http.routers.${NOMAD_TASK_NAME}.entryPoints=web,websecure",
              "traefik.http.routers.${NOMAD_TASK_NAME}.service=${NOMAD_TASK_NAME}",
              "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
              "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=cloudflare"
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

      // resources {
      //     cpu    = 100 # MHz
      //     memory = 300 # MB
      // } // resources

    } // task


  } // group


} // job
