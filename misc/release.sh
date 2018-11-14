#! /usr/bin/env bash

# paths
project_path=$(dirname $(dirname $(readlink -f $0)))
app_path=$project_path/app
build_path=$project_path/build

now=$(date "+%Y%m%d-%H%M%S")
binary_name=app-$now

# error code
BUMPVERSION_FAILED=-1
TESTING_FAILED=-2
BUILDING_FAILED=-3

build() {
    # Bump version
    release_part=$1
    default_part=patch
    part=${release:-$default_part}  # major minor patch
    # check bumpversion
    if !(python -c "import bumpversion" > /dev/null 2>&1)
    then
        echo >&2 "No bumpversion, install it"
        pip install -U bumpversion
    fi
    echo "Bumping version"
    bumpversion --commit --message '[{now:%Y-%m-%d}] Jenkins Build {$BUILD_NUMBER}: {new_version}' --tag $part $app_path/apis/init.go
    if [ $? -eq 0 ]
    then
        echo "Bump version complete."
    else
        echo "!! Bump version failed."
        exit $BUMPVERSION_FAILED
    fi

    # Running tests
    echo "Running tests"
    if !(go test -v $app_path/...)
    then
        echo "!! Testing failed."
        exit $TESTING_FAILED
    fi

    # Update docs
    echo "Updating swag docs"
    # check swag
    if !(swag > /dev/null 2>&1)
    then
        echo >&2 "!No swag, install it"
        go get -u github.com/swaggo/swag/cmd/swag
    fi
    cd $app_path
    swag init -g apis/init.go
    cd -

    # Building
    echo "Building..."
    # check build directory
    if [ ! -d "$build_path" ]; then
        mkdir $build_path
    fi
    go build -o $build_path/$binary_name -tags=jsoniter -v $app_path
    if [ $? -ne 0 ]
    then
        echo "!! Building failed."
        exit $BUILDING_FAILED
    fi
}

build $1
