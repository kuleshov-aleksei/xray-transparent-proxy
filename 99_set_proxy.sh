#!/bin/bash

PORT=1081

export HTTPS_PROXY=http://127.0.0.1:$PORT
export HTTP_PROXY=http://127.0.0.1:$PORT
export NO_PROXY=localhost,127.0.0.1

export http_proxy=http://127.0.0.1:$PORT
export https_proxy=http://127.0.0.1:$PORT
export all_proxy=http://127.0.0.1:$PORT
export no_proxy=localhost,127.0.0.1
