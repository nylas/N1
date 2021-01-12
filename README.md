# Nylas Mail - the open-source, extensible mail client
![N1 Screenshot](https://github.com/nylas/nylas-mail/raw/master/screenshot/hero_graphic_mac%402x.png)

**Nylas Mail was an open-source mail client built on the modern web with [Electron](https://github.com/atom/electron), [React](https://facebook.github.io/react/), and [Flux](https://facebook.github.io/flux/).** It was designed to be easy to extend, and many third-party plugins are available that add functionality to the client. 

**⚠️ Nylas Mail was initially released and open-sourced in early 2015 and was maintained by Nylas until Spring 2017.** While Nylas no longer supports Nylas Mail, you can download the latest release or build it from source. There are also **[several forks](#forks)** that are being actively developed and maintained.

# Getting Started

## Setup your Environment (Mac):

1. Install [Homebrew](http://brew.sh/)
1. Install [NVM](https://github.com/creationix/nvm) & Redis `brew install nvm redis`
1. Install Node 6 via NVM: `nvm install 6`
1. `npm install`

## Setup your Environment (Linux - Debian/Ubuntu):

1. Install Node 6+ via NodeSource (trusted):
  1. `curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -`
  1. `sudo apt-get install -y nodejs`
1. Install Redis locally `sudo apt-get install -y redis-server redis-tools`
benefit of letting us use subdomains.
1. `npm install`

## Running Nylas Mail

1. `npm run client`: Starts the app
1. `npm run test-client`: Run the tests
1. `npm run lint-client`: Lint the source (ESLint + Coffeelint + LESSLint)

### Exploring the Source

This repository contains the full source code to the Nylas Mail client and it's backend services. It is divided into the following packages:

1. [**Isomorphic Core**](https://github.com/nylas/nylas-mail/tree/master/packages/isomorphic-core): Shared code across local client and cloud servers
1. [**Client App**](https://github.com/nylas/nylas-mail/tree/master/packages/client-app): The main Electron app for Nylas Mail
   mirrored to open source repo.
1. [**Client Sync**](https://github.com/nylas/nylas-mail/tree/master/packages/client-sync): The local mailsync engine integreated in Nylas Mail
1. [**Client Private Plugins**](https://github.com/nylas/nylas-mail/tree/master/packages/client-private-plugins): Private Nylas Mail plugins (like SFDC)
1. [**Cloud API**](https://github.com/nylas/nylas-mail/tree/master/packages/cloud-api): The cloud-based auth and metadata APIs for N1
1. [**Cloud Core**](https://github.com/nylas/nylas-mail/tree/master/packages/cloud-core): Shared code used in all remote cloud services
1. [**Cloud Workers**](https://github.com/nylas/nylas-mail/tree/master/packages/cloud-workers): Cloud workers for services like send later

See `/packages` for the separate pieces. Each folder in `/packages` is
designed to be its own stand-alone repository. They are all bundled here
for the ease of source control management.

## Digging Deeper

In early 2016, the Nylas Mail team wrote [extensive documentation](https://nylas.github.io/nylas-mail/) for the app that was intended for plugin developers. This documentation lives on GitHub Pages and offers a great overview of the app's architecture and important classes. Here are some good places to get started:

- [Application Architecture](https://nylas.github.io/nylas-mail/guides/Architecture.html)
- [Debugging Nylas Mail](https://nylas.github.io/nylas-mail/guides/Debugging.html)

The team has also given conference talks and published blog posts about the client:

- [ReactEurope: How React & Flux Turn Apps Into Extensible Platforms](https://www.youtube.com/watch?v=Uu4Yz2HmCgE)
- [ForwardJS: Electron, React & Pixel Perfect Experiences](https://www.youtube.com/watch?v=jRPUB-D1Wx0&list=PL7i8CwZBnlf7iUTn2JMVLLWofAhaiK7l3)

- [Blog: Splitting from Atom](https://github.com/nylas/nylas-mail/raw/master/blog-posts/splitting-from-atom.pdf)
- [Blog: Building Plugins for React Apps](https://github.com/nylas/nylas-mail/raw/master/blog-posts/plugins.pdf)
- [Blog: Nylas Mail Build Process](https://github.com/nylas/nylas-mail/raw/master/blog-posts/build-process.pdf)
- [Blog: Low level Electron Debugging](https://github.com/nylas/nylas-mail/raw/master/blog-posts/electron-debugging.pdf)
- [Blog: A New Search Parser](https://github.com/nylas/nylas-mail/raw/master/blog-posts/search-parser.pdf)
- [Blog: Developers Guide to Emoji](https://github.com/nylas/nylas-mail/raw/master/blog-posts/emoji.pdf)
- [Blog: Nylas Pro](https://github.com/nylas/nylas-mail/raw/master/blog-posts/nylas-pro.pdf)
- [Blog: Nylas Mail & PGP](https://github.com/nylas/nylas-mail/raw/master/blog-posts/pgp.pdf)
- [Blog: Calendar Events and RRULEs](https://github.com/nylas/nylas-mail/raw/master/blog-posts/rrules.pdf)

## Running the Cloud

When you download and build Nylas Mail from source it runs without its cloud components. The concept of a "Nylas ID" / subscription has been removed, and plugins that require server-side processing are disabled by default. (Plugins like Snooze, Send Later, etc.)

In order to use these plugins and get the full Nylas Mail experience, you need to deploy the backend infrastructure located in the `cloud-*` packages. Deploying these services is challenging because they are implemented as microservices and designed to be run at enterprise scale with Redis, Postgres, etc. Because these backend services must access your email account, it is also important to use security best-practices (at the very least, SSL, encryption at rest, and a partitioned VPC). For more information about building and deploying this part of the stack, check out the [cloud-core README](https://github.com/nylas/nylas-mail/blob/master/packages/cloud-core/README.md).

## Themes

The Nylas Mail user interface is styled using CSS, which means it's easy to modify and extend. Nylas Mail comes stock with a few beautiful themes, and there are many more which have been built by community developers

![N1 Themes](https://github.com/nylas/nylas-mail/raw/master/screenshot/687474703a2f2f692e696d6775722e636f6d2f505751374e6c592e6a7067.jpg)

#### Bundled Themes
- [Dark](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/ui-dark)
- [Darkside](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/ui-darkside) (designed by [Jamie Wilson](https://github.com/jamiewilson))
- [Taiga](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/ui-taiga) (designed by [Noah Buscher](https://github.com/noahbuscher))
- [Ubuntu](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/ui-ubuntu) (designed by [Ahmed Elhanafy](https://github.com/ahmedlhanafy))
- [Less Is More](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/ui-less-is-more) (designed by [Alexander Adkins](https://github.com/P0WW0W))

#### Community Themes
|       |       |       |
| ----- | ----- | ----- |
| [ToogaBooga](https://github.com/brycedorn/N1-ToogaBooga) | [Material](https://github.com/jackiehluo/n1-material) | [Monokai](https://github.com/dcondrey/n1-monokai)  |
| [Agapanthus](https://github.com/taniadaniela/n1-agapanthus)—Inbox-inspired theme | [Stripe](https://github.com/oeaeee/n1-stripe)| [Kleinstein](https://github.com/diklein/Kleinstein)—Hides account sidebar|
| [Arc Dark](https://github.com/varlesh/Nylas-Arc-Dark-Theme)| [Solarized Dark](https://github.com/NSHenry/N1-Solarized-Dark) | [Darkish](https://github.com/dyrnade/N1-Darkish)|
| [Predawn](https://github.com/adambmedia/N1-Predawn)| [Ido](https://github.com/edipox/n1-ido)—Polymail-inspired theme|[Berend](https://github.com/Frique/N1-Berend) |
| [ElementaryOS](https://github.com/edipox/elementary-nylas) | [LevelUp](https://github.com/stolinski/level-up-nylas-n1-theme)|[Sunrise](https://github.com/jackiehluo/n1-sunrise) |
| [BoraBora](https://github.com/arimai/N1-BoraBora) | [Honeyduke](https://github.com/arimai/n1-honeyduke)| [Snow](https://github.com/Wattenberger/N1-snow-theme)|
|[Hull](https://github.com/unity/n1-hull)|[Express](https://github.com/oeaeee/n1-express)|[DarkSoda](https://github.com/adambullmer/N1-theme-DarkSoda)|
|[Bemind](https://github.com/bemindinteractive/Bemind-N1-Theme)|[Dracula](https://github.com/dracula/nylas-n1)|[MouseEatsCat](https://github.com/MouseEatsCat/MouseEatsCat-N1)|
|[Sublime Dark](https://github.com/rishabhkesarwani/Nylas-Sublime-Dark-Theme)|[Firefox](https://github.com/darshandsoni/n1-firefox-theme)|[Gmail](https://github.com/dregitsky/n1-gmail-theme)|

#### To install community themes:

1. Download and unzip the repo
2. In Nylas Mail, select `Developer > Install a Package Manually... `
3. Navigate to where you downloaded the theme and select the root folder. The theme is copied into the `~/.nylas-mail` folder for your convinence
5. Select `Change Theme...` from the top level menu, and you'll see the newly installed theme. That's it!

Want to dive in more? Try [creating your own theme](https://github.com/nylas/nylas-mail-theme-starter)!

## Plugins

Some plugins come pre-installed, and are a great starting points for creating your own:

- [Translate](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/composer-translate)—Works with 10 languages
- [Quick Replies](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/composer-templates)—Send emails faster with templates
- [Emoji Keyboard](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/composer-emoji)—Insert emoji by typing a colon (:) followed by the name of an emoji symbol
- [GitHub Sidebar Info](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/github-contact-card)
- [View on GitHub](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/message-view-on-github)
- [Personal Level Indicators](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/personal-level-indicators)
- [Phishing Detection](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/phishing-detection)

#### Community Plugins

Note these are not tested or officially supported by Nylas, but we still think they are really cool! If you find bugs with them, please open GitHub issues on their individual project pages, not the Nylas Mail (N1) repo page. Thanks!

|       |       |       |
| ----- | ----- | ----- |
|[Jiffy](http://noahbuscher.github.io/N1-Jiffy/)—Insert animated GIFs|[Weather](https://github.com/jackiehluo/n1-weather)|[Todoist](https://github.com/alexfruehwirth/N1TodoistIntegration)|
|[Unsubscribe](https://github.com/colinking/n1-unsubscribe)|[Squirt Speed Reader](https://github.com/HarleyKwyn/squirt-reader-N1-plugin/)|[Website Launcher](https://github.com/adriangrantdotorg/nylas-n1-background-webpage)—Opens a URL in separate window|
|[Cypher](https://github.com/mbilker/cypher)—PGP Encryption|[Avatars](https://github.com/unity/n1-avatars)|[Events Calendar (WIP)](https://github.com/nerdenough/n1-events-calendar)|
|[Mail in Chat (WIP)](https://github.com/yjchen/mail_in_chat)|[Evernote](https://github.com/grobgl/n1-evernote)|[Wunderlist](https://github.com/miguelrs/n1-wunderlist)|
|[Participants Display](https://github.com/kbruccoleri/nylas-participants-display)|[GitHub](https://github.com/ForbesLindesay/N1-GitHub)||

When you install packages, they're moved to ~/.nylas-mail/packages, and Nylas Mail runs apm install on the command line to fetch dependencies listed in the package's package.json

# Forks

There are several forks of Nylas Mail that you should check out. If you're just learning about Nylas Mail, it is highly recommended you use one of these instead.

 - [Mailspring](http://www.getmailspring.com/) - Significant rewrite by one of the original authors focused on performance and cloud plugins
 - [Nylas Mail Lives](https://github.com/nylas-mail-lives/nylas-mail) - Community effort to fix bugs and improve the client! (Archived)
