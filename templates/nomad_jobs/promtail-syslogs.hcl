job "promtail-syslogs" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "system"

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

  group "promtail-syslogs" {

    restart {
      attempts = 0
      delay    = "30s"
    }

    task "promtail-syslogs" {

      driver = "docker"
      config {
        image    = "grafana/promtail"
        hostname = "${NOMAD_JOB_NAME}"
        volumes  = [
          "/var/log:/var/log"
        ]
        args         = [
          "-config.file",
          "/local/promtail-config.yaml",
          "-print-config-stderr"
        ]
      } // docker config


      template {
        destination = "local/promtail-config.yaml"
        env         = false
        data        = <<EOH
          server:
            http_listen_port: 9080
            grpc_listen_port: 0

          positions:
            filename: /tmp/positions.yaml

          {% raw -%}
          clients:
            - url: http://{{ range nomadService "loki" }}{{ .Address }}:{{ .Port }}{{ end }}/loki/api/v1/push
          {% endraw %}

          scrape_configs:
            - job_name: system
              static_configs:
              - targets:
                  - localhost
                labels:
                  job: syslog
                  {% raw %}host: {{ env "node.unique.name" }}{% endraw +%}
                  __path__: /var/log/syslog
              - targets:
                  - localhost
                labels:
                  job: authlog
                  {% raw %}host: {{ env "node.unique.name" }}{% endraw +%}
                  __path__: /var/log/auth.log

          EOH
      } // template


      resources {
        cpu    = 30 # MHz
        memory = 30 # MB
      } // resources

    } // task


  } // group


} // job
