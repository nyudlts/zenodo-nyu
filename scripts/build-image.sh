#!/bin/bash

GITLAB_BRANCH=master
GITLAB_PIPELINE_TRIGGER_URL="https://gitlab.cern.ch/api/v4/projects/39370/trigger/pipeline"

if [ -z $GITLAB_PIPELINE_TRIGGER_TOKEN ]; then
    read -s -p "Pipeline trigger token: " GITLAB_PIPELINE_TRIGGER_TOKEN
fi

usage() { echo "Usage: $0 [-b <branch> | -c <commit> | -t <tag> | -p <pull-request>]" 1>&2; exit 1; }

if [ $# -le 2 ]
then
    case "${1}" in
        -b|--branch)
            type='BRANCH_NAME'
            value=$2
            docker_image_tag=$value
            echo "Building image from branch $value"
            ;;
        -c|--commit)
            type='COMMIT_ID'
            value=$2
            docker_image_tag=$value
            echo "Building image from commit $value"
            ;;
        -t|--tag)
            type='TAG_NAME'
            value=$2
            docker_image_tag=$value
            echo "Building image from tag $value"
            ;;
        -p|--pull-request)
            type='PR_ID'
            value=$2
            docker_image_tag="pr-$value"
            echo "Building image from pull request $value"
            ;;
        *)
            echo Do you want to build from master branch? "(Y or N)"
            read answer
            # now check if $x is "y"
            if [ "$answer" = "y" ]; then
                type='BRANCH_NAME'
                value='master'
                docker_image_tag='latest'
                echo "Building image from branch $value"
            else
                usage
            fi
            ;;
    esac
else
    usage
fi

curl -X POST \
     -F token=${GITLAB_PIPELINE_TRIGGER_TOKEN} \
     -F ref=${GITLAB_BRANCH} \
     -F "variables[CACHE_DATE]=$(date +%Y-%m-%d:%H:%M:%S)" \
     -F "variables[${type}]=${value}" \
     -F "variables[IMAGE_TAG]=${docker_image_tag}" \
     "$GITLAB_PIPELINE_TRIGGER_URL"
