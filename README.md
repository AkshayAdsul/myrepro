# Edge  Issue Reproducer



## Setup Instructions

Start by setting up the cluster

```bash
./setup-kind-gloo.sh
```

This script will set up a Kind cluster with Gloo Edge and Gloo Portal. 
Currently Gloo Portal steps are commented out from the setup-kind-gloo.sh script.
You can uncomment if Gloo Portal set up is needed

Make sure to export GLOO_LICENSE_KEY with a valid license key.
Please contact for license key.

Currently Edge version which is installed is 1.18.11
 Please change it according to your need.
