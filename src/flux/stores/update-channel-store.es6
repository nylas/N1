import NylasStore from 'nylas-store';
import {remote} from 'electron';

import EdgehillAPI from '../edgehill-api';

const autoUpdater = remote.getGlobal('application').autoUpdateManager;
const preferredChannel = autoUpdater.preferredChannel;

class UpdateChannelStore extends NylasStore {
  constructor() {
    super();
    this._current = {name: 'Loading...'};
    this._available = [{name: 'Loading...'}];

    if (NylasEnv.isMainWindow()) {
      this.refreshChannel();
    }
  }

  current() {
    return this._current;
  }

  currentIsUnstable() {
    return this._current && this._current.name.toLowerCase() === 'beta';
  }

  available() {
    return this._available;
  }

  refreshChannel() {
    EdgehillAPI.makeRequest({
      method: 'GET',
      path: `/update-channel`,
      qs: Object.assign({preferredChannel: preferredChannel}, autoUpdater.parameters()),
      json: true,
    }).then(({current, available}) => {
      this._current = current;
      this._available = available;
      this.trigger();
    });
    return null;
  }

  setChannel(channelName) {
    EdgehillAPI.makeRequest({
      method: 'POST',
      path: `/update-channel`,
      qs: Object.assign({channel: channelName,
                         preferredChannel: preferredChannel}, autoUpdater.parameters()),
      json: true,
    }).then(({current, available}) => {
      this._current = current;
      this._available = available;
      this.trigger();
    }).catch((err) => {
      NylasEnv.showErrorDialog(err.toString())
      this.trigger();
    });
    return null;
  }
}

export default new UpdateChannelStore();
