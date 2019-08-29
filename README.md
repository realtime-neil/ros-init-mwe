ros-bloom-debhelper
===================

[`bloom`][bloom] your [ROS][ros] projects with the full power of
[`debhelper`][debhelper].

# tldr

    $ tree ~/my_catkin_ws
    /home/user/my_catkin_ws
    `-- src
        `-- my_project
            |-- CMakeLists.txt
            |-- debian
            |   |-- cron.daily.em
            |   |-- logrotate.em
            |   |-- service.em
            |   `-- udev.em
            |-- etc
            |   `-- rsyslog.d
            |       `-- 99-slug.conf.in
            |-- package.xml
            `-- src
                `-- main.cpp

    $ bloom-release --rosdistro melodic ...
    ...
    $ git clone file:///path/to/my_catkin_ws-release.git
    ...
    $ cd my_catkin_ws-release
    $ git checkout debian/melodic/bionic/my_project
    $ gbp buildpackage -us -uc --source-option='-i.*'
    ...
    $ dpkg-deb -R ../ros-melodic-my-project_0.0.1_amd64.deb ../ros-melodic-my-project_0.0.1_amd64.deb.raw
    $ tree ../ros-melodic-my-project_0.0.1_amd64.deb.raw
    ../ros-melodic-my-project_0.0.1_amd64.deb.raw/
    |-- DEBIAN
    |   |-- conffiles
    |   |-- control
    |   |-- md5sums
    |   |-- postinst
    |   |-- postrm
    |   |-- preinst
    |   `-- prerm
    |-- etc
    |   |-- cron.daily
    |   |   `-- ros-melodic-my-project
    |   |-- logrotate.d
    |   |   `-- ros-melodic-my-project
    |   `-- rsyslog.d
    |       `-- 99-ros-melodic-my-project.conf
    |-- lib
    |   |-- systemd
    |   |   `-- system
    |   |       `-- ros-melodic-my-project.service
    |   `-- udev
    |       `-- rules.d
    |           `-- 60-ros-melodic-my-project.rules
    ...

# What?

You can `bloom` your ROS project (that thing you build with [`catkin`][catkin])
into a Debian package archive (`*.deb`) that installs one (or more) of the
following:

* `systemd` service units
* `udev` rules
* `logrotate` config files
* `cron` scripts
* more coming soon

# Why?

Because you're a [Debian package maintainer][debmaintguide] and you want to do
one (or more) of the following:

* run your ROS application as a [`systemd` service][systemdservice]
* use `udev` to detect and configure new/custom/unusual hardware
* rotate logs generated by your ROS application
* run your ROS application from a `cron` script
* more coming soon

# How?

There are really two mechanisms enabling this trick. The first is the manner by
which `bloom` populates the `debian` directory of the released package. The
second is the fallback behavior in [`debhelper`][debhelper].

## How does `bloom` populate the `debian` directory?

> As of bloom 0.5.13, you can supply files in a "debian" folder in your
> package, and the various debhelpers, including dh_installudev will pick them
> up.

-- `mikepurvis`, answering himself,
https://answers.ros.org/question/133966/install-directly-to-etcudevrulesd/?answer=212041#post-id-212041

As of this writing, the latest release of `bloom` is [0.8.0][bloom-0.8.0]
([c247a13](https://github.com/ros-infrastructure/bloom/commit/c247a1320172867ce87c94939df1f166d25a0bb0))
and the mechanism to which `mikepurvis` alludes is implemented within
`bloom/generators/debian/generator.py`, in and around the function
`place_template_files`:

https://github.com/ros-infrastructure/bloom/blob/c247a1320172867ce87c94939df1f166d25a0bb0/bloom/generators/debian/generator.py#L838

During the execution of `bloom-release`, `place_template_files` will copy the
`debian` directory from the catkin project (thing being bloomed) to the
"Debianized release" (thing being generated). The copied contents are combined
with various
[templates](https://github.com/ros-infrastructure/bloom/tree/master/bloom/generators/debian/templates)
and then the process of template expansion begins.

Template files have a `*.em` suffix and any `*.em` file found in the `debian`
directory will be expanded using [`empy`][empy]. How `empy` expands every
`@(Variable)` instance within a given template `foobar.em` to produce
`foobar`. It helps that `bloom-generate` defines several variables specific to
the package being bloomed. Here is a partial enumeration of those variables:

* `@(Copyright)`
* `@(DebianInc)`
* `@(Description)`
* `@(Distribution)`
* `@(Homepage)`
* `@(InstallationPrefix)`
* `@(Maintainer)`
* `@(Package)`
* `@(change_date)`
* `@(change_version)`
* `@(changelog)`
* `@(debhelper_version)`
* `@(format)`
* `@(main_email)`
* `@(main_name)`
* `@(release_tag)`

`bloom-generate` tacitly assumes you will use `debhelper` to build your Debian
packages --- it uses a `debian/rules.em` template that explicitly invokes
`dh`. In any case, the resulting expansions are committed to the "release"
(almost always a bare git repository) from which the Debian packages can be
built.

## How does `debhelper` find files?

When `debhelper` goes looking for files, it searches under the `debian`
directory. Some of these files are [required][dreq]. Other files are
[optional][dother]. For most of the optional files, each has within its
basename (usually as `package.` prefix) the name of the package to which it
belongs. Consider the following examples for the ficticious package `foo`:

* `debian/foo.init`: init script, installs to `/etc/init.d/foo`
* `debian/foo.cron.hourly`: hourly cron job, installs to `/etc/cron.hourly/foo`

[dreq]:https://www.debian.org/doc/manuals/maint-guide/dreq.en.html
[dother]:https://www.debian.org/doc/manuals/maint-guide/dother.en.html

Additionally, and crucially, `debhelper` also uses other files:

> Note for the first (or only) binary package listed in debian/control,
> debhelper will use debian/foo when there's no debian/package.foo
> file. However, it is often a good idea to keep the package. prefix as it is
> more explicit. The primary exception to this are files that debhelper by
> default installs in every binary package when it does not have a package
> prefix (such as debian/copyright or debian/changelog).

-- http://man7.org/linux/man-pages/man7/debhelper.7.html, "Debhelper Config Files" section

This association to an implicit package name is useful when, say, you don't
actually know the name of the package for which you want to install
artifacts. This is exactly the case for ROS packages targeting a Debian-like
OS. The Debian package name is of the form `ros-${ROS_DISTRO}-catkin-project`
and the `${ROS_DISTRO}` could be one of several identifiers through which
`bloom-release` iterates. The quantity and nature of package names is known to
the maintainer only _after_ the bloom succeeds.

# Caveats?

* In the case where you have both a `debian/foo` and a `debian/foo.em`, the
  expansion of the latter overwrites the former.
  
* The example `rsyslog` filter rule file is a `cmake` trick, not a `debhelper`
  trick. It's there to illustrate how such a thing would interact with
  `dh_logrotate`.


[bloom-0.8.0]:https://github.com/ros-infrastructure/bloom/releases/tag/0.8.0
[bloom]:https://github.com/ros-infrastructure/bloom
[bloomgendeb]:https://github.com/ros-infrastructure/bloom/blob/master/bloom/generators/debian/generator.py
[catkin]:https://github.com/ros/catkin
[debhelper]:https://salsa.debian.org/debian/debhelper
[debmaintguide]:https://www.debian.org/doc/manuals/maint-guide/
[empy]:http://www.alcyone.com/software/empy/
[ros]:https://www.ros.org/
[systemdservice]:https://www.freedesktop.org/software/systemd/man/systemd.service.html
[udev]:http://man7.org/linux/man-pages/man7/udev.7.html