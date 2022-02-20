job "icloud_backup" {
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

  group "icloud_backup" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    task "icloud_backup" {

      env {
          PUID        = "${meta.PUID}"
          PGID        = "${meta.PGID}"
          TZ          = "America/New_York"
      }

      driver = "docker"
      config {
          image    = "mandarons/icloud-drive"
          hostname = "${NOMAD_TASK_NAME}"
          volumes  = [
            "${meta.nfsStorageRoot}/nate/icloud_backup:/app/icloud",
            "local/icloud_backup.yaml:/app/config.yaml",
            "/etc/timezone:/etc/timezone:ro",
            "/etc/localtime:/etc/localtime:ro"
          ]
      } // docker config

          template {
              destination = "local/icloud_backup.yaml"
              env         = false
              change_mode = "restart"
              perms       = "644"
              data        = <<-EOH
                app:
                  logger:
                    # level - debug, info, warning (default) or error
                    level: "info"
                    # log filename icloud.log (default)
                    filename: "icloud.log"
                  credentials:
                    # iCloud drive username
                    username: "{{ icloud_backup_username }}"
                    # Retry login interval - default is 10 minutes
                    retry_login_interval: 600
                  # Drive destination
                  root: "icloud"
                  smtp:
                    # If you want to recieve email notifications about expired/missing 2FA credentials then uncomment
                    email: "{{ email_smtp_account }}"
                    password: "{{ icloud_backup_smtp_password }}"
                    host: "{{ email_smtp_host }}"
                    port: {{ email_smtp_port }}
                    # If your email provider doesn't handle TLS
                    no_tls: false
                drive:
                  destination: "drive"
                  remove_obsolete: true
                  sync_interval: 1440
                  filters:
                    # File filters to be included in syncing iCloud drive content
                    folders:
                      - "Scanner By Readdle"
                      # - "folder2"
                      # - "folder3"
                    file_extensions:
                      # File extensions to be included
                      - "pdf"
                      - "png"
                      - "jpg"
                      - "jpeg"
                      - "xls"
                      - "xlsx"
                      - "docx"
                      - "pptx"
                      - "txt"
                      - "md"
                      - "html"
                      - "htm"
                      - "css"
                      - "js"
                      - "json"
                      - "xml"
                      - "yaml"
                      - "yml"
                      - "csv"
                      - "mp3"
                      - "mp4"
                      - "mov"
                      - "wav"
                      - "mkv"
                      - "m4a"
                photos:
                  destination: "photos"
                  remove_obsolete: false
                  sync_inteval: 720
                  filters:
                    albums:
                      - "offline_backup"
                      - "All Favorites"
                    file_sizes: # valid values are original, medium and/or thumb
                      - "original"
                      # - "medium"
                      # - "thumb"
                EOH
          } // template data

      // resources {
      //     cpu    = 100 # MHz
      //     memory = 300 # MB
      // } // resources

    } // task


  } // group


} // job
