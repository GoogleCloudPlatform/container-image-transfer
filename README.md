This is not an officially supported Google product.

See LICENSE for license information.

# Background

This repo holds a script for dumping and transfering container images between registries while keeping digest unchanged. 

# Usage

To use the script, run 

```bash
dumpimage image dest-dir
```

You can laterly run the `auto.sh` in dest-dir to upload the image to another registry.
To use the generated `auto.sh`, you need to set the following environment variables:
 -  `TARGETHOST`: the hostname of private registry you want to push to.
 -  `TARGETNAMESPACE`: the namespace ifn that registry you want to push to, default is "library"
 -  `AUTHCRED`: the credentials used for authenticate to the registry, for basic authentication, 
        use this command to set(assume user and pass are username and password respectively):
        `export AUTHCRED="Basic $(echo -n $user:$pass|base64)"`

