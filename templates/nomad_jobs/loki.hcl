job "loki" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "service"

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

  group "loki" {

    count = 1

    restart {
      attempts = 0
      delay    = "1m"
    }

    network {
      port "loki_port" {
        static  = "3100"
        to      = "3100"
      }
    }

    task "loki" {

      driver = "docker"
      config {
        image    = "grafana/loki:latest"
        hostname = "${NOMAD_JOB_NAME}"
        volumes  = [
          "local/loki/local-config.yaml:/etc/loki/local-config.yaml",
          "${meta.nfsStorageRoot}/pi-cluster/loki:/loki"

        ]
        ports = ["loki_port"]
      } // docker config

      service  {
        port = "loki_port"
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
          path     = "/metrics"
          interval = "30s"
          timeout  = "10s"
        }

        check_restart {
          limit           = 0
          grace           = "1m"
        }
      } // service

      template {
        destination = "local/loki/local-config.yaml"
        env         = false
        change_mode = "noop"
        data        = <<-EOH
          ---
          auth_enabled: false

          server:
            http_listen_port: 3100
            grpc_listen_port: 9096

          ingester:
            wal:
              enabled: true
              dir: /tmp/wal
            lifecycler:
              address: 127.0.0.1
              ring:
                kvstore:
                  store: inmemory
                replication_factor: 1
              final_sleep: 0s
            chunk_idle_period: 1h       # Any chunk not receiving new logs in this time will be flushed
            max_chunk_age: 1h           # All chunks will be flushed when they hit this age. Def: 1h
            chunk_target_size: 1048576  # Loki will attempt to build chunks up to 1.5MB, flushing first if chunk_idle_period or max_chunk_age is reached first
            chunk_retain_period: 30s    # Must be greater than index read cache TTL if using an index cache (Default index read cache TTL is 5m)
            max_transfer_retries: 0     # Chunk transfers disabled

          schema_config:
            configs:
              - from: 2020-10-24
                store: boltdb-shipper
                object_store: filesystem
                schema: v11
                index:
                  prefix: index_
                  period: 24h

          storage_config:
            boltdb_shipper:
              active_index_directory: /loki/boltdb-shipper-active
              cache_location: /loki/boltdb-shipper-cache
              cache_ttl: 24h         # Can be increased for faster performance over longer query periods, uses more disk space
              shared_store: filesystem
            filesystem:
              directory: /loki/chunks

          compactor:
            working_directory: /loki/boltdb-shipper-compactor
            shared_store: filesystem

          limits_config:
            reject_old_samples: true
            reject_old_samples_max_age: 168h

          chunk_store_config:
            max_look_back_period: 0s

          table_manager:
            retention_deletes_enabled: false
            retention_period: 0s

          ruler:
            storage:
              type: local
              local:
                directory: /loki/rules
            rule_path: /loki/rules-temp
            alertmanager_url: http://localhost:9093
            ring:
              kvstore:
                store: inmemory
            enable_api: true
          EOH
      } // template

      // resources {
      //   cpu    = 100 # MHz
      //   memory = 300 # MB
      // } // resources

    } // task loki
  } // group
} // job
