# Darkside
**An dark sidebar theme for [Nylas Mail](https://nylas.com/n1). Created by [Jamie Wilson](http://jamiewilson.io)**

## Activation
Darkside comes [pre-installed](https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/ui-darkside) with N1. To change themes, go to `Nylas Mail > Change Theme…` in the menu bar, then select `Darkside`. Learn more at [support.nylas.com](https://support.nylas.com/hc/en-us/articles/217557858-How-do-I-change-my-theme-).

## Customization
In order to customize Darkside, you'll need to manually install it.

#### 1. Download the `ui-darkside` folder.

> **Download Option 1:**  
> [Download just the 'ui-darkside' folder](https://kinolien.github.io/gitzip/?download=https://github.com/nylas/nylas-mail/tree/master/packages/client-app/internal_packages/ui-darkside) thanks to the service [gitzip by @kinolien](https://kinolien.github.io/gitzip/).
  

> **Download Option 2:**  
> [Download the entire N1 repo](https://github.com/nylas/nylas-mail/archive/master.zip) or `git clone https://github.com/nylas/nylas-mail.git`. Then grab the folder from `N1/internal_packages/ui-darkside`.
  
#### 2. Manual Install

> To manually install a theme, go to `Nylas Mail > Install Theme…` in the menu bar. Select the `ui-darkside` folder you just downloaded. This will copy the folder into your N1 packages directory so you can delete the orginal download if you want to. 

#### 3. Customize

> **Open the theme directory**  
> If you're on a Mac, you can find the theme files at `~/.nylas-mail/packages`. To get there quickly, use the key command <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>G</kbd> and enter `~/.nylas-mail/packages`.

> **Change package.json**  
> In order to avoid conflicts between your custom theme and the pre-installed version, change `name` and `displayName` in `package.json` to:

    "name": "ui-darkside-custom",
    "displayName": "Darkside Custom",

> **Edit LESS files**  
> Open the `darkside-variables.less` file. To change colors, just comment out the default `@sidebar` and `@accent` variables and uncomment another theme or simply replace with your own colors.

```sass
// Default
@sidebar: #313042;
@accent: #F18260;

// Luna
// @sidebar: #202C46;
// @accent: #39DFF8;

// Zond
// @sidebar: #333333;
// @accent: #F6D49C;

// Gemini
// @sidebar: #00203C;
// @accent: #F6B312;

// Mercury
// @sidebar: #555;
// @accent: #999;

// Apollo
// @sidebar: #3A1E15;
// @accent: #F6AA1C;
```

### Feedback
If you have questions or suggestions, please submit an issue. If you need to, you can email me at [jamie@jamiewilson.io](mailto:jamie@jamiewilson?subject=Re: Darkside).
