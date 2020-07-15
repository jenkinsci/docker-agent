#!/bin/bash

set -e

source env.props
export `cut -d= -f1 env.props`

make build

make test