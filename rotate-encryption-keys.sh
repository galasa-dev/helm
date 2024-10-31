#! /usr/bin/env bash

#
# Copyright contributors to the Galasa project
#
# SPDX-License-Identifier: EPL-2.0
#

#-----------------------------------------------------------------------------------------
#
# Objective: Rotates the encryption key currently being used to encrypt secrets in
# the Galasa Ecosystem and re-encrypts secrets using the new encryption key
#
# Environment variable overrides:
# None
#
#-----------------------------------------------------------------------------------------

# Where is this script executing from?
BASEDIR=$(dirname "$0");pushd $BASEDIR 2>&1 >> /dev/null ;BASEDIR=$(pwd);popd 2>&1 >> /dev/null

cd "${BASEDIR}/.."
WORKSPACE_DIR=$(pwd)

#-----------------------------------------------------------------------------------------
#
# Set Colors
#
#-----------------------------------------------------------------------------------------
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 76)
white=$(tput setaf 7)
tan=$(tput setaf 202)
blue=$(tput setaf 25)

#-----------------------------------------------------------------------------------------
#
# Headers and Logging
#
#-----------------------------------------------------------------------------------------
underline() { printf "${underline}${bold}%s${reset}\n" "$@" ;}
h1() { printf "\n${underline}${bold}${blue}%s${reset}\n" "$@" ;}
h2() { printf "\n${underline}${bold}${white}%s${reset}\n" "$@" ;}
debug() { printf "${white}%s${reset}\n" "$@" ;}
info() { printf "${white}➜ %s${reset}\n" "$@" ;}
success() { printf "${green}✔ %s${reset}\n" "$@" ;}
error() { printf "${red}✖ %s${reset}\n" "$@" ;}
warn() { printf "${tan}➜ %s${reset}\n" "$@" ;}
bold() { printf "${bold}%s${reset}\n" "$@" ;}
note() { printf "\n${underline}${bold}${blue}Note:${reset} ${blue}%s${reset}\n" "$@" ;}

#-----------------------------------------------------------------------------------------
# Functions
#-----------------------------------------------------------------------------------------
function usage {
    h1 "A helper script to rotate Galasa ecosystem encryption keys."
    info "The following command-line tools must be installed before running this script:"
    cat << EOF
kubectl (v1.30.3 or later)
openssl (3.3.2 or later)
galasactl (0.38.0 or later)
EOF
    info "Syntax: rotate-encryption-keys.sh [OPTIONS]"
    cat << EOF
Options are:
--release-name <name> : Required. The Helm release name provided when the Galasa ecosystem Helm chart was installed.
--clear-fallback-keys : Optional. If provided, the fallback decryption keys list will be cleared from the Kubernetes Secret containing the Galasa encryption keys.
-b | --bootstrap <bootstrap-url> : Optional. The bootstrap URL of the Galasa ecosystem that is being serviced. Not required if the GALASA_BOOTSTRAP environment variable is set and is pointing to the correct bootstrap URL.
-n | --namespace <namespace> : Optional. The Kubernetes namespace in which your Galasa ecosystem is running. By default, the namespace pointed to by the current Kubernetes context will be used.
EOF
}

function check_exit_code {
    # This function takes 2 parameters in the form:
    # $1 an integer value of the returned exit code
    # $2 an error message to display if $1 is not equal to 0
    return_code=$1
    error_msg=$2

    if [[ "${return_code}" != "0" ]]; then
        error "${error_msg}. Log file is at ${LOG_FILE}"
        exit 1
    fi
}

function check_tool_installed {
    # This function takes 1 parameter:
    # $1 the name of the tool to look for
    tool_name=$1
    h2 "Checking ${tool_name} is installed..."

    which ${tool_name} 2>&1 > /dev/null
    rc=$?

    check_exit_code ${rc} "${tool_name} is not installed. Install it and try again. rc=${rc}"
    success "${tool_name} is installed OK"
}

function check_required_tools_installed {
    h1 "Checking required CLI tools are installed"

    check_tool_installed "kubectl"
    check_tool_installed "openssl"
    check_tool_installed "galasactl"

    success "All required tools are already installed OK"
}

function check_galasactl_auth {
    h1 "Logging into the Galasa ecosystem"

    info "Bootstrap URL is ${GALASA_BOOTSTRAP}"

    cmd="galasactl auth login"
    info "Running command: ${cmd}"

    ${cmd} 2>&1 | tee -a "${LOG_FILE}"
    rc=$?
    check_exit_code ${rc} "Failed to log in to the Galasa ecosystem secret. Check that a personal access token has been set and try again. rc=${rc}"
    success "Logged in to the Galasa ecosystem OK"
}

function get_existing_encryption_keys {
    h1 "Retrieving encryption keys"

    # Get the current secret data
    decoded_secret_data=$(kubectl get secret ${ENCRYPTION_SECRET_NAME} \
        ${KUBECTL_NAMESPACE_FLAG} \
        --output jsonpath="{ .data.encryption-keys\.yaml }" | base64 --decode)
    rc=$?
    check_exit_code ${rc} "Failed to get encryption keys from ${ENCRYPTION_SECRET_NAME} secret. Check that the value for the --release-name flag matches an existing Helm release and try again. rc=${rc}"

    # Extract the current encryption key
    export CURRENT_KEY=$(echo "${decoded_secret_data}" | grep "encryptionKey:" | awk '{print $2}')
    rc=$?
    check_exit_code ${rc} "Failed to get current encryption key from ${ENCRYPTION_SECRET_NAME} secret. rc=${rc}"

    # Extract the fallback decryption keys list
    export FALLBACK_KEYS=$(echo "${decoded_secret_data}" | awk '/^fallbackDecryptionKeys:/,/^$/' | tail -n +2)
    rc=$?
    check_exit_code ${rc} "Failed to get fallback keys from ${ENCRYPTION_SECRET_NAME} secret. rc=${rc}"

    success "Existing keys retrieved OK"
}

function rotate_encryption_keys {
    h1 "Rotating encryption keys"

    # Create a new AES256 encryption key - this must be 32 characters long for 256-bit keys
    info "Creating new encryption key..."
    cmd="openssl rand -base64 32"

    info "Running command: ${cmd}"
    new_key=$(${cmd})
    rc=$?
    check_exit_code ${rc} "Failed to create a new encryption key. rc=${rc}"
    success "Created new encryption key OK"

    # Add the existing encryption key to the start of the fallback keys list
    updated_fallback_keys_yaml=$(cat << EOF
fallbackDecryptionKeys:
- ${CURRENT_KEY}
${FALLBACK_KEYS}
EOF
)

    # Update the Kubernetes Secret with the rotated encryption keys
    patch_encryption_keys "${new_key}" "${updated_fallback_keys_yaml}"
    success "Successfully rotated encryption keys"
}

function restart_deployment {
    # This function takes 1 parameter:
    # $1 the deployment name to wait for
    deployment_name=$1

    kubectl rollout restart deployment ${deployment_name} ${KUBECTL_NAMESPACE_FLAG} 2>&1 | tee -a "${LOG_FILE}"
    rc=$?
    check_exit_code ${rc} "Failed to issue command to restart the ${deployment_name} deployment. Check that the value for the --release-name flag matches an existing Helm release and try again. rc=${rc}"

    # Wait for the rollout to complete
    kubectl rollout status deployment "${deployment_name}" ${KUBECTL_NAMESPACE_FLAG} --timeout=3m 2>&1 | tee -a "${LOG_FILE}"
    rc=$?
    check_exit_code ${rc} "Failed to wait for ${deployment_name} to be restarted. rc=${rc}"
}

function restart_deployments {
    h1 "Restarting Galasa ecosystem deployments to use new encryption keys"

    info "Restarting API server..."
    restart_deployment "${API_DEPLOYMENT_NAME}"
    success "API server restarted OK"

    info "Restarting engine controller..."
    restart_deployment "${ENGINE_CONTROLLER_DEPLOYMENT_NAME}"
    success "Engine controller restarted OK"

    success "Restarted ecosystem deployments OK"
}

function get_existing_secrets {
    h1 "Getting existing Galasa Secrets"

    cmd="galasactl-dev secrets get --format yaml"
    info "Running command: ${cmd}"

    ${cmd} > ${SECRETS_FILE}
    rc=$?
    check_exit_code ${rc} "Failed to get secrets from the Galasa ecosystem. rc=${rc}"
    success "Existing secrets stored at ${SECRETS_FILE}"
}

function migrate_secrets {
    h1 "Re-encrypting existing Galasa Secrets with new encryption keys"

    if [[ ! -s "${SECRETS_FILE}" ]]; then
        info "No secrets found to re-encrypt"
        success "OK"
    else
        info "Re-applying secrets"
        cmd="galasactl-dev resources apply -f ${SECRETS_FILE}"

        info "Running command: ${cmd}"
        ${cmd} 2>&1 | tee -a "${LOG_FILE}"
        rc=$?
        check_exit_code ${rc} "Failed to re-apply secrets to the Galasa ecosystem. rc=${rc}"
        success "Successfully re-encrypted existing Galasa Secrets"
    fi
}

function patch_encryption_keys {
    # This function takes 2 parameters:
    # $1 a base64-encoded encryption key string to be the primary encryption key
    # $2 a string representing the fallbackDecryptionKeys key-value pair in YAML format
    encryption_key=$1
    fallback_decryption_keys_yaml=$2
    
    # Convert the keys into the expected YAML structure to be placed inside the secret
    yaml=$(cat << EOF
encryptionKey: ${encryption_key}
${fallback_decryption_keys_yaml}
EOF
)
    encoded_yaml=$(echo -n "${yaml}" | base64)
    patch=$(cat << EOF
data:
    encryption-keys.yaml: ${encoded_yaml}
EOF
)
    # Update the Kubernetes Secret
    echo "${patch}" | kubectl patch secret "${ENCRYPTION_SECRET_NAME}" ${KUBECTL_NAMESPACE_FLAG} --patch-file /dev/stdin 2>&1 | tee -a "${LOG_FILE}"
    rc=$?
    check_exit_code ${rc} "Failed to patch the encryption keys secret. rc=${rc}"
}

function clear_fallback_keys {
    h1 "Clearing fallback decryption keys"
    get_existing_encryption_keys

    # Reset the fallback decryption keys list to be an empty list
    updated_fallback_keys_yaml=$(cat << EOF
fallbackDecryptionKeys: []
EOF
)
    patch_encryption_keys "${CURRENT_KEY}" "${updated_fallback_keys_yaml}"
    success "Successfully cleared fallback decryption keys"
}

#-----------------------------------------------------------------------------------------
# Process parameters
#-----------------------------------------------------------------------------------------
NAMESPACE=""
RELEASE_NAME=""

while [ "$1" != "" ]; do
    case $1 in
        -n | --namespace )      shift
                                export NAMESPACE=$1
                                ;;
        --release-name )        shift
                                export RELEASE_NAME=$1
                                ;;
        -b | --bootstrap )      shift
                                export GALASA_BOOTSTRAP=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     error "Unexpected argument $1"
                                usage
                                exit 1
    esac
    shift
done

if [[ -z ${RELEASE_NAME} ]]; then
    error "A release name must be provided using the --release-name flag."
    usage
    exit 1
fi

#-----------------------------------------------------------------------------------------
# Main program logic
#-----------------------------------------------------------------------------------------
set -o pipefail

ENCRYPTION_SECRET_NAME="${RELEASE_NAME}-encryption-secret"
API_DEPLOYMENT_NAME="${RELEASE_NAME}-api"
ENGINE_CONTROLLER_DEPLOYMENT_NAME="${RELEASE_NAME}-engine-controller"

KUBECTL_NAMESPACE_FLAG=""
if [[ -n ${NAMESPACE} ]]; then
    KUBECTL_NAMESPACE_FLAG="--namespace ${NAMESPACE}"
fi

# Create temp directory and log file
TEMP_DIR="${BASEDIR}/temp"
mkdir -p "${TEMP_DIR}"
LOG_FILE="${TEMP_DIR}/rotate-${RELEASE_NAME}-keys.txt"
> "${LOG_FILE}"

SECRETS_FILE="${TEMP_DIR}/secrets.yaml"

# Before starting the rotation process, check that we have all the tools required
# and that we can authenticate with the Galasa ecosystem
check_required_tools_installed
check_galasactl_auth

get_existing_secrets
get_existing_encryption_keys
rotate_encryption_keys
restart_deployments
migrate_secrets

clear_fallback_keys
restart_deployments
success "Successfully rotated encryption keys and re-encrypted secrets!"