job "recyclarr" {
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

  group "recyclarr" {

    count = 1

    restart {
        attempts = 0
        delay    = "30s"
    }

    task "recyclarr" {

      env {
          TZ          = "America/New_York"
      }

      // user = "${meta.PUID}:${meta.PGID}"
      driver = "docker"
      config {
          image    = "ghcr.io/recyclarr/recyclarr"
          hostname = "${NOMAD_TASK_NAME}"
          init     = true
          volumes  = [
            "${meta.nfsStorageRoot}/pi-cluster/${NOMAD_TASK_NAME}:/config"
          ]
      } // docker config

      // template {
      //     destination = "local/recyclarr.yml"
      //     env         = false
      //     change_mode = "restart"
      //     perms       = "644"
      //     data        = <<-EOH
      //         ---
      //         # yaml-language-server: $schema=https://raw.githubusercontent.com/recyclarr/recyclarr/master/schemas/config-schema.json

      //         # A starter config to use with Recyclarr. Most values are set to "reasonable defaults". Update the
      //         # values below as needed for your instance. You will be required to update the API Key and URL for
      //         # each instance you want to use.
      //         #
      //         # Many optional settings have been omitted to keep this template simple.
      //         #
      //         # For more details on the configuration, see the Configuration Reference on the wiki here:
      //         # https://github.com/recyclarr/recyclarr/wiki/Configuration-Reference

      //         # Configuration specific to Sonarr
      //         sonarr:
      //           # Set the URL/API Key to your actual instance

      //           {% raw -%}
      //           - base_url: http://{{ range service "sonarr" }}{{ .Address }}:{{ .Port }}{{ end }}
      //             api_key: f7e74ba6c80046e39e076a27af5a8444
      //           {% endraw -%}

      //             # Quality definitions from the guide to sync to Sonarr. Choice: anime, series, hybrid
      //             quality_definition: series

      //             # Release profiles from the guide to sync to Sonarr.
      //             # You can optionally add tags and make negative scores strictly ignored
      //             release_profiles:
      //               # Series
      //               - trash_ids:
      //                   - EBC725268D687D588A20CBC5F97E538B # Low Quality Groups
      //                   - 1B018E0C53EC825085DD911102E2CA36 # Release Sources (Streaming Service)
      //                   - 71899E6C303A07AF0E4746EFF9873532 # P2P Groups + Repack/Proper
      //               # Anime (Uncomment below if you want it)
      //         #      - trash_ids:
      //         #          - d428eda85af1df8904b4bbe4fc2f537c # Anime - First release profile
      //         #          - 6cd9e10bb5bb4c63d2d7cd3279924c7b # Anime - Second release profile

      //         # Configuration specific to Radarr.
      //         radarr:
      //           # Set the URL/API Key to your actual instance
      //           {% raw -%}
      //           - base_url: http://{{ range service "radarr" }}{{ .Address }}:{{ .Port }}{{ end }}
      //             api_key: f7e74ba6c80046e39e076a27af5a8444
      //           {% endraw -%}

      //             # Which quality definition in the guide to sync to Radarr. Only choice right now is 'movie'
      //             quality_definition:
      //               type: movie

      //             # Set to 'true' to automatically remove custom formats from Radarr when they are removed from
      //             # the guide or your configuration. This will NEVER delete custom formats you manually created!
      //             delete_old_custom_formats: false

      //             custom_formats:
      //               # A list of custom formats to sync to Radarr. Must match the "trash_id" in the guide JSON.
      //               - trash_ids:
      //                   - ed38b889b31be83fda192888e2286d83 # BR-DISK
      //                   - 90cedc1fea7ea5d11298bebd3d1d3223 # EVO (no WEBDL)
      //                   - 90a6f9a284dff5103f6346090e6280c8 # LQ
      //                   - dc98083864ea246d05a42df0d05f81cc # x265 (720/1080p)
      //                   - b8cd450cbfa689c0259a01d9e29ba3d6 # 3D

      //                 # Uncomment the below properties to specify one or more quality profiles that should be
      //                 # updated with scores from the guide for each custom format. Without this, custom formats
      //                 # are synced to Radarr but no scores are set in any quality profiles.
      //         #        quality_profiles:
      //         #          - name: Quality Profile 1
      //         #          - name: Quality Profile 2
      //         #            #score: -9999 # Optional score to assign to all CFs. Overrides scores in the guide.
      //         #            #reset_unmatched_scores: true # Optionally set other scores to 0 if they are not listed in 'names' above.
      //         EOH
      // }


      // resources {
      //     cpu    = 100 # MHz
      //     memory = 300 # MB
      // } // resources

    } // task


  } // group


} // job
