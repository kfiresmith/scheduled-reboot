# scheduled-reboot

Simple script-driven framework for executing orderly scheduled reboots that optionally perform package updates or any scripted pre/post/on-failure actions as part of the scheduled reboot.

scheduled-reboot is meant to be invoked from cron or from a systemd timer.

The scripts support Debian/Ubuntu systems using APT and RHEL-family systems using DNF or YUM. They require Bash and common Linux utilities.

### Configuration


**The defaults file**


When executed, the script `/usr/local/bin/scheduled-reboot` consults `/etc/default/scheduled-reboot` for these settings:


 - `scheduled_reboots_disabled: [true|false]`
    Default: `false`.  
 - `email_when_disabled: [true|false]`
    Default: `true`.  Sends an email to notify the administrator at scheduled runtime if scheduled reboots have been disabled.
 - `upgrade_at_shutdown: [true|false]`
    Default: false.  Whether to run a full package upgrade immediately prior to reboot.
- `script_timeout_seconds: [integer]`
    Default: 900. Maximum runtime for each custom script.
- `package_manager_timeout_seconds: [integer]`
    Default: 1800. Maximum runtime for each package-manager command.
- `mailto: [string]`
    Default: `root`.  This is a **space-separated** list of full email addresses to send any scheduled-reboot email to.
 - `scripts_dir: [string]`
    Default: `/etc/scheduled-reboot`. Base directory where the `pre-reboot`, `post-reboot`, and `on-pre-reboot-failure` script folders are located.
 - `logs_dir: [string]`
    Default: `/var/log/scheduled-reboot`. Directory used for scheduled-reboot log files.


**Pre/Post/On-pre-failure tasks**


Folders at `/etc/scheduled-reboot/pre-reboot`, `/etc/scheduled-reboot/on-pre-reboot-failure`, and `/etc/scheduled-reboot/post-reboot` can store any custom bash scripts that might be needed to help prepare the system for reboot, or to perform tasks immediately after reboot.


Numeric prefixes can be added to these scripts to ensure deliberate order of operations. Only regular files with the executable bit set and a shebang (`#!`) are run; the shebang selects Bash, Python, or another installed interpreter. Files are run directly, not forcibly through Bash.

Output from scripts and package-manager commands is appended to the custom log files with an ISO-8601 timestamp (including timezone) on each line.

Each run also emits structured start/finish metadata to syslog, including a run ID, phase, command, exit status, and elapsed time. Log files are rotated monthly and retained for 12 rotations.

During maintenance, scheduled-reboot creates `/etc/nologin` only when that file does not already exist. The post-reboot service removes it only when its contents match the scheduled-reboot maintenance marker, so an administrator's existing `/etc/nologin` is never overwritten or removed.

### Operations order

After reading in settings from `/etc/default/scheduled-reboot`, the script confirms that package operations are not already underway. If a package operation is active, scheduled-reboot waits up to five minutes for it to finish. If the lock remains active, the process is abandoned until the next scheduled reboot execution and notification emails are sent to the configured `mailto` contacts.


If upgrades are not currently running, the script moves on to run any pre-reboot scripts.   If these scripts encounter any issues (non-zero exits), the script will log & email about the problems, then move on to execute anything present in the on-pre-reboot-failure directory.


If the pre-reboot scripts all succeed, or none are present, scheduled-reboot moves on to (optionally) performing a package cache update and full package upgrade.  If either of these steps fail, you guessed it - logs and emails will be generated.  The system will **not** be rebooted if the package upgrade encounters problems.


Once the upgrade successfully completes, the system is rebooted.


Upon successful boot, as part of entering the multi-user.target stage, anything in the post-reboot folder will be executed.

### Repository layout

- `src/` — the single, package-agnostic source tree (FHS layout: `etc/`, `usr/`). This is what gets installed on the target system, regardless of package format.
- `packaging/deb/` — Debian-specific packaging metadata (`control`, `conffiles`).
- `packaging/rpm/` — the RPM spec file.
- `packaging/common/` — pre-install, post-install, and pre-remove provisioning logic shared verbatim by both package formats, so the two packages can't drift out of sync with each other.
- `build.sh` — assembles ephemeral build trees under `/tmp` from the above and produces packages in `./dist/`.

### Building packages

Run `./build.sh` from the repository root:

```
./build.sh --all   # build both .deb and .rpm (default with no flags)
./build.sh --deb    # build only the .deb
./build.sh --rpm    # build only the .rpm
```

The script verifies that the version string in `packaging/deb/control`, `packaging/rpm/scheduled-reboot.spec`, the man page, and both scripts' `VERSION=` variables all agree before building anything, and checks for the required build tools (`dpkg-dev`/`fakeroot` for `.deb`, `rpm-build` for `.rpm`), telling you what to install if something's missing. Output packages are written to `./dist/`.

To release a new version, bump the version string in all of those places (`packaging/deb/control`, `packaging/rpm/scheduled-reboot.spec`, the `.TH` line in the man page, and `VERSION=` in both `usr/local/bin/scheduled-reboot` and `usr/local/bin/post-reboot`), then run `./build.sh --all`.

### Manual page

The package installs a manual page in `/usr/local/share/man/man8`.  View it
with `man scheduled-reboot` for a concise reference of configuration and
operation.
