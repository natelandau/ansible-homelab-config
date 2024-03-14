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
        api_key: "{{ sonarr_api_key }}"
        delete_old_custom_formats: true
        replace_existing_custom_formats: true

        # Quality definitions from the guide to sync to Sonarr. Choices: series, anime
        quality_definition:
            type: series

        quality_profiles:
            - name: "HD - 720p/1080p"
              reset_unmatched_scores:
                  enabled: true
              upgrade:
                  allowed: true
                  until_quality: WEB-1080p
              qualities:
                  - name: Bluray-2160p Remux
                    enabled: false
                  - name: Bluray-2160p
                    enabled: false
                  - name: WEB-2160p
                    enabled: false
                    qualities:
                        - WEBRip-2160p
                        - WEBDL-2160p
                  - name: HDTV-2160p
                    enabled: false
                  - name: Bluray-1080p Remux
                    enabled: false
                  - name: Bluray-1080p
                  - name: WEB-1080p
                    qualities:
                        - WEBRip-1080p
                        - WEBDL-1080p
                  - name: HDTV-1080p
                  - name: Bluray-720p
                    enabled: false
                  - name: WEB-720
                    qualities:
                        - WEBRip-720p
                        - WEBDL-720p
                  - name: HDTV-720p
        custom_formats:
            - trash_ids:
                  - 85c61753df5da1fb2aab6f2a47426b09 # BR-DISK
                  - 9c11cd3f07101cdba90a2d81cf0e56b4 # LQ
                  - e2315f990da2e2cbfc9fa5b7a6fcfe48 # LQ Release Title
                  #   - 47435ece6b99a0b477caf360e79ba0bb # X265
                  - fbcb31d8dabd2a319072b84fc0b7249c # Extras
                  - 32b367365729d530ca1c124a0b180c64 # Bad dual lingual groups
                  - 82d40da2bc6923f41e14394075dd4b03 # No-RlsGroup
              quality_profiles:
                  - name: "HD - 720p/1080p"
                    score: -1000
            - trash_ids:
                  - ec8fa7296b64e8cd390a1600981f3923 # Repack
              quality_profiles:
                  - name: "HD - 720p/1080p"
                    score: 5
            - trash_ids:
                  - eb3d5cc0a2be0db205fb823640db6a3c # Repack2
              quality_profiles:
                  - name: "HD - 720p/1080p"
                    score: 6
            - trash_ids:
                  - 44e7c4de10ae50265753082e5dc76047 # Repack3
              quality_profiles:
                  - name: "HD - 720p/1080p"
                    score: 7
            - trash_ids: # Streaming services, Low Tier
                  - bbcaf03147de0f73be2be4a9078dfa03 # 40D
                  - fcc09418f67ccaddcf3b641a22c5cfd7 # ALL4
                  - 77a7b25585c18af08f60b1547bb9b4fb # CC
                  - f27d46a831e6b16fa3fee2c4e5d10984 # CANALPlus
                  - 4e9a630db98d5391aec1368a0256e2fe # CRAV
                  - 36b72f59f4ea20aad9316f475f2d9fbb # DCU
                  - 7be9c0572d8cd4f81785dacf7e85985e # FOD
                  - 7a235133c87f7da4c8cccceca7e3c7a6 # HBO
                  - f6cce30f1733d5c8194222a7507909bb # HULU
                  - dc503e2425126fa1d0a9ad6168c83b3f # IP
                  - 0ac24a2a68a9700bcb7eeca8e5cd644c # iT
                  - b2b980877494b560443631eb1f473867 # NLZ
                  - fb1a91cdc0f26f7ca0696e0e95274645 # OViD
                  - c30d2958827d1867c73318a5a2957eb1 # Red
                  - ae58039e1319178e6be73caab5c42166 # Sho
                  - d100ea972d1af2150b65b1cffb80f6b5 # TVer
                  - 0e99e7cc719a8a73b2668c3a0c3fe10c # U-next
                  - 5d2317d99af813b6529c7ebf01c83533 # VDL
              quality_profiles:
                  - name: "HD - 720p/1080p"
                    score: 50
            - trash_ids: # Streaming services, second tier
                  - d660701077794679fd59e8bdf4ce3a29 # AMZN
                  - a880d6abc21e7c16884f3ae393f84179 # HMAX
                  - d34870697c9db575f17700212167be23 # NF
                  - 1656adc6d7bb2c8cca6acfb6592db421 # PCOK
                  - c67a75ae4a1715f2bb4d492755ba4195 # PMTP
                  - 3ac5d84fce98bab1b531393e9c82f467 # QIBI
                  - 1efe8da11bfd74fbbcd4d8117ddb9213 # STAN
              quality_profiles:
                  - name: "HD - 720p/1080p"
                    score: 80
            - trash_ids: # Streaming services, Top tier
                  - f67c9ca88f463a48346062e8ad07713f # ATVP
                  - 89358767a60cc28783cdc3d0be9388a4 # DSNP
                  - 81d1fbf600e2540cee87f3a23f9d3c1c # MAX
              quality_profiles:
                  - name: "HD - 720p/1080p"
                    score: 100
            - trash_ids: # HQ Source Groups: Tier 1
                  - e6258996055b9fbab7e9cb2f75819294
              quality_profiles:
                  - name: "HD - 720p/1080p"
                    score: 1700
            - trash_ids: # HQ Source Groups: Tier 2
                  - 58790d4e2fdcd9733aa7ae68ba2bb503
              quality_profiles:
                  - name: "HD - 720p/1080p"
                    score: 1650
            - trash_ids: # HQ Source Groups: Tier 3
                  - d84935abd3f8556dcd51d4f27e22d0a6
              quality_profiles:
                  - name: "HD - 720p/1080p"
                    score: 1600

# Configuration specific to Radarr.
radarr:
    movies:
        base_url: https://radarr.{{ homelab_domain_name }}/
        api_key: "{{ radarr_api_key }}"
        delete_old_custom_formats: true
        replace_existing_custom_formats: true

        # Which quality definition in the guide to sync to Radarr. Only choice right now is 'movie'
        quality_definition:
            type: movie
            preferred_ratio: 0.5

        quality_profiles:
            - name: "720p/1080p"
              reset_unmatched_scores:
                  enabled: true
            - name: "720p/1080p Remux"
              reset_unmatched_scores:
                  enabled: true

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
                    score: -100
                  - name: "720p/1080p Remux"
                    score: -100

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
