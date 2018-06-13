[![Build Status](https://img.shields.io/travis/AntiPhotonltd/kms-vault/master.svg)](https://travis-ci.org/AntiPhotonltd/kms-vault)
[![Software License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)
[![Release](https://img.shields.io/github/release/AntiPhotonltd/kms-vault.svg)](https://github.com/AntiPhotonltd/kms-vault/releases/latest)
[![Github commits (since latest release)](https://img.shields.io/github/commits-since/AntiPhotonltd/kms-vault/latest.svg)](https://github.com/AntiPhotonltd/kms-vault/commits)
[![GitHub repo size in bytes](https://img.shields.io/github/repo-size/AntiPhotonltd/kms-vault.svg)](https://github.com/AntiPhotonltd/kms-vault)
[![GitHub contributors](https://img.shields.io/github/contributors/AntiPhotonltd/kms-vault.svg)](https://github.com/AntiPhotonltd/kms-vault)

KMS Vault
=========

A bash script for managing secrets encrypted / decrypted via AWS KMS. The origin of the script was a requirement to protect eyaml keys at rest in a masterless puppet environment and 
was inspired by this [kms-vault gist](https://gist.github.com/hassy/96256cfde707fed40714c02b64f8049e)

The script has 3 operating modes:

1. [List available KMS keys](#list-keys)
2. [Encrypt a file](#encrypt-file)
3. [Decrypt a file](#decrypt-file)

## Usage

```
  Usage: ./kms-vault.sh [ -hdel ] [ -k key alias ] [ -f input filename ] [ -o output filename ]
    -h    : Print this screen
    -d    : decrypt a given file
    -e    : encrypt a given file
    -f    : The name of the name to encrypt
    -k    : The alias for the key to encrypt with
    -l    : List the available KSM key aliases/names
    -o    : Name of the output file
```

<a name="list-keys"></a>
## List Keys

```
./kms-vault.sh -l

Available Aliases:
1. alias/puppet
```

The alias name is used when encrypting the file contents. Not ALL KSM keys are listed, the script will not use a key which is AWS managed or 
any key which doesnt have a TargetKeyId attribute.

It is also possible that attempts to use certain keys might well be meet with the following error:

```
An error occurred (AccessDeniedException) when calling the Encrypt operation: <truncated output>
```

This is due to IAM restrictions to the key you are attempting to use, this normally happens with AWS managed keys forthings like S3 and RDS
which is why the script excludes them.

You are required to create your own KMS keys for encryption/decryption purposes. (A tool for creating this will be released shortly and the link placed here).

<a name="encrypt-file"></a>

## Encrypt File

```
./kms-vault.sh -e -f <input file> -k <key alias>
```

The output from the script will be a long base64 encoded string, the output can be redirected to a file (an output file option is on the todo list)

<a name="decrypt-file"></a>

## Decrypt File

```
./kms-vault.sh -d -f <input file>
```

The output from the script will be the decrypted contains of the file, the output can be redirected to a file (an output file option is on the todo list)


## ToDo

- [ ] Better validation and error handling
- [ ] Make region an option ??
- [ ] Validate the region if one is provided
- [X] Allow an output file to be specificed and write the encrypted text to that
- [ ] Have a debug mode / verbose mode

