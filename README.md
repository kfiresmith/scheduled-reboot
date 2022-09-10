# scheduled-reboot
Simple structure for performing scheduled reboots that optionally perform package updates or any scripted pre/post/on-failure actions as part of the scheduled reboot.

scheduled-reboot is meant to be invoked from cron or from a systemd timer.  

When executed, the script `/usr/local/bin/scheduled-reboot` consults `/etc/default/scheduled-reboot` for these settings:

 - `scheduled_reboots_disabled: [true|false]`
    Default: `false`.  
 - `email_when_disabled: [true|false]`
    Default: `true`.  Sends an email to notify the administrator at scheduled runtime if scheduled reboots have been disabled.
 - `upgrade_at_shutdown: [true|false]`
    Default: false.  Whether to run a full package upgrade immediately prior to reboot.
 - `mailto: [string]`
    Default: `root`.  This is a **space-separated** list of full email addresses to send any scheduled-reboot email to.

After reading in setting, the script confirms that package operations are not already underway.  If any package operations are happening at the time of reboot 

### To-do
 - Add tasks to create, populate, delete /etc/nologin
