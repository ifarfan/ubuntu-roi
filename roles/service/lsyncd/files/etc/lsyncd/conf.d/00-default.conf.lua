--
--  See:
--  - http://axkibe.github.io/lsyncd/manual/config/file/
--  - https://www.stephenrlang.com/2015/12/how-to-install-and-configure-lsyncd/
--
settings {
    logfile        = "/var/log/lsyncd/lsyncd.log",
    statusFile     = "/var/run/lsyncd.status",
    statusInterval = 20,
    nodaemon       = false,
    insist         = true
}
