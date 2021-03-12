# Includes

The content of this directory contains all configurations
that will be included by [Common.json](./Common.json).

`_Docker.json` file is git-ignored. To be able to run examples, it is required to create
your version of this file:

```json
{
  "variables": {
    "DOCKER": {
      "LOGIN": {
        "ACCOUNT": "your_docker_account",
        "PASSWORD": "your_docker_password"
      }
    }
  }
}
```

