#filter out plugin .so from porvides
%global __provides_exclude_from %{_libdir}/purple-.*/.*\\.so
%define git_commit eca11d5c7010964e43c3ac0d568b48f39cee9027

Name:		purple-discord
Version:	0.0.0
Release:	%mkrel 1
Summary:	Discord protocol plugin for libpurple
License:	GPLv3
Group:		Networking/Instant messaging
URL:		https://github.com/EionRobb/purple-discord
Source0:	https://github.com/EionRobb/%{name}/archive/%{git_commit}.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires:	pkgconfig(json-glib-1.0)
BuildRequires:	pkgconfig(libmarkdown)
BuildRequires:	pkgconfig(purple)

%description
A third-party plugin for the Pidgin multi-protocol instant messenger.
It connects libpurple-based instant messaging clients with Discord server. 

This package provides the protocol plugin for libpurple clients.

%package -n pidgin-discord
Summary:        Libpurple protocol plugin to connect to Discord
Group:          Applications/Internet
License:        GPLv2+

Requires:       %{name} = %{version}-%{release}
BuildArch:      noarch


%description -n pidgin-discord
A third-party plugin for the Pidgin multi-protocol instant messenger.
It connects libpurple-based instant messaging clients with Discord server. 

This package provides the icon set for Pidgin.

%prep
%setup -q -n %{name}-%{git_commit}

%build
%make_build

%install
%make_install
%find_lang %{name}

%files -f %{name}.lang
%license LICENSE
%doc README.md
%{_libdir}/purple-*/libdiscord.so

%files -n pidgin-discord
%{_datadir}/pixmaps/pidgin/protocols/*/discord.png

%changelog
* %(LC_TIME=C date "+%a %b %d %Y") (Automated build) - %{version}-%{release}
- Updated package.

* Mon Sep 30 2019 - 0.0.0-1
- Initial package.
