# Less Cache [![CI](https://github.com/pulsar-edit/less-cache/actions/workflows/ci.yml/badge.svg)](https://github.com/pulsar-edit/less-cache/actions/workflows/ci.yml)
Caches the compiled `.less` files as `.css`.

## Using

```sh
npm install less-cache
```

```coffeescript
LessCache = require 'less-cache'

cache = new LessCache(cacheDir: '/tmp/less-cache')
css = cache.readFileSync('/Users/me/apps/static/styles.less')
```
