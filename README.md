# scheduled-reboot

Simple script-driven framework for executing orderly scheduled reboots that optionally perform package updates or any scripted pre/post/on-failure actions as part of the scheduled reboot.

scheduled-reboot is meant to be invoked from cron or from a systemd timer.

Current support is limited to Ubuntu 16+, but this system likely works fine on Debian.  I just haven't tested that.  If I get saddled with enough Red Hat variant servers, I'll probably write in support for RPM-based distributions at some point.

### Configuration


**The defaults file**


When executed, the script `/usr/local/bin/scheduled-reboot` consults `/etc/default/scheduled-reboot` for these settings:


 - `scheduled_reboots_disabled: [true|false]`
    Default: `false`.  
 - `email_when_disabled: [true|false]`
    Default: `true`.  Sends an email to notify the administrator at scheduled runtime if scheduled reboots have been disabled.
 - `upgrade_at_shutdown: [true|false]`
    Default: false.  Whether to run a full package upgrade immediately prior to reboot.
 - `mailto: [string]`
    Default: `root`.  This is a **space-separated** list of full email addresses to send any scheduled-reboot email to.


**Pre/Post/On-pre-failure tasks**


Folders at `/etc/scheduled-reboot/pre-reboot`, `/etc/scheduled-reboot/on-pre-reboot-failure`, and `/etc/scheduled-reboot/post-reboot` can store any custom bash scripts that might be needed to help prepare the system for reboot, or to perform tasks immediately after reboot.


Numeric prefixes can be added to these scripts to ensure deliberate order of operations.  For example, in `pre-reboot/`, you might have: `00-first_task`, and `10-second_task` and so on.

### Operations order

After reading in settings from `/etc/default/scheduled-reboot`, the script confirms that package operations are not already underway.  If any package operations are happening at the time of scheduled reboot, the entire process is immediately abandoned until the next scheduled reboot execution.  Notification emails will go out to scheduled-reboot mailto contacts when this happens.


If upgrades are not currently running, the script moves on to run any pre-reboot scripts.   If these scripts encounter any issues (non-zero exits), the script will log & email about the problems, then move on to execute anything present in the on-pre-reboot-failure directory.


If the pre-reboot scripts all succeed, or none are present, scheduled-reboot moves on to (optionally) performing a package cache update and full package upgrade.  If either of these steps fail, you guessed it - logs and emails will be generated.  The system will **not** be rebooted if the package upgrade encounters problems.


Once the upgrade successfully completes, the system is rebooted.


Upon successful boot, as part of entering the multi-user.target stage, anything in the post-reboot folder will be executed.


