job "wikijs" {
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

  group "wikijs_db_group" {

    restart {
      attempts = 1
      delay    = "30s"
    }

    network {
      port "db" {
        static = "5434"
        to = "5432"
      }
    }

    task "await_db_filesystem" {

      constraint {
        attribute = "${node.unique.name}"
        value     = "macmini"
      }

        driver = "docker"

        config {
          image        = "busybox:latest"
          command      = "sh"
          args         = [
            "-c",
            "echo -n 'Waiting for /etc/postgresql/postgresql.conf to be available'; until [ -f /etc/postgresql/my-postgres.conf ]; do echo '.'; sleep 2; done",
            ]
          network_mode = "host"
          volumes = [
            "/Users/{{ my_username }}/cluster/wikidb:/etc/postgresql"
          ]
        }

        lifecycle {
          hook    = "prestart"
          sidecar = false
        }
    } // /task

    task "await_backup_filesystem" {

      constraint {
        attribute = "${node.unique.name}"
        value     = "macmini"
      }

        driver = "docker"

        config {
          image        = "busybox:latest"
          command      = "sh"
          args         = [
            "-c",
            "echo -n 'Waiting for /backups to be available'; until [ -f /backups/dbBackup.log ]; do echo '.'; sleep 2; done",
            ]
          network_mode = "host"
          volumes = [
            "${meta.nfsStorageRoot}/pi-cluster/backups/wikijsdb:/backups"
          ]
        }

        lifecycle {
          hook    = "prestart"
          sidecar = false
        }
    } // /task

    task "wikijs_db" {

      constraint {
        attribute = "${node.unique.name}"
        value     = "macmini"
      }

      env {
          PUID              = "${meta.PUID}"
          PGID              = "${meta.PGID}"
          TZ                = "America/New_York"
          POSTGRES_USER     = "wikijs"
          POSTGRES_PASSWORD = "wikijs"
          POSTGRES_DB       = "wikijs"
          PGDATA            = "/var/lib/postgresql/data/pgdata"
      }

      driver = "docker"
      config {
        image = "postgres:9.6.17"
        hostname = "wikijs_db"
        volumes = [
          "/Users/{{ my_username }}/cluster/wikidb/pgdata:/var/lib/postgresql/data",
          "/Users/{{ my_username }}/cluster/wikidb/my-postgres.conf:/etc/postgresql/postgresql.conf",
          "/Users/{{ my_username }}/cluster/wikidb/entrypoint:/docker-entrypoint-initdb.d",
          "${meta.nfsStorageRoot}/pi-cluster/backups/wikijsdb:/backups"
        ]
        ports = ["db"]
      }

      artifact {
        source      = "git::https://github.com/{{ my_username }}/db_scripts.git"
        destination = "local/scripts"
      }

      service {
        port = "db"
        name = "wikijsdb"
        provider = "nomad"
        check {
          type     = "tcp"
          port     = "db"
          interval = "30s"
          timeout  = "4s"
        }
        check_restart {
          limit = 2
          grace = "1m"
        }
      }

      resources {
        cpu    = 55 # MHz
        memory = 60 # MB
      }

    } // /task
  } // /group

group "wikijs_app_group" {

  restart {
    attempts = 1
    delay    = "30s"
  }

  network {
    port "http" {
      to = "3000"
    }
  }

  task "await_database" {
    driver = "docker"

    config {
      image        = "busybox:latest"
      command      = "sh"
      args         = [
        "-c",
        "echo -n 'Waiting for wikijsdb.service.consul to come alive'; until nslookup wikijsdb.service.consul 2>&1 >/dev/null; do echo '.'; sleep 2; done"
        ]
      network_mode = "host"
    }

    resources {
      cpu    = 200
      memory = 128
    }

    lifecycle {
      hook    = "prestart"
      sidecar = false
    }
  } // /task

  task "await_filesystem" {
      driver = "docker"

      config {
        image        = "busybox:latest"
        command      = "sh"
        args         = [
          "-c",
          "echo -n 'Waiting for ${meta.nfsStorageRoot}/pi-cluster/wikijs/ to be mounted'; until less -E /wiki/config.yml | grep 'wikijsdb.service.consul' 2>&1 >/dev/null; do echo '.'; sleep 2; done",
          ]
        network_mode = "host"
        volumes = [
          "${meta.nfsStorageRoot}/pi-cluster/wikijs/config/config.yml:/wiki/config.yml"
        ]
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
  } // /task

  task "wikijs_app" {

    env {
      PUID              = "${meta.PUID}"
      PGID              = "${meta.PGID}"
      TZ                = "America/New_York"
    }

    driver = "docker"
    config {
      image = "linuxserver/wikijs:version-2.5.170"
      hostname = "wikijs-app"
      volumes = [
        "${meta.nfsStorageRoot}/pi-cluster/wikijs/config/config.yml:/wiki/config.yml",
        "${meta.nfsStorageRoot}/pi-cluster/wikijs/config:/config",
        "${meta.nfsStorageRoot}/pi-cluster/wikijs/data/:/data"
      ]
      ports = ["http"]
    } // /config

    service {
      port = "http"
      name = "wikijs"
      provider = "nomad"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.wikijs.rule=Host(`wiki.{{ homelab_domain_name }}`)",
        "traefik.http.routers.wikijs.entryPoints=web,websecure",
        "traefik.http.routers.wikijs.service=wikijs",
        "traefik.http.routers.wikijs.tls=true"
        ]
      check {
        type     = "http"
        path     = "/"
        interval = "90s"
        timeout  = "15s"
      }
      check_restart {
        limit = 3
        grace = "30s"
      }
    } // /service

    resources {
      // cpu    = 100 # MHz
      // memory = 60 # MB
    }


    } // /task
  } // /group

} // job
