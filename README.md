[![Build Status](https://img.shields.io/travis/AntiPhotonltd/kms-vault/master.svg)](https://travis-ci.org/AntiPhotonltd/kms-vault)
[![Software License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)
[![Release](https://img.shields.io/github/release/AntiPhotonltd/kms-vault.svg)](https://github.com/AntiPhotonltd/kms-vault/releases/latest)
[![Github commits (since latest release)](https://img.shields.io/github/commits-since/AntiPhotonltd/kms-vaule/latest.svg)](https://github.com/AntiPhotonltd/kms-vault/commits)
[![GitHub repo size in bytes](https://img.shields.io/github/repo-size/AntiPhotonltd/kms-vault.svg)](https://github.com/AntiPhotonltd/kms-vault)
[![GitHub contributors](https://img.shields.io/github/contributors/AntiPhotonltd/kms-vault.svg)](https://github.com/AntiPhotonltd/kms-vault)

KMS Vault
=========

A bash script for managing secrets encrypted / decrypted via AWS KMS. The origin of the script was a requirement to protect eyaml keys at rest in a masterless puppet environment.

The script has 3 operating modes:

1. [List available KMS keys](#list-keys)
2. [Encrypt a file](#encrypt-file)
3. [Decrypt a file](#decrypt-file)

## Usage

```
  Usage: ./kms-vault.sh [ -hdel ] [ -k key alias ] [ -f filename ]
    -h    : Print this screen
    -d    : decrypt a given file
    -e    : encrypt a given file
    -f    : The name of the name to encrypt
    -k    : The alias for the key to encrypt with
    -l    : List the available KSM key aliases/names
```

<a name="list-keys"></a>
## List Keys

```
./kms-vault.sh -l

Available Aliases:
1. alias/aws/ebs
2. alias/aws/lambda
3. alias/aws/rds

```

The alias name is used when encrypting the file contents. Not ALL KSM keys are listed, any key which doesnt have a TargetKeyId attribute cannot be used.
It is also possible that attempts to use certain keys might well be meet with the following error:

```
An error occurred (AccessDeniedException) when calling the Encrypt operation: <truncated output>
```

This is due to IAM restrictions to certain keys espcially AWS self generated keys forthings like S3 and RDS. It is advised that you create your own KMS keys for encryption/decryption purposes.

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
- [ ] Allow an output file to be specificed and write the encrypted text to that
- [ ] Have a debug mode / verbose mode

