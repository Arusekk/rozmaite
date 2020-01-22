# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit git-r3

DESCRIPTION="A libpurple/Pidgin plugin for Mattermost"
HOMEPAGE="https://github.com/EionRobb/purple-mattermost"
EGIT_REPO_URI="${HOMEPAGE}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="-debug"

RDEPEND="app-text/discount
	dev-libs/glib
	dev-libs/json-glib
	dev-vcs/git
	net-im/pidgin"
DEPEND="${RDEPEND}"
