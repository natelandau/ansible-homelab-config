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
          TZ                 = "America/New_York"
          RECYCLARR_APP_DATA = "/local"
      }

      // user = "${meta.PUID}:${meta.PGID}"
      driver = "docker"
      config {
          image    = "ghcr.io/recyclarr/recyclarr:{{ recyclarr_version }}"
          hostname = "${NOMAD_TASK_NAME}"
          init     = true
      } // docker config

      template {
          destination = "local/recyclarr.yml"
          env         = false
          change_mode = "restart"
          perms       = "644"
          data        = <<-EOH
# yaml-language-server: $schema=https://raw.githubusercontent.com/recyclarr/recyclarr/master/schemas/config-schema.json

# A starter config to use with Recyclarr. Most values are set to "reasonable defaults". Update the
# values below as needed for your instance. You will be required to update the API Key and URL for
# each instance you want to use.
#
# Many optional settings have been omitted to keep this template simple. Note that there's no "one
# size fits all" configuration. Please refer to the guide to understand how to build the appropriate
# configuration based on your hardware setup and capabilities.
#
# For any lines that mention uncommenting YAML, you simply need to remove the leading hash (`#`).
# The YAML comments will already be at the appropriate indentation.
#
# For more details on the configuration, see the Configuration Reference on the wiki here:
# https://recyclarr.dev/wiki/reference/config-reference

# Configuration specific to Sonarr
sonarr:
    series:
        base_url: https://sonarr.{{ homelab_domain_name }}/
        api_key: {{ sonarr_api_key }}
        delete_old_custom_formats: true

        # Quality definitions from the guide to sync to Sonarr. Choices: series, anime
        quality_definition:
            type: series

        # Release profiles from the guide to sync to Sonarr v3 (Sonarr v4 does not use this!)
        # Use `recyclarr list release-profiles` for values you can put here.
        # https://trash-guides.info/Sonarr/Sonarr-Release-Profile-RegEx/
        release_profiles:
            - trash_ids:
                  - EBC725268D687D588A20CBC5F97E538B # Low Quality Groups
                  - 1B018E0C53EC825085DD911102E2CA36 # Release Sources (Streaming Service)
                  - 71899E6C303A07AF0E4746EFF9873532 # P2P Groups + Repack/Proper
              strict_negative_scores: false

            - trash_ids:
                  - 76e060895c5b8a765c310933da0a5357 # Optionals
              filter:
                  include:
                      - cec8880b847dd5d31d29167ee0112b57 # Golden rule
                      - 436f5a7d08fbf02ba25cb5e5dfe98e55 # Ignore Dolby Vision without HDR10 fallback.
                      #   - f3f0f3691c6a1988d4a02963e69d11f2 # Ignore The Group -SCENE
                      #   - 5bc23c3a055a1a5d8bbe4fb49d80e0cb # Ignore so called scene releases
                      - 538bad00ee6f8aced8e0db5218b8484c # Ignore Bad Dual Audio Groups
                      - 4861d8238f9234606df6721df6e27deb # Ignore AV1
                      - bc7a6383cbe88c3ee2d6396e1aacc0b3 # Prefer HDR
                      - 6f2aefa61342a63387f2a90489e90790 # Dislike retags: rartv, rarbg, eztv, TGx
                      - 19cd5ecc0a24bf493a75e80a51974cdd # Dislike retagged groups
                      - 6a7b462c6caee4a991a9d8aa38ce2405 # Dislike release ending: en
                      - 236a3626a07cacf5692c73cc947bc280 # Dislike release containing: 1-
                      #   - fa47da3377076d82d07c4e95b3f13d07 # Prefer Dolby Vision

# Configuration specific to Radarr.
radarr:
    movies:
        # Set the URL/API Key to your actual instance
        base_url: https://radarr.{{ homelab_domain_name }}/
        api_key: {{ radarr_api_key }}
        delete_old_custom_formats: true
        replace_existing_custom_formats: true

        # Which quality definition in the guide to sync to Radarr. Only choice right now is 'movie'
        quality_definition:
            type: movie
            preferred_ratio: 0.5

        quality_profiles:
            - name: "720p/1080p"
              reset_unmatched_scores: true
            - name: "720p/1080p Remux"
              reset_unmatched_scores: true

        custom_formats:
            # Use `recyclarr list custom-formats radarr` for values you can put here.
            # https://trash-guides.info/Radarr/Radarr-collection-of-custom-formats/

            - trash_ids:
                  # Movie versions
                  - eca37840c13c6ef2dd0262b141a5482f # 4K Remaster
                  - 570bc9ebecd92723d2d21500f4be314c # Remaster
                  - 0f12c086e289cf966fa5948eac571f44 # Hybrid
                  - 9d27d9d2181838f76dee150882bdc58c # Masters of Cinema
                  - e0c07d59beb37348e975a930d5e50319 # Criterion Collection
                  - 957d0f44b592285f26449575e8b1167e # Special Edition
                  - eecf3a857724171f968a66cb5719e152 # IMAX
                  - 9f6cbff8cfe4ebbc1bde14c7b7bec0de # IMAX Enhanced
                  # Unwanted
                  - b8cd450cbfa689c0259a01d9e29ba3d6 # 3D
                  - ed38b889b31be83fda192888e2286d83 # BR-DISK
                  - 90a6f9a284dff5103f6346090e6280c8 # LQ
                  - bfd8eb01832d646a0a89c4deb46f8564 # Upscaled
                  - 90cedc1fea7ea5d11298bebd3d1d3223 # EVO (no WEBDL)
                  - 923b6abef9b17f937fab56cfcf89e1f1 # DV (WEBDL)
                  - b6832f586342ef70d9c128d40c07b872 # Bad Dual Groups
                  - ae9b7c9ebde1f3bd336a8cbd1ec4c5e5 # No-RlsGroup
                  - 7357cf5161efbf8c4d5d0c30b4815ee2 # Obfuscated
                  - 5c44f52a8714fdd79bb4d98e2673be1f # Retags
                  - c465ccc73923871b3eb1802042331306 # Line/Mic Dubbed
                  # Misc
                  - e7718d7a3ce595f289bfee26adc178f5 # Repack/Proper
                  - ae43b294509409a6a13919dedd4764c4 # Repack2
                  # HQ Release Groups
                  - ed27ebfef2f323e964fb1f61391bcb35 # HD Bluray Tier 01
                  - c20c8647f2746a1f4c4262b0fbbeeeae # HD Bluray Tier 02
                  - c20f169ef63c5f40c2def54abaf4438e # WEB Tier 01
                  - 403816d65392c79236dcb6dd591aeda4 # WEB Tier 02
                  - af94e0fe497124d1f9ce732069ec8c3b # WEB Tier 03
              quality_profiles:
                  - name: "720p/1080p"
                  - name: "720p/1080p Remux"

            # HDR FORMATS
            # ########################
            - trash_ids:
                  - 3a3ff47579026e76d6504ebea39390de # Remux Tier 01
                  - 9f98181fe5a3fbeb0cc29340da2a468a # Remux Tier 02
                  - e61e28db95d22bedcadf030b8f156d96 # HDR
                  - 2a4d9069cc1fe3242ff9bdaebed239bb # HDR (undefined)
              quality_profiles:
                  - name: "720p/1080p"
                    score: -100
                  - name: "720p/1080p Remux"

            # AUDIO FORMATS
            # ########################
            - trash_ids:
                  - 6fd7b090c3f7317502ab3b63cc7f51e3 # 6.1 Surround
                  - e77382bcfeba57cb83744c9c5449b401 # 7.1 Surround
                  - f2aacebe2c932337fe352fa6e42c1611 # 9.1 Surround
              quality_profiles:
                  - name: "720p/1080p"
                    score: -50
                  - name: "720p/1080p Remux"
                    score: -50

            - trash_ids:
                  - 89dac1be53d5268a7e10a19d3c896826 # 2.0 Stereo
              quality_profiles:
                  - name: "720p/1080p"
                    score: 120

            - trash_ids:
                  - 77ff61788dfe1097194fd8743d7b4524 # 5.1 Surround
              quality_profiles:
                  - name: "720p/1080p"
                    score: 80
                  - name: "720p/1080p Remux"
                    score: 80
              EOH
      }


      resources {
          cpu    = 100 # MHz
          memory = 300 # MB
      } // resources

    } // task


  } // group


} // job
