# Configuration and its persistence

Gateway needs configuration in order to work. It needs it to determine service configuration, hostname, etc.

Gateway can load the configuration from file, API or write it through management API (for debugging purposes).

## Configuration loading

### File

Can be loaded in `init` and `init_worker` before server starts serving requests. 

### API (autoload)

Can't be used in `init` or `init_worker` as cosocket API is not available. Would have to be pushed to background via `ngx.timer.at`.

### Management API

Can push configuration to the gateway via an API. 

## Configuration storage

Gateway needs to cache the configuration somewhere. Possibly even across restarts.

### Global variable

Just not scalable. Disappears on every request with `lua_code_cache off`.

### Shared Memory

Needs to serialize configuration into a string. Does not survive restarts. Size is allocated on boot. Shared across workers.

### LRU Cache (lua-resty-lrucache)

Does not use shared memory, but has eviction algorithm to keep maximum number of items. Local to the worker.

### File

Can survive restart. Still needs some other method to act as cache.

## Multi-tenancy

3scale hosts thousands of gateways for its customers and needs a reasonable way to share resources between them. Multi-tenant deployment of this proxy is the preferred way.

TODO: figure out how to store/load the configuration in multi-tenant way


## How config is loaded:

The following are the three main components in an APIcast configuration:

- configuration_loader: this is an object that retrieves the configuration and the
OIDC config for all services. There are three type of configuration_loader:
    - file: for using local file and THREESCALE_CONFIG_FILE
    - remote_v1: this is what we used in the past, to load all the config from
      system and spec.json, using THREESCALE_PORTAL_ENDPOINT.
    - remote_v2: This is the recommended way for retrieving the config for each service, to auto-discover the OIDC information, and it uses the THREESCALE_PORTAL_ENDPOINT env variable.
- configuration_store: this object stores the configuration into the Openresty cache and uses it at different phases.
- policy/load-configuration: this policy loads first by default and works in the following scenarios:
    - init phase: started the configuration_store
    - init_worker phase: retrieves the config using configuration_loader and sends the configuration_store object, which saves the config retrieved
    - rewrite phase: looks for the service for the requested host, and sets the service config on that request.

