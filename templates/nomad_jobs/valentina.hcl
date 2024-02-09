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
                VALENTINA_LOG_LEVEL             = "INFO"
                VALENTINA_LOG_LEVEL_AWS         = "INFO"
                VALENTINA_LOG_LEVEL_HTTP        = "ERROR"
                VALENTINA_MONGO_DATABASE_NAME   = "{{ valentina_mongo_database_name }}"
                VALENTINA_MONGO_URI             = "{{ valentina_mongo_uri }}"
                VALENTINA_OWNER_CHANNELS        = "{{ valentina_owner_channels }}"
                VALENTINA_OWNER_IDS             = "{{ valentina_owner_ids }}"
                VALENTINA_S3_BUCKET_NAME        = "{{ valentina_s3_bucket_name}}"
                VALENTINA_GITHUB_TOKEN          = "{{ valentina_github_token }}"
                VALENTINA_GITHUB_REPO           = "{{ valentina_github_repo }}"
            }
            driver = "docker"
            config {
                image              = "ghcr.io/natelandau/valentina:v{{ valentina_version }}"
                image_pull_timeout = "10m"
                hostname           = "${NOMAD_TASK_NAME}"
                volumes            = [
                    "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_TASK_NAME}:/valentina",
                ]
            } // docker config

        // resources {
        //     cpu    = 100 # MHz
        //     memory = 300 # MB
        // } // resources

        } // task


    } // group

    group "mongobackup" {

        count = 1

        restart {
            attempts = 0
            delay    = "30s"
        }

        network {
            port "port1" {
                to     = "80"
            }
        }

        constraint {
            attribute = "${attr.cpu.arch}"
            value     = "amd64"
        }

        task "mongobackup" {

            env {
                    PUID                  = "${meta.PUID}"
                    PGID                  = "${meta.PGID}"
                    TZ                    = "America/New_York"
                    AWS_ACCESS_KEY_ID     = "{{ valentina_aws_access_key_id }}"
                    AWS_S3_BUCKET_NAME    = "{{ valentina_s3_bucket_name }}"
                    AWS_S3_BUCKET_PATH    = "db_backups"
                    AWS_SECRET_ACCESS_KEY = "{{ valentina_aws_secret_access_key }}"
                    BACKUP_DIR            = "/data/db_backups"
                    CRON_SCHEDULE         = "0 2 * * *" # 2am daily
                    // CRON_SCHEDULE         = "*/1 * * * *" # Every minute
                    DAILY_RETENTION       = "7"
                    DB_NAME               = "{{ backup_mongo_db_name }}"
                    LOG_FILE              = "/data/backup_mongodb.log"
                    LOG_LEVEL             = "INFO"
                    MONGODB_URI           = "{{ backup_mongo_mongodb_uri }}"
                    MONTHLY_RETENTION     = "12"
                    PORT                  = "80"
                    STORAGE_LOCATION      = "BOTH"
                    WEEKLY_RETENTION      = "4"
                    YEARLY_RETENTION      = "2"
            }

            driver = "docker"
            config {
                image              = "ghcr.io/natelandau/backup-mongodb:v{{ backup_mongodb_version }}"
                image_pull_timeout = "10m"
                hostname           = "${NOMAD_TASK_NAME}"
                ports              = ["port1"]
                volumes            = ["${meta.nfsStorageRoot}/pi-cluster/valentina:/data"]
            } // docker config

            service {
                port     = "port1"
                name     = "${NOMAD_TASK_NAME}"
                provider = "nomad"
                tags     = [
                    "traefik.enable=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${NOMAD_TASK_NAME}.{{ homelab_domain_name }}`)",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.entryPoints=web,websecure",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.service=${NOMAD_TASK_NAME}",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=cloudflare",
                    ]

                check {
                    type     = "tcp"
                    port     = "port1"
                    interval = "1m"
                    timeout  = "4s"
                }

                check_restart {
                    limit           = 0
                    grace           = "1m"
                }
            } // service

        } // task
    } // group
} // job
