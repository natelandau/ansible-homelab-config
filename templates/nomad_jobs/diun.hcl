job "diun" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "system"

  group "diun" {

    restart {
      attempts = 0
      delay    = "30s"
    }

    task "diun" {

      env {
        // DIUN_PROVIDERS_DOCKER_ENDPOINT       = "unix:///var/run/docker.sock"
        DIUN_NOTIF_PUSHOVER_RECIPIENT        = "{{ pushover_recipient }}"
        DIUN_NOTIF_PUSHOVER_TOKEN            = "{{ pushover_token }}"
        DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT = "true"
        DIUN_WATCH_FIRSTCHECKNOTIF           = "false"
        DIUN_WATCH_SCHEDULE                  = "26 */48 * * *"
        TZ                                   = "America/New_York"
      }

      driver = "docker"
      config {
        image    = "crazymax/diun:latest"
        hostname = "${NOMAD_JOB_NAME}"
        volumes  = [
            "/var/run/docker.sock:/var/run/docker.sock"
        ]
      } // docker config

      // resources {
      //   cpu    = 100 # MHz
      //   memory = 300 # MB
      // } // resources

    } // task diun
  } // group
} // job
