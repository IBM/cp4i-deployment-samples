#!/bin/bash

# Send requests to the Bookshop API service
# Use --help for details

cd $(dirname $0)/..
exec python -m bookshop.bookshop_client "$@"
