#!/bin/bash

# Send requests to the Bookshop API service
# Use --help for details

cd $(dirname $0)/..
exec python3 -m bookshop.bookshop_client "$@"
