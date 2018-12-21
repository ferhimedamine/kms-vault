#!/usr/bin/env bash

# -------------------------------------------------------------------------------- #
# Description                                                                      #
# -------------------------------------------------------------------------------- #
# A bash script for managing secrets encrypted / decrypted via AWS KMS.            #
# -------------------------------------------------------------------------------- #

# -------------------------------------------------------------------------------- #
# Global Variabes                                                                  #
# -------------------------------------------------------------------------------- #
# Various global varibles - commented inline.                                      #
# -------------------------------------------------------------------------------- #

SCRIPT_TITLE="KMS Vault"                            # Pretty header

LIST_KEYS=false                                     # Flag for listing keys
DECRYPT=false                                       # Flag for decryption
ENCRYPT=false                                       # Flag for encryption

# -------------------------------------------------------------------------------- #
# Required commands                                                                #
# -------------------------------------------------------------------------------- #
# These commands MUST exist in order for tyhe script to correctly run.             #
# -------------------------------------------------------------------------------- #

COMMANDS=( "aws" "jq" )

# -------------------------------------------------------------------------------- #
# List KSM Aliases                                                                 #
# -------------------------------------------------------------------------------- #
# This function will list all of the aliases that 'might' work, this means they    #
# contain an attribute called 'TargetKeyId'. This does not mean they WILL work     #
# but without that they definately will not.                                       #
# -------------------------------------------------------------------------------- #

list_ksm_aliases()
{
    ALIAS_COUNT=1

    show_success 'Available Aliases:'

    aws kms list-aliases | jq -cr ".Aliases[]" | while read -r key_info
    do
        key_id=$(echo "${key_info}" | jq -r .TargetKeyId)
        alias=$(echo "${key_info}" | jq -r .AliasName)

        if [[ -n "${key_id}" ]] && [[ "${key_id}" != "null" ]] && [[ "${alias}" != alias/aws/* ]]; then
            printf '%s%s.%s %s\n' "${green}" "${ALIAS_COUNT}" "${reset}" "${alias}"
            ALIAS_COUNT=$((ALIAS_COUNT+1))
        fi
    done
}

# -------------------------------------------------------------------------------- #
# Decrypt a file                                                                   #
# -------------------------------------------------------------------------------- #
# This function will take a the name of an encrypted file and attempt to decrypt   #
# the contents.                                                                    #
# -------------------------------------------------------------------------------- #

decrypt_file()
{
    ciphertext_path=$1
    output_filename=$2

    if ! [[ -f "${ciphertext_path}" ]]; then
        show_error "File ${ciphertext_path} not found - aborting decryption"
        return
    fi

    if [[ -z "${output_filename}" ]]; then
        aws kms decrypt --ciphertext-blob fileb://<(base64 --decode < "${ciphertext_path}") --output text --query Plaintext | base64 --decode
    else
        aws kms decrypt --ciphertext-blob fileb://<(base64 --decode < "${ciphertext_path}") --output text --query Plaintext | base64 --decode > "${output_filename}"
        show_success 'Results habe been written to: %s' "${output_filename}"
    fi
}

# -------------------------------------------------------------------------------- #
# Encrypt a file                                                                   #
# -------------------------------------------------------------------------------- #
# This function will take a the name of a file and a ksm key alias and attempt to  #
# encrypt the contents.                                                            #
# -------------------------------------------------------------------------------- #

encrypt_file()
{
    plaintext_path=$1
    key_alias=$2
    output_filename=$3

    if ! [[ -f "${plaintext_path}" ]]; then
        show_error "File ${plaintext_path} not found - aborting encryption"
        return
    fi

    key_info=$(aws kms list-aliases | jq -r ".Aliases[] | select(.AliasName | contains (\"${key_alias}\"))")
    keys=$(echo "$key_info" | jq -c '.' | wc -l)

    if [[ "${keys}" == 0 ]]; then
        abort_script "Key alias ${2} not found - aborting"
    fi

    if [[ "${keys}" -gt 1 ]]; then
        abort_script "Key alias returned ${keys} keys - please be more specific - aborting"
    fi

    key_id=$(echo "$key_info" | jq -r .TargetKeyId)
    alias=$(echo "$key_info" | jq -r .AliasName)

    if [[ "${alias}" == alias/aws/* ]]; then
      abort_script "Key alias ${2} is an AWS managed key and cannot be used"
    fi

    if [[ -z "${key_id}" ]] || [[ "${key_id}" == "null" ]]; then
        abort_script "Key alias ${2} has not TargetKeyId attribute - aborting"
    fi

    if [[ -z "${output_filename}" ]]; then
        aws kms encrypt --key-id "${key_id}" --plaintext "fileb://${plaintext_path}" --query CiphertextBlob --output text
    else
        aws kms encrypt --key-id "${key_id}" --plaintext "fileb://${plaintext_path}" --query CiphertextBlob --output text > "${output_filename}"
        show_success 'Results habe been written to: %s' "${output_filename}"
    fi
}

# -------------------------------------------------------------------------------- #
# Utiltity Functions                                                               #
# -------------------------------------------------------------------------------- #
# The following functions are all utility functions used within the script but     #
# are not specific to the display of the colours and only serve to handle things   #
# like, signal handling, user interface and command line option processing.        #
# -------------------------------------------------------------------------------- #

# -------------------------------------------------------------------------------- #
# Signal Handling                                                                  #
# -------------------------------------------------------------------------------- #
# This function is execute when a SIGINT or SIGTERM is caught. It allows us to     #
# exit the script nice and clean so do we not mess up the end users terminal.      #
# -------------------------------------------------------------------------------- #

control_c()
{
    printf '%s\n** Trapped CTRL-C **\n\n' "${reset}"
    show_footer
    exit
}

# -------------------------------------------------------------------------------- #
# Init                                                                             #
# -------------------------------------------------------------------------------- #
# A simple init function which will setup anything that is needed at the start of  #
# the script, for example set up the signal handler and work out the width of the  #
# screen that we have available.                                                   #
# -------------------------------------------------------------------------------- #

init()
{
    trap control_c SIGINT
    trap control_c SIGTERM
}

# -------------------------------------------------------------------------------- #
# Check Colours                                                                    #
# -------------------------------------------------------------------------------- #
# This function will check to see if we are able to support colours and how many   #
# we are able to support.                                                          #
#                                                                                  #
# The script will give and error and exit if there is no colour support or there   #
# are less than 8 supported colours.                                               #
#                                                                                  #
# Variables intentionally not defined 'local' as we want them to be global.        #
#                                                                                  #
# NOTE: Do NOT use show_error for the error messages are it requires colour!       #
# -------------------------------------------------------------------------------- #

check_colours()
{
    local ncolors

    red=''
    yellow=''
    green=''
    cls=''
    reset=''

    if ! test -t 1; then
        return
    fi

    if ! tput longname > /dev/null 2>&1; then
        return
    fi

    ncolors=$(tput colors)

    if ! test -n "${ncolors}" || test "${ncolors}" -le 7; then
        return
    fi

    red=$(tput setaf 1)
    yellow=$(tput setaf 3)
    green=$(tput setaf 2)
    cls=$(tput clear)
    reset=$(tput sgr0)
}

# -------------------------------------------------------------------------------- #
# Check Root                                                                       #
# -------------------------------------------------------------------------------- #
# If required ensure the script is running as the root user.                       #
# -------------------------------------------------------------------------------- #

check_root()
{
    if [[ $EUID -ne 0 ]]; then
        abort_script "This script must be run as root"
    fi
}

# -------------------------------------------------------------------------------- #
# Show Header                                                                      #
# -------------------------------------------------------------------------------- #
# A simple wrapper function to show the script header to the user.                 #
# -------------------------------------------------------------------------------- #

show_header()
{
    printf '%s%s%s%s\n' "${cls}" "${green}" "${SCRIPT_TITLE}" "${reset}"
}

# -------------------------------------------------------------------------------- #
# Abort Script                                                                     #
# -------------------------------------------------------------------------------- #
# A simple wrapper function to give an error and then exitthe script.              #
# -------------------------------------------------------------------------------- #

abort_script()
{
    show_error "${1}"
    exit 1
}

# -------------------------------------------------------------------------------- #
# Show Error                                                                       #
# -------------------------------------------------------------------------------- #
# A simple wrapper function to show something was an error.                        #
# -------------------------------------------------------------------------------- #

show_error()
{
    if [[ -n $1 ]]; then
        printf '%s%s%s\n' "${red}" "${*}" "${reset}" 1>&2
    fi
}

# -------------------------------------------------------------------------------- #
# Show Warning                                                                     #
# -------------------------------------------------------------------------------- #
# A simple wrapper function to show a warning.                                     #
# -------------------------------------------------------------------------------- #

show_warning()
{
    if [[ -n $1 ]]; then
        printf '%s%s%s\n' "${yellow}" "${*}" "${reset}" 1>&2
    fi
}

# -------------------------------------------------------------------------------- #
# Show Success                                                                     #
# -------------------------------------------------------------------------------- #
# A simple wrapper function to show a success.                                     #
# -------------------------------------------------------------------------------- #

show_success()
{
    if [[ -n $1 ]]; then
        printf '%s%s%s\n' "${green}" "${*}" "${reset}" 1>&2
    fi
}

# -------------------------------------------------------------------------------- #
# Check Prerequisites                                                              #
# -------------------------------------------------------------------------------- #
# Check to ensure that the prerequisite commmands exist.                           #
# -------------------------------------------------------------------------------- #

check_prereqs()
{
    local error_count=0

    for i in "${COMMANDS[@]}"
    do
        command=$(command -v "${i}")
        if [[ -z $command ]]; then
            show_error "$i is not in your command path"
            error_count=$((error_count+1))
        fi
    done

    if [[ $error_count -gt 0 ]]; then
        show_error "$error_count errors located - fix before re-running";
        exit 1;
    fi
}

# -------------------------------------------------------------------------------- #
# Usage (-h parameter)                                                             #
# -------------------------------------------------------------------------------- #
# This function is used to show the user 'how' to use the script.                  #
# -------------------------------------------------------------------------------- #

usage()
{
cat <<EOF
  Usage: $0 [ -hdel ] [ -k key alias ] [ -f input filename ] [ -o output filename ]
    -h    : Print this screen
    -d    : decrypt a given file
    -e    : encrypt a given file
    -f    : The name of the name to encrypt
    -k    : The alias for the key to encrypt with
    -l    : List the available KSM key aliases/names
    -o    : Name of the output file
EOF
    exit 1;
}

# -------------------------------------------------------------------------------- #
# Process Input                                                                    #
# -------------------------------------------------------------------------------- #
# This function will process the input from the command line and work out what it  #
# is that the user wants to see.                                                   #
#                                                                                  #
# This is the main processing function where all the processing logic is handled.  #
# -------------------------------------------------------------------------------- #

process_input()
{
    if [[ $# -eq 0 ]]; then
        usage
    fi

    while getopts ":hdelf:k:o:" arg; do
        case $arg in
            h)
                usage;
                ;;
            d)
                DECRYPT=true
                ;;
            e)
                ENCRYPT=true
                ;;
            l)
                LIST_KEYS=true
                ;;
            f)
                filename=$OPTARG
                ;;
            k)
                keyname=$OPTARG
                ;;
            o)
                output_filename=$OPTARG
                ;;
            :)
                show_error "Option -$OPTARG requires an argument."
                usage
                ;;
            \?)
                show_error "Invalid option: -$OPTARG"
                usage
                ;;
        esac
    done

    show_header

    if [[ "${LIST_KEYS}" = true ]]; then
        list_ksm_aliases
    elif [[ "${DECRYPT}" = true ]]; then
        if [[ -z "${filename}" ]]; then
            abort_script "You must supply the filename for the encrypted text"
        fi
        decrypt_file "${filename}" "${output_filename}"
    elif [[ "${ENCRYPT}" = true ]]; then
        if [[ -z "${filename}" ]]; then
            abort_script "You must supply the filename for the encrypted text"
        fi
        if [[ -z "${keyname}" ]]; then
            abort_script "You must supply the name for the key to use for encryption (use $0 -l for a list of available keys)"
        fi
        encrypt_file "${filename}" "${keyname}" "${output_filename}"
    else
        abort_script "You must select decrypt (-d) or encrypt (-e)"
    fi
}

# -------------------------------------------------------------------------------- #
# Main()                                                                           #
# -------------------------------------------------------------------------------- #
# This is the actual 'script' and the functions/sub routines are called in order.  #
# -------------------------------------------------------------------------------- #

#check_root

init
check_colours
check_prereqs
process_input "$@"

# -------------------------------------------------------------------------------- #
# End of Script                                                                    #
# -------------------------------------------------------------------------------- #
# This is the end - nothing more to see here.                                      #
# -------------------------------------------------------------------------------- #

