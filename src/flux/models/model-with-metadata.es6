import Model from './model'
import Attributes from '../attributes'

class PluginMetadata extends Model {
  static attributes = {
    pluginId: Attributes.String({
      modelKey: 'pluginId',
    }),
    version: Attributes.Number({
      modelKey: 'version',
    }),
    value: Attributes.Object({
      modelKey: 'value',
    }),
  };

  constructor(...args) {
    super(...args)
    this.version = this.version ? this.version : 0;
  }

  get id() {
    return this.pluginId
  }

  set id(pluginId) {
    this.pluginId = pluginId
  }
}


/**
 Cloud-persisted data that is associated with a single Nylas API object
 (like a `Thread`, `Message`, or `Account`).

 Each Nylas API object can have exactly one `Metadata` object associated
 with it. If you update the metadata object on an existing associated
 Nylas API object, it will override the previous `value`
*/
export default class ModelWithMetadata extends Model {
  static attributes = Object.assign({}, Model.attributes, {
    pluginMetadata: Attributes.Collection({
      queryable: true,
      itemClass: PluginMetadata,
      modelKey: 'pluginMetadata',
      jsonKey: 'metadata',
    }),
  });

  constructor(...args) {
    super(...args)
    this.pluginMetadata = this.pluginMetadata ? this.pluginMetadata : [];
  }

  // Public accessors

  metadataForPluginId(pluginId) {
    const metadata = this.metadataObjectForPluginId(pluginId);
    if (!metadata) {
      return null;
    }
    return metadata.value;
  }

  // Private helpers

  metadataObjectForPluginId(pluginId) {
    return this.pluginMetadata.find(metadata => metadata.pluginId === pluginId);
  }

  applyPluginMetadata(pluginId, metadataValue) {
    const clone = this.clone();

    let metadata = clone.metadataObjectForPluginId(pluginId);
    if (!metadata) {
      metadata = new PluginMetadata({pluginId});
      clone.pluginMetadata.push(metadata);
    }
    metadata.value = metadataValue;
    return clone;
  }

  setPluginMetadata(pluginMetadata) {
    this.pluginMetadata = pluginMetadata.map(({pluginId, value})=> {
      return new PluginMetadata({pluginId, value});
    })
    return this;
  }

}
