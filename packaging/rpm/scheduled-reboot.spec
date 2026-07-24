Name:           scheduled-reboot
Version:        0.55
Release:        1%{?dist}
Summary:        Script-driven framework for performing automated patching & rebooting systems

License:        MIT
URL:            https://github.com/kfiresmith/scheduled-reboot
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
Requires:       bash, coreutils, util-linux, logrotate, mailx

%description
Simple script-driven framework for executing orderly scheduled reboots that
optionally perform package updates or any scripted pre/post/on-failure
actions as part of the scheduled reboot. Supports RHEL-family systems using
DNF or YUM, and can be invoked from cron or a systemd timer.

%prep
%autosetup -n %{name}-%{version}

%build
# Nothing to build; this package only ships scripts and configuration files.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a etc usr %{buildroot}/

%pre -p /bin/bash
@@PREINSTALL@@

%post -p /bin/bash
@@POSTINSTALL@@

%preun -p /bin/bash
@@PREREMOVE@@

%files
%attr(0755,root,root) /usr/local/bin/scheduled-reboot
%attr(0755,root,root) /usr/local/bin/post-reboot
%config(noreplace) %attr(0644,root,root) /etc/default/scheduled-reboot
%attr(0644,root,root) /etc/systemd/system/post-reboot.service
%config(noreplace) %attr(0644,root,root) /etc/logrotate.d/scheduled-reboot
%attr(0644,root,root) /usr/local/share/man/man8/scheduled-reboot.8

%changelog
* Fri Jul 24 2026 Kodiak Firesmith <firesmith@protonmail.com> - 0.55-1
- See project README and git history for change details.
* Fri Jul 24 2026 Kodiak Firesmith <firesmith@protonmail.com> - 0.50-1
- See project README and git history for change details.
