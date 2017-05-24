import path from 'path';
import fs from 'fs-plus';
import {BrowserWindow, dialog, app} from 'electron';
import {atomicWriteFileSync, getMostRecentTimestampedFile} from '../fs-utils'

let _ = require('underscore');
_ = _.extend(_, require('../config-utils'));

const RETRY_SAVES = 3


export default class ConfigPersistenceManager {
  constructor({configDirPath, resourcePath} = {}) {
    this.configDirPath = configDirPath;
    this.resourcePath = resourcePath;

    this.userWantsToPreserveErrors = false
    this.saveRetries = 0
    this.loadRetries = 0
    this.configFilePath = getMostRecentTimestampedFile(this.configDirPath, 'config', 'json');
    if(typeof this.configFilePath === "string") {
      this.configFilePath = path.join(this.configDirPath, this.configFilePath);
    }
    if (typeof this.configFilePath === "undefined" || !fs.existsSync(this.configFilePath)) {
      this.configFilePath = path.join(this.configDirPath, 'config.json'); // check legacy file
      if (!fs.existsSync(this.configFilePath)) {
        this.configFilePath = path.join(this.configDirPath, 'config.0.json'); // default file for creation
      }
    }
    this.settings = {};

    this.initializeConfigDirectory();
    this.load();
  }

  initializeConfigDirectory() {
    if (!fs.existsSync(this.configDirPath)) {
      fs.makeTreeSync(this.configDirPath);
      const templateConfigDirPath = path.join(this.resourcePath, 'dot-nylas');
      fs.copySync(templateConfigDirPath, this.configDirPath);
    }

    if (!fs.existsSync(this.configFilePath)) {
      this.writeTemplateConfigFile();
    }
  }

  writeTemplateConfigFile() {
    const templateConfigPath = path.join(this.resourcePath, 'dot-nylas', 'config.json');
    const templateConfig = fs.readFileSync(templateConfigPath);
    fs.writeFileSync(this.configFilePath, templateConfig);
  }

  _showLoadErrorDialog(error) {
    const message = `Failed to load "${path.basename(this.configFilePath)}"`;
    let detail = (error.location) ? error.stack : error.message;

    if (error instanceof SyntaxError) {
      detail += `\n\nThe file ${this.configFilePath} has incorrect JSON formatting or is empty. Fix the formatting to resolve this error, or reset your settings to continue using N1.`
    } else {
      detail += `\n\nWe were unable to read the file ${this.configFilePath}. Make sure you have permissions to access this file, and check that the file is not open or being edited and try again.`
    }

    const clickedIndex = dialog.showMessageBox({
      type: 'error',
      message,
      detail,
      buttons: ['Quit', 'Try Again', 'Try Older Configuration', 'Reset Configuration'],
    });

    switch (clickedIndex) {
      case 0: return 'quit';
      case 1: return 'tryagain';
      case 2: return 'tryolder';
      case 3: return 'reset';
      default:
        throw new Error('Unknown button clicked');
    }
  }

  load() {
    this.userWantsToPreserveErrors = false;

    try {
      const json = JSON.parse(fs.readFileSync(this.configFilePath));
      if (!json || !json['*']) {
        throw new Error('config json appears empty');
      }
      this.settings = json['*'];
      this.emitChangeEvent();
    } catch (error) {
      error.message = `Failed to load config.json: ${error.message}`;
      global.errorLogger.reportError(error);

      const action = this._showLoadErrorDialog(error);
      if (action === 'quit') {
        this.userWantsToPreserveErrors = true;
        app.quit();
        return;
      }

      if (action === 'tryagain') {
        this.load();
        return;
      }

      if (action === 'tryolder') {
        this.loadRetries++;
        this.configFilePath = getMostRecentTimestampedFile(this.configDirPath, 'config', 'json', this.loadRetries);
        if(typeof this.configFilePath === "string") {
          this.configFilePath = path.join(this.configDirPath, this.configFilePath);
        }
        this.load();
        return;
      }

      if (action !== 'reset') {
        throw new Error(`Unknown action: ${action}`);
      }

      if (fs.existsSync(this.configFilePath)) {
        fs.unlinkSync(this.configFilePath);
      }
      this.writeTemplateConfigFile();
      this.load();
    }
    this.loadRetries = 0;
  }

  _showSaveErrorDialog() {
    const clickedIndex = dialog.showMessageBox({
      type: 'error',
      message: `Failed to save "${path.basename(this.configFilePath)}"`,
      detail: `\n\nWe were unable to save the file ${this.configFilePath}. Make sure you have permissions to access this file, and check that the file is not open or being edited and try again.`,
      buttons: ['Okay', 'Try again'],
    })
    return ['ignore', 'retry'][clickedIndex];
  }

  save = () => {
    if (this.userWantsToPreserveErrors) {
      return;
    }
    const allSettings = {'*': this.settings};
    const allSettingsJSON = JSON.stringify(allSettings, null, 2);
    this.lastSaveTimestamp = Date.now();

    try {
      atomicWriteFileSync(this.configDirPath, 'config', 'json', allSettingsJSON)
      this.saveRetries = 0
    } catch (error) {
      if (this.saveRetries >= RETRY_SAVES) {
        error.message = `Failed to save config.json: ${error.message}`
        global.errorLogger.reportError(error);
        const action = this._showSaveErrorDialog();
        this.saveRetries = 0;

        if (action === 'retry') {
          this.save()
        }
        return;
      }

      this.saveRetries++
      this.save()
    }
  }

  getRawValuesString = () => {
    if (!this.settings || _.isEmpty(this.settings)) {
      throw new Error('this.settings is empty');
    }
    return JSON.stringify(this.settings);
  }

  setSettings = (value, sourceWebcontentsId) => {
    this.settings = value;
    this.emitChangeEvent({sourceWebcontentsId});
    this.save();
  }

  setRawValue = (keyPath, value, sourceWebcontentsId) => {
    if (!keyPath) {
      throw new Error('keyPath must not be false-y!');
    }
    _.setValueForKeyPath(this.settings, keyPath, value);
    this.emitChangeEvent({sourceWebcontentsId});
    this.save();
  }

  emitChangeEvent = ({sourceWebcontentsId} = {}) => {
    global.application.config.updateSettings(this.settings);

    BrowserWindow.getAllWindows().forEach((win) => {
      if ((win.webContents) && (win.webContents.getId() !== sourceWebcontentsId)) {
        win.webContents.send('on-config-reloaded', this.settings);
      }
    });
  }
}
