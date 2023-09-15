job "valentina" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "service"

    // constraint {
    //     attribute = "${node.unique.name}"
    //     operator  = "regexp"
    //     value     = "rpi(1|2|3)"
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

  group "valentina" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    task "valentina" {

      env {
            PGID                            = "${meta.PGID}"
            PUID                            = "${meta.PUID}"
            TZ                              = "America/New_York"
            VALENTINA_AWS_ACCESS_KEY_ID     = "{{ valentina_aws_access_key_id }}"
            VALENTINA_AWS_SECRET_ACCESS_KEY = "{{ valentina_aws_secret_access_key }}"
            VALENTINA_DISCORD_TOKEN         = "{{ valentina_discord_token }}"
            VALENTINA_GUILDS                = "{{ valentina_guids }}"
            VALENTINA_LOG_LEVEL             = "DEBUG"
            VALENTINA_LOG_LEVEL_AWS         = "INFO"
            VALENTINA_OWNER_CHANNELS        = "{{ valentina_owner_channels }}"
            VALENTINA_OWNER_IDS             = "{{ valentina_owner_ids }}"
            VALENTINA_S3_BUCKET_NAME        = "{{ valentina_s3_bucket_name}}"
      }

      driver = "docker"
      config {
          image    = "ghcr.io/natelandau/valentina:v{{valentina_version}}"
          hostname = "${NOMAD_TASK_NAME}"
          volumes  = [
            "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_TASK_NAME}:/valentina",
          ]
      } // docker config

      // resources {
      //     cpu    = 100 # MHz
      //     memory = 300 # MB
      // } // resources

    } // task


  } // group


} // job
