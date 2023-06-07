# Overview
The `create-catalog-sources.sh` script in the parent dir contains a block of yaml for the catalog source CRs.
This yaml needs to be re-calculated for each new release of CP4I and doing this manually is a pain, so this
dir provides a script to help do this.

## find-catalog-images.sh
This script finds the latest catalog sources for the cases listed at the top of the script and the output
can be copied directly into the `create-catalog-sources.sh` script.
```
./find-catalog-images.sh
```

When a new version of CP4I is released then copy the contents of the table of cases from the relevant docs
page, copy/paste into the top of `find-catalog-images.sh`, then re-run.
