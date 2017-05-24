# Github Contact Card Section

Extends the contact card in the sidebar to show public repos of the people you email.
Uses GitHub's public API to look up a GitHub user based on their email address,
and then displays public repos and their stars.

This example is a good starting point for plugins that want to display data from
external sources in the sidebar. If you want to see some more advanced plugins, have a look through [all the internal plugins, here on Github](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages).

<img src="https://raw.githubusercontent.com/nylas/nylas-mail/master/packages/client-app/internal_packages/github-contact-card/screenshot.png">

#### Install this plugin

1. Download and run N1

2. From the menu, select `Developer > Install a Plugin Manually...`
   The dialog will default to this examples directory. Just choose the
   package to install it!

   > When you install packages, they're moved to `~/.nylas-mail/packages`,
   > and N1 runs `apm install` on the command line to fetch dependencies
   > listed in the package's `package.json`
