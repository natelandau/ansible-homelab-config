job "pihole" {
  region      = "global"
  datacenters = ["{{ datacenter_name }}"]
  type        = "service"

  constraint {
    attribute = "${node.unique.name}"
    operator  = "regexp"
    value     = "rpi(2|3)"
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

  group "pihole-group" {

    network {
      port "web" {
        static = "80"
        to     = "80"
      }
      port "dns" {
        static = "53"
        to     = "53"
      }
      // port "dhcp" {
      //   static = "67"
      //    to = "67"
      // }
    }

    task "await_filesystem" {
      driver = "docker"

      config {
        image        = "busybox:latest"
        command      = "sh"
        network_mode = "host"
        args = [
          "-c",
          "echo -n 'Waiting for /mnt/pi-cluster/pihole5 to be mounted'; until [ -f /etc/pihole/gravity.db ]; do echo '.'; sleep 2; done",
        ]
        volumes = [
          "/mnt/pi-cluster/pihole5:/etc/pihole/"
        ]
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    } // /await-filesystem

    task "pihole" {
      env {
        // REV_SERVER_DOMAIN   = ""
        ADMIN_EMAIL         = "{{ my_email_address }}"
        DHCP_ACTIVE         = "false"
        DNS_BOGUS_PRIV      = "false"
        DNS_FQDN_REQUIRED   = "false"
        DNSSEC              = "false"
        FTLCONF_REPLY_ADDR4 = "${attr.unique.network.ip-address}"
        IPv6                = "false"
        PIHOLE_DNS_         = "10.0.30.1#53"
        QUERY_LOGGING       = "true"
        REV_SERVER          = "true"
        REV_SERVER_CIDR     = "10.0.0.0/16"
        REV_SERVER_TARGET   = "10.0.30.1"
        TEMPERATUREUNIT     = "f"
        TZ                  = "America/New_York"
        WEBTHEME            = "default-light"
        WEBUIBOXEDLAYOUT    = "traditional"
      }

      driver = "docker"
      config {
        image    = "pihole/pihole:latest"
        hostname = "${NOMAD_JOB_NAME}"
        dns_servers = [
          "127.0.0.1",
          "1.1.1.1"
        ]
        extra_hosts = [
          "laptopVPN:10.0.90.2",
          "FiddleStixPhoneVPN:10.0.90.3"
        ]
        volumes = [
          "${meta.nfsStorageRoot}/pi-cluster/pihole5:/etc/pihole/",
          "${meta.nfsStorageRoot}/pi-cluster/pihole5/dnsmasq.d:/etc/dnsmasq.d/"
          // "${meta.nfsStorageRoot}/pi-cluster/pihole5/logs/pihole.log:/var/log/pihole.log",
          // "${meta.nfsStorageRoot}/pi-cluster/pihole5/logs/pihole-FTL.log:/var/log/pihole-FTL.log"
        ]
        ports = ["web", "dns"]
      }

      resources {
        cpu    = 400 # MHz
        memory = 80  # MB
      }

      service {
        name = "${NOMAD_JOB_NAME}"
        port = "web"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`p.{{ homelab_domain_name }}`)",
          "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=web,websecure",
          "traefik.http.routers.${NOMAD_JOB_NAME}.service=${NOMAD_JOB_NAME}",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_JOB_NAME}.tls.certresolver=cloudflare",
          "traefik.http.middlewares.piholeRedirect.redirectregex.regex=^(https?://p\\.{{ homelab_domain_name }})/?$",
          "traefik.http.middlewares.piholeRedirect.redirectregex.replacement=$${1}/admin/",
          "traefik.http.routers.${NOMAD_JOB_NAME}.middlewares=piholeRedirect"
        ]
        check {
          type     = "http"
          path     = "/admin/"
          port     = "web"
          interval = "30s"
          timeout  = "2s"
        }
        check_restart {
          limit           = 3
          grace           = "10m"
        }
      }

      service {
        name = "piholeDNStcp"
        port = "dns"
        provider = "nomad"
        check {
          type     = "tcp"
          port     = "dns"
          interval = "30s"
          timeout  = "2s"
        }
        check_restart {
          limit           = 3
          grace           = "60s"
          ignore_warnings = false
        }
      }

    }
  } // group
}
