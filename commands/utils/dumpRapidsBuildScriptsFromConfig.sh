#!/bin/bash

USAGE="
USAGE: $0
"

if (( $# > 0 )); then
    echo "${USAGE}"
    exit 1
fi

THISDIR=$(dirname $0)
RAPIDSDEVTOOL_DIR=${THISDIR}/../..
source ${THISDIR}/common.sh

#
# awk script processes config file line-by-line.
# Extract the URLs
#
awk --assign debug=${DEBUG} \
    --assign utilsDir=${UTILS_DIR} '
    BEGIN {
       inRapidsSection = 0
    }
    /^# SECTION: RAPIDS.*$/ {
       inRapidsSection = 1
       next
    }
    /^# SECTION: .*$/ {
       inRapidsSection = 0
       next
    }
    /^[a-zA-Z0-9_\-]+_REPO=.+$/ {
       if (inRapidsSection == 0) {
          next
       }
       # Assume repo is a URL similar to https://github.com/rapidsai/cudf.git
       split($0, fields, "/")
       last = fields[length(fields)]
       split(last, fields, ".")
       comp = fields[1]
       rapidscomps[comp] = 1
       next
    }
    END {
       split("cudf cuml xgboost dask-xgboost dask-cudf dask-cuda", buildorder)
       for (i in buildorder) {
          comp = buildorder[i]
          if (comp in rapidscomps) {
             script = utilsDir "/build-" comp ".sh"
             # Not all comps have a build script, so skip if script DNE
             if (system("ls " script ">/dev/null 2>&1") != 0) {
                continue
             }
             printf("####################\n# %s\n\n", comp)
             while ((getline line < script) > 0) {
                # Only print lines not starting with #!
                if (index(line, "#!") == 1) {
                   continue
                }
                   printf("%s\n", line)
             }
             printf("\n")
          }
       }
    }
    ' ${CONFIG_FILE_NAME}
