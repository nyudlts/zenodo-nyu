#!/usr/bin/env bash

OPENSHIFT_SERVER=${OPENSHIFT_SERVER:-'https://openshift.cern.ch/'}
APPLICATION_IMAGE_NAME='zenodobrokerimage'

# check if the script is called from an OpenShift logged in console
oc whoami > /dev/null 2>&1
logged_in_with_oc="$?"

if [ -z "$OPENSHIFT_PROJECT_TOKEN" ]
then
    if [ logged_in_with_oc -ne 0 ]
    then
        echo 'Warning! You should login with oc client or provide a token.'
        echo 'See: oc https://openshift.cern.ch/console/command-line'
        echo '     or export OPENSHIFT_PROJECT_TOKEN=somesecret'
        exit 1
    fi
else
    # OpenShift server and token passed as parameters
    openshift_server_arg="--server=\"${OPENSHIFT_SERVER}\""
    openshift_token_arg="--token=\"${OPENSHIFT_PROJECT_TOKEN}\""
fi

usage() { echo "Usage: $0 <enviroment> <version-tag> [--yes-i-know]" 1>&2; exit 1; }

# defines mappings to have short aliases (`dev`, `qa`, `prod`) for OpenShift project names
input_enviroment=$1
case "$input_enviroment" in
    dev)
        ENVIRONMENT=dev
        OPENSHIFT_PROJECT_NAME='zenodo-broker-dev'
        ;;
    qa)
        ENVIRONMENT=qa
        OPENSHIFT_PROJECT_NAME='zenodo-broker-qa'
        ;;
    prod)
        ENVIRONMENT=prod
        OPENSHIFT_PROJECT_NAME='zenodo-broker'
        ;;
    *)
        echo 'Environment should be [dev|qa|prod].'
        usage
        ;;
esac

# Make sure that users logged in OpenShift with oc have selected the correct
# project for the given environment.
if [ $logged_in_with_oc -eq 0 ] && [ "$OPENSHIFT_PROJECT_NAME" != $(oc project --short) ]
then
    echo "You have selected the OpenShift project $(oc project --short) which does not correspond to the $ENVIRONMENT environment."
fi


VERSION=$2
confirmation=$3
if [ "$deploy" = "--yes-i-know" ]
then
    deploy=1
else
    read -p "Are you sure that you want to deploy version $VERSION? [y|n]" answer
    if [ "$answer" = "y" ]
    then
        deploy=1
    fi
fi

if [ -z "$deploy" ]
then
    echo 'You can start the deployment manually with `oc rollout latest dc/<web>` or through OpenShift UI.'
else
    # Import images to OpenShift
    # Update the tag named `latest` in OpenShift to point to the tag named with the version just linked above.
    # `latest` -> `1.2.0`
    # Example:
    # oc tag -n zenodo-broker-dev
    #        zenodo-broker:1.2.0 zenodo-broker:latest \
    #        <token> --server=https://openshift.cern.ch/
    oc tag -n ${OPENSHIFT_PROJECT_NAME} \
           ${APPLICATION_IMAGE_NAME}:${VERSION} ${APPLICATION_IMAGE_NAME}:$ENVIRONMENT \
           $openshift_token_arg $openshift_server_arg
    # Re-deploy all DeploymentConfigs using the updated image
    application_dc_list=`oc get dc --no-headers --selector template=invenio-application | awk '{$1=$1; print $1}'`
    echo -e "Re-deploying:\n$application_dc_list"
    for dc_name in $application_dc_list;
    do
        oc -n ${OPENSHIFT_PROJECT_NAME} \
           rollout latest dc/$dc_name \
           $openshift_token_arg $openshift_server_arg
    done
fi
