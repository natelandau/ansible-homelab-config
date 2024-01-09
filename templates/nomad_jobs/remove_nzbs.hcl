job "remove_nzbs" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "batch"

    constraint {
        attribute = "${node.unique.name}"
        operator  = "regexp"
        value     = "rpi"
    }

    periodic {
        cron              = "*/15 * * * * *"
        prohibit_overlap  = true
        time_zone         = "America/New_York"
    }

    task "remove_nzbs" {
        driver = "raw_exec"
        config {
            command = "/home/pi/.pyenv/shims/python"
            args    = ["/home/pi/repos/bin/bin-sabnzbd/removeNZBs.py"]
        }

    } // /task do_backups

} //job
