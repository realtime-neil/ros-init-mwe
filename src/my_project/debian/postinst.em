#!/bin/sh

# @(Package) postinst script

# This file is an amalgamation of the following package contents:
#
# * dh-make_2.201701_all/usr/share/debhelper/dh_make/debian/postinst.ex
# * dh-sysuser_1.3.1_all/usr/share/debhelper/autoscripts/postinst-sysuser
# * sysuser-helper_1.3.1_all/lib/sysuser-helper/sysuser-helper
#
# They were harvested on 2019.09.24 from an Ubuntu Bionic host via
#
#     $ apt-get download dh-make dh-sysuser sysuser-helper
#
# The dh-make `postinst.ex` is an example file. The other files have been
# pilfered because --- while the packages `dh-sysuser` and `sysuser-helper` are
# available for Ubuntu Bionic --- they are not available for Ubuntu Xenial.
#
# References:
#
# * https://unix.stackexchange.com/questions/47880/how-debian-package-should-create-user-accounts/147123#147123
# * https://wiki.debian.org/AccountHandlingInMaintainerScripts
# * https://www.tldp.org/LDP/www.debian.org/doc/manuals/securing-debian-howto/ch9.en.html#fr64
# * https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=81697
# * https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=291177
# * https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=118787
# * https://packages.ubuntu.com/source/bionic/dh-sysuser
# * https://packages.ubuntu.com/bionic/dh-sysuser
# * https://packages.ubuntu.com/bionic/sysuser-helper
# * https://medium.com/opsops/dh-sysuser-6bd3e3d623dd
# * https://www.debian.org/doc/debian-policy/ch-maintainerscripts.html

set -eu

readonly this="$(readlink -f "$0")"
readonly whatami="$(basename "${this}")"

readonly package="@(Package)"
readonly project="@(Name)"
readonly systemd_service_file="/lib/systemd/system/${package}.service"
readonly sysuser_name="$(echo "${project}" | cut -c-32)"
readonly sysuser_home="/nonexistent"
readonly udev_rules_file="/lib/udev/rules.d/60-${package}.rules"

log() { echo "${whatami}: $*" >&2; }
error() { log "ERROR: $*"; }
warning() { log "WARNING: $*"; }
info() { log "INFO: $*"; }
die() {
    error "$*"
    exit 1
}

################################################################################

#################
# SYSUSER BEGIN #
#################

# The section "Automatically added by dh_systemd_start" (re)starts the
# service which requires a sysuser. Add the sysuser first.
if [ "configure" = "$1" ]; then
    if [ -f "${systemd_service_file}" ]; then
        info "${systemd_service_file} exists; checking sysuser..."
        if getent passwd "${sysuser_name}" >/dev/null 2>&1; then
            info "extant sysuser: $(getent passwd "${sysuser_name}")"
        else
            # Create home directory for system user, unless it is /nonexistent
            # which must stay nonexistent.
            emptydir="$(mktemp -d)" # to inhibit /etc/skel
            if [ "/nonexistent" = "${sysuser_home}" ]; then
                useradd --system --shell /usr/sbin/nologin \
                    "${sysuser_name}"
            else
                useradd --system --shell /usr/sbin/nologin \
                    --create-home --skel "${emptydir}" --home-dir "${sysuser_home}" \
                    "${sysuser_name}"
            fi
            rmdir "${emptydir}"
            info "created sysuser: $(getent passwd "${sysuser_name}")"
        fi
        # If user already have another home directory, we use `usermod
        # --move-home'. Unfortunately, new home is required to be non-existent
        # (and different from previous), so this conditional is required.
        if ! [ -d "${sysuser_home}" ]; then
            usermod --move-home --home "${sysuser_home}" "${sysuser_name}"
        fi
        for group in adm systemd-journal; do
            if ! getent group "${group}" >/dev/null 2>&1; then
                warning "missing group: ${group}"
                continue
            fi
            if ! usermod --append --groups "${group}" "${sysuser_name}"; then
                die "FAILURE: usermod --append --groups ${group} ${sysuser_name}"
            fi
        done
        info "groups: $(groups "${sysuser_name}")"
    else
        info "${systemd_service_file} does not exist; skipping sysuser"
    fi
fi

###############
# SYSUSER END #
###############

################################################################################

#DEBHELPER#

################################################################################

##############
# UDEV BEGIN #
##############

# The section "Automatically added by dh_installudev" attempts to preserve user
# changes to udev rules under /etc/udev/rules.d. Bounce udev after that
if [ "configure" = "$1" ]; then
    if [ -f "${udev_rules_file}" ]; then
        info "${udev_rules_file} exists; checking udev bounce..."
        if ischroot; then
            warning "chroot detected, skipping udev bounce"
        else
            if ! udevadm control --reload-rules; then
                die "FAILURE: udevadm control --reload-rules"
            fi
            if ! udevadm trigger; then
                die "FAILURE: udevadm trigger"
            fi
            info "udev bounced"
        fi
    else
        info "${udev_rules_file} does not exist; skipping udev bounce"
    fi
fi
############
# UDEV END #
############

################################################################################

exit 0
