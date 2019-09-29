#filter out plugin .so from porvides
%global __provides_exclude_from %{_libdir}/purple-.*/.*\\.so
%define git_commit be97802c7fd0b611722d2f551756e2a2672f6084

Name:		slack-libpurple
Version:	0.0.0
Release:	%mkrel 1
Summary:	Slack protocol plugin for libpurple
License:	GPLv2
Group:		Networking/Instant messaging
URL:		https://github.com/dylex/slack-libpurple
Source0:	https://github.com/dylex/%{name}/archive/%{git_commit}.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires:  pkgconfig(libcurl)
BuildRequires:	pkgconfig(purple)

%description
A third-party plugin for the Pidgin multi-protocol instant messenger.
It connects libpurple-based instant messaging clients with Slack server. 

This package provides the protocol plugin for libpurple clients.

%package -n pidgin-slack
Summary:        Libpurple protocol plugin to connect to Slack
Group:          Applications/Internet
License:        GPLv2

Requires:       %{name} = %{version}-%{release}
BuildArch:      noarch


%description -n pidgin-slack
A third-party plugin for the Pidgin multi-protocol instant messenger.
It connects libpurple-based instant messaging clients with Slack server. 

This package provides the icon set for Pidgin.

%prep
%setup -q -n %{name}-%{git_commit}

%build
%make_build

%install
%make_install

%files
%license COPYING
%doc README.md
%{_libdir}/purple-*/libslack.so

%files -n pidgin-slack
%{_datadir}/pixmaps/pidgin/protocols/*/slack.png

%changelog
* %(LC_TIME=C date "+%a %b %d %Y") (Automated build) - %{version}-%{release}
- Updated package.

* Mon Sep 30 2019 - 0.0.0-1
- Initial package.
