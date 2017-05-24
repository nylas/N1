# Composer Templates

Create templates you can use to pre-fill the N1 composer - never type the same
email again! Templates live in the ~/.nylas-mail/templates directory on your computer.
Each template is an HTML file - the name of the
file is the name of the template, and it's contents are the default message body.

If you include HTML &lt;code&gt; tags in your template, you can create
regions that you can jump between and fill easily.
Give &lt;code&gt; tags the `var` class to mark them as template regions. Add
the `empty` class to make them dark yellow. When you send your message, &lt;code&gt;
tags are always stripped so the recipient never sees any highlighting.

This example is a good starting point for plugins that want to extend the composer
experience.

<img src="https://raw.githubusercontent.com/nylas/nylas-mail/master/packages/client-app/internal_packages/composer-templates/screenshot.png">

#### Install this plugin

1. Download and run N1

2. From the menu, select `Developer > Install a Plugin Manually...`
   The dialog will default to this examples directory. Just choose the
   package to install it!

   > When you install packages, they're moved to `~/.nylas-mail/packages`,
   > and N1 runs `apm install` on the command line to fetch dependencies
   > listed in the package's `package.json`
