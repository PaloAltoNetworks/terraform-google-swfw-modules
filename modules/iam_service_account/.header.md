# IAM Service Account

Create a dedicated IAM Service Account that will be used to run firewall instances.
This module is optional - even if you don't use it, firewalls run fine on the default Google Service Account.

The account produced by this module is intended to have minimal required permissions.

[Google Cloud Docs](https://cloud.google.com/compute/docs/access/create-enable-service-accounts-for-instances#best_practices)
