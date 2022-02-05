job "diagnostics" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "service"

  // constraint {
  //   attribute = "${node.unique.name}"
  //   operator  = "regexp"
  //   value     = "rpi(1|2|3)"
  // }

  group "diagnostics" {

    count = 1

    restart {
      attempts = 0
      delay    = "30s"
    }

    task "diagnostics" {

      // env {
      //   KEY = "VALUE"
      // }

      driver = "docker"
      config {
        image    = "alpine:latest"
        hostname = "${NOMAD_JOB_NAME}"
        args     = [
          "/bin/sh",
          "-c",
          "chmod 755 /local/bootstrap.sh && /local/bootstrap.sh"
        ]
        volumes   = [
          "${meta.nfsStorageRoot}/pi-cluster/backups/config_backups:/backups",
          "${meta.localStorageRoot}:/docker"
        ]
      } // docker config

      template {
        destination = "local/bootstrap.sh"
        data        = <<EOH
          #!/bin/sh

          apk update
          apk add --no-cache bash
          apk add --no-cache bind-tools
          apk add --no-cache curl
          apk add --no-cache git
          apk add --no-cache jq
          apk add --no-cache openssl
          apk add --no-cache iperf3
          apk add --no-cache nano
          apk add --no-cache wget

          tail -f /dev/null   # Keep container running
          EOH
      }

    } // tasks
  } // group
} // job
