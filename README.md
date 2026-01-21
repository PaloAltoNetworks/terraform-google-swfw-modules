![GitHub release (latest by date)](https://img.shields.io/github/v/release/PaloAltoNetworks/terraform-google-swfw-modules?style=flat-square)
![GitHub](https://img.shields.io/github/license/PaloAltoNetworks/terraform-modules-swfw-ci-workflows?style=flat-square)
![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/PaloAltoNetworks/terraform-google-swfw-modules/release_ci.yml?style=flat-square)
![GitHub issues](https://img.shields.io/github/issues/PaloAltoNetworks/terraform-google-swfw-modules?style=flat-square)
![GitHub pull requests](https://img.shields.io/github/issues-pr/PaloAltoNetworks/terraform-google-swfw-modules?style=flat-square)
![Terraform registry downloads total](https://img.shields.io/badge/dynamic/json?color=green&label=downloads%20total&query=data.attributes.total&url=https%3A%2F%2Fregistry.terraform.io%2Fv2%2Fmodules%2FPaloAltoNetworks%2Fswfw-modules%2Fgoogle%2Fdownloads%2Fsummary&style=flat-square)
![Terraform registry download month](https://img.shields.io/badge/dynamic/json?color=green&label=downloads%20this%20month&query=data.attributes.month&url=https%3A%2F%2Fregistry.terraform.io%2Fv2%2Fmodules%2FPaloAltoNetworks%2Fswfw-modules%2Fgoogle%2Fdownloads%2Fsummary&style=flat-square)

# Terraform Modules for Palo Alto Networks Software Firewalls on Google Cloud Platform

## Overview

A set of modules for using **Palo Alto Networks Software Firewalls** to provide control and protection
to your applications running on Google Cloud Platform (GCP). It deploys Software Firewalls and it configures aspects such as Shared VPC connectivity, IAM access, Service Accounts, Panorama virtual
machine instances, and more.

The design is heavily based on the [Reference Architecture Guide for Google Cloud Platform](https://pandocs.tech/fw/160p-prime).

For copyright and license see the LICENSE file.

## Structure

This repository has the following directory structure:

* [modules](./modules): This directory contains several standalone, reusable, production-grade Terraform modules. Each module is individually documented.
* [examples](./examples): This directory shows examples of different ways to combine the modules contained in the
  `modules` directory.

## Compatibility

The compatibility with Terraform is defined individually per each module. In general, expect the earliest compatible
Terraform version to be 1.0.0 across most of the modules.
<!-- [FUTURE] If you need to stay on Terraform 0.15.3 and need to use these modules, the recommended last compatible release is 1.2.3. -->

## Roadmap

We are maintaining a [public roadmap](https://github.com/orgs/PaloAltoNetworks/projects/33/views/8) to help users understand when we will release new features, bug fixes and enhancements.

## Versioning

These modules follow the principles of [Semantic Versioning](http://semver.org/). You can find each new release,
along with the changelog, on the GitHub [Releases](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/releases) page.

## Getting Help

[Open an issue](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/issues) on Github.

## Contributing

Contributions are welcome, and they are greatly appreciated! Every little bit helps,
and credit will always be given. Please follow our [contributing guide](https://github.com/PaloAltoNetworks/terraform-best-practices/blob/main/CONTRIBUTING.md).

<!-- ## Who maintains these modules?

This repository is maintained by [Palo Alto Networks](https://www.paloaltonetworks.com/).
If you're looking for commercial support or services, send an email to [address not known yet]. -->
