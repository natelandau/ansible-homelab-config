job "execTest" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "batch"

  constraint {
    attribute = "${node.unique.name}"
    operator  = "regexp"
    value     = "rpi3"
  }

  group "testing" {

    task "execTest" {
      driver = "raw_exec"
      config {
        command = "/usr/local/bin/backup_configs"
        args = ["--verbose","--job","sonarr"]
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
