%global commit0 9c7d05ccaf3773e4168278ce3d3da254695b02eb
%global shortcommit0 %(c=%{commit0}; echo ${c:0:7})
%global gittag 3.0.7
%global projname AutoMySQLBackup

Name:		   automysqlbackup
Version:	 3.0.7
Release:	 1%{?dist}
Summary:	 MySQL/MariaDB backup script
Group:		 Applications/Databases
License:	 GPLv2+
URL:       https://github.com/sixhop/%{projname}
%undefine  _disable_source_fetch
Source0:	 https://github.com/sixhop/%{projname}/archive/%{gittag}/%{projname}-%{version}.tar.gz
%define    SHA256SUM0 8641f37ed453c880f541fe729e7b927db62b8d8a81c0d693efb8dd9dece09ee7
BuildArch: noarch
Requires:	 bash
Requires:	 bzip2
Requires:	 gzip
Requires:	 diffutils
Requires:	 openssl
Requires:	 mysql

%description
MySQL/MariaDB backup wrapper script for mysqldump, with support for
backup rotation, encryption, compression and incremental backup.

%prep
echo "%SHA256SUM0 %SOURCE0" | sha256sum -c -
%autosetup -n %{projname}-%{gittag}

%build
true

%install
install -m 755 -d %{buildroot}/%{_bindir}
install -m 755 -d %{buildroot}/%{_sysconfdir}/automysqlbackup

install -m 755 automysqlbackup %{buildroot}/%{_bindir}/automysqlbackup
install -m 600 automysqlbackup.conf %{buildroot}/%{_sysconfdir}/automysqlbackup/automysqlbackup.conf

%files
%{_bindir}/automysqlbackup
%config(noreplace) %{_sysconfdir}/automysqlbackup/automysqlbackup.conf
%doc README README.md LICENSE CHANGELOG

%changelog
* Sun Nov 03 2019 Robert Oschwald <robertoschwald@gmail.com> 3.0.7
- Small changes for MacOS
