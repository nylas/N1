/* eslint no-unused-vars:0 */

import {ComponentRegistry, WorkspaceStore} from 'nylas-exports';
import ActivitySidebar from "./sidebar/activity-sidebar";
import NotifWrapper from "./notif-wrapper";

import AccountErrorNotification from "./items/account-error-notif";
import DefaultClientNotification from "./items/default-client-notif";
import UnstableChannelNotification from "./items/unstable-channel-notif";
import DevModeNotification from "./items/dev-mode-notif";
import DisabledMailRulesNotification from "./items/disabled-mail-rules-notif";
import OfflineNotification from "./items/offline-notification";
import UpdateNotification from "./items/update-notification";

const notifications = [
  AccountErrorNotification,
  DefaultClientNotification,
  UnstableChannelNotification,
  DevModeNotification,
  DisabledMailRulesNotification,
  UpdateNotification,
]

if (NylasEnv.config.get('core.workspace.showOfflineNotification')) {
  notifications.push(OfflineNotification)
}

export function activate() {
  ComponentRegistry.register(ActivitySidebar, {location: WorkspaceStore.Location.RootSidebar});
  ComponentRegistry.register(NotifWrapper, {location: WorkspaceStore.Location.RootSidebar});

  for (const notification of notifications) {
    ComponentRegistry.register(notification, {role: 'RootSidebar:Notifications'});
  }
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(ActivitySidebar);
  ComponentRegistry.unregister(NotifWrapper);

  for (const notification of notifications) {
    ComponentRegistry.unregister(notification)
  }
}
