job "backup_local_filesystems" {
    region      = "global"
    datacenters = ["{{ datacenter_name }}"]
    type        = "sysbatch"

    periodic {
        cron              = "0 */8 * * * *"
        prohibit_overlap  = true
        time_zone         = "America/New_York"
    }

    task "do_backups" {
        driver = "raw_exec"
        config {
        # When running a binary that exists on the host, the path must be absolute
        command = "${meta.backupCommand}"
        args    = ["${meta.backupCommandArg1}", "${meta.backupCommandArg2}", "${meta.backupCommandArg3}"]
        }
    } // /task do_backups

} //job
