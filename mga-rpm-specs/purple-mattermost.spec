#filter out plugin .so from porvides
%global __provides_exclude_from %{_libdir}/purple-.*/.*\\.so

Name:		purple-mattermost
Version:	1.2
Release:	%mkrel 1
Summary:	Mattermost protocol plugin for libpurple
License:	GPLv3
Group:		Networking/Instant messaging
URL:		https://github.com/EionRobb/purple-mattermost
Source0:	https://github.com/EionRobb/%{name}/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
Patch1:     https://github.com/EionRobb/purple-mattermost/compare/v1.2...d6aa4dd85f8cc46bd5ee17473c551dcdbf61da5b.patch#/purple-mattermost-1.2-use-v4.patch

BuildRequires:	pkgconfig(json-glib-1.0)
BuildRequires:	pkgconfig(libmarkdown)
BuildRequires:	pkgconfig(purple)

%description
A third-party plugin for the Pidgin multi-protocol instant messenger.
It connects libpurple-based instant messaging clients with Mattermost server. 

This package provides the protocol plugin for libpurple clients.

%package -n pidgin-mattermost
Summary:        Libpurple protocol plugin to connect to Mattermost
Group:          Applications/Internet
License:        GPLv3

Requires:       %{name} = %{version}-%{release}
BuildArch:      noarch


%description -n pidgin-mattermost
A third-party plugin for the Pidgin multi-protocol instant messenger.
It connects libpurple-based instant messaging clients with Mattermost server. 

This package provides the icon set for Pidgin.

%prep
%autosetup -p1

%build
%make_build

%install
%make_install

%files
%license LICENSE
%doc INSTALL.md README.md VERIFICATION.md
%{_libdir}/purple-*/libmattermost.so

%files -n pidgin-mattermost
%{_datadir}/pixmaps/pidgin/protocols/*/mattermost.png

%changelog
* %(LC_TIME=C date "+%a %b %d %Y") (Automated build) - %{version}-%{release}
- Updated package.

* Wed May 31 2017 Jaroslaw Polok <jaroslaw.polok@gmail.com> - 1.1
- Initial packaging.
