# /lib/systemd/system/@(Package).service
#
# This is a systemd service unit file generated by bloom from the following
# template:
#
# ros-bloom-debhelper/src/my_project/debian/service.em

[Unit]
Description=@(Description)
After=network.target

[Service]
# Package names, as generated by bloom and trimmed here to 32 characters in
# length, are safe to use as user names. This assertion is supported by the
# following references:
#
# > Package names (both source and binary, see Package) must consist only of
# > lower case letters (a-z), digits (0-9), plus (+) and minus (-) signs, and
# > periods (.). They must be at least two characters long and must start with
# > an alphanumeric character.
#
# -- https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-source
#
# > It is usually recommended to only use usernames that begin with a lower
# > case letter or an underscore, followed by lower case letters, digits,
# > underscores, or dashes. They can end with a dollar sign. In regular
# > expression terms: [a-z_][a-z0-9_-]*[$]?
#
# > On Debian, the only constraints are that usernames must neither start with
# > a dash ('-') nor plus ('+') nor tilde ('~') nor contain a colon (':'), a
# > comma (','), or a whitespace (space: ' ', end of line: '\n', tabulation:
# > '\t', etc.). Note that using a slash ('/') may break the default algorithm
# > for the definition of the user's home directory.
#
# > Usernames may only be up to 32 characters long.
#
# -- man 8 useradd
User=@(Name[:32])

# references:
# * https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Capabilities
# * http://man7.org/linux/man-pages/man7/capabilities.7.html
CapabilityBoundingSet=CAP_SYS_NICE
AmbientCapabilities=CAP_SYS_NICE

# https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RuntimeDirectory=
RuntimeDirectory=@(Name)

# systemd version 229 (shipping with Ubuntu Xenial, as of this writing) doesn't
# export the RUNTIME_DIRECTORY env var, so we have to do this:
Environment=RUNTIME_DIRECTORY=/run/@(Name)

# systemd version 229 (shipping with Ubuntu Xenial, as of this writing) doesn't
# have any of the following:
#
#StateDirectory=@(Name)
#CacheDirectory=@(Name)
#LogsDirectory=@(Name)
#ConfigurationDirectory=@(Name)
#
# ...so fake it:

PermissionsStartOnly=true

Environment=STATE_DIRECTORY=/var/lib/@(Name)
Environment=CACHE_DIRECTORY=/var/cache/@(Name)
Environment=LOGS_DIRECTORY=/var/log/@(Name)
Environment=CONFIGURATION_DIRECTORY=/etc/@(Name)

ExecStartPre=/bin/sh -c 'mkdir -vp ${STATE_DIRECTORY}'
ExecStartPre=/bin/sh -c 'mkdir -vp ${CACHE_DIRECTORY}'
ExecStartPre=/bin/sh -c 'mkdir -vp ${LOGS_DIRECTORY}'
ExecStartPre=/bin/sh -c 'mkdir -vp ${CONFIGURATION_DIRECTORY}'

ExecStartPre=/bin/sh -c 'chown -vR ${USER}:${USER} ${STATE_DIRECTORY}'
ExecStartPre=/bin/sh -c 'chown -vR ${USER}:${USER} ${CACHE_DIRECTORY}'
ExecStartPre=/bin/sh -c 'chown -vR ${USER}:${USER} ${LOGS_DIRECTORY}'
ExecStartPre=/bin/sh -c 'chown -vR ${USER}:${USER} ${CONFIGURATION_DIRECTORY}'

# roscpp logging is a stunning and epitomic demonstration of unparalleled bad
# design. You can't stop it. You can't configure its breathtakingly stupid
# imitation of logrotate's file-moving behavior. You can't funnel its
# ever-growing, filesystem-crippling tracts of plaintext into /dev/null. Like
# so much else in the ROS ecosystem, roscpp logging begs the question, "Is this
# _actual_ malice or just a degenerate confluence of weapons-grade ineptitude?"
#
# Here's my attempt at a work-around: override ROS_HOME to a directory under
# /tmp/. This won't stop roscpp from dumping (perhaps) Gigabytes of text into
# your filesystem, but --- assuming your init is smart enough to purge /tmp/ on
# a low drive space condition --- it may prevent a runaway ROS _process_ (not a
# "node", you presumptive fscks) from rendering your rootfs unbootable.
Environment=ROS_HOME=/tmp/@(Package)
ExecStartPre=/bin/sh -c 'rm -rf ${ROS_HOME}'
ExecStart=/bin/sh -c '. @(InstallationPrefix)/setup.sh && env | sort && roslaunch @(Name) main.launch'
ExecStopPost=/bin/sh -c 'rm -rf ${ROS_HOME}'

[Install]
WantedBy=default.target
