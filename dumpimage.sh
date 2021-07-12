#!/bin/bash
# Copyright 2021 Google LLC
# Author: Jun Sheng
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if ! which crane &>/dev/null
then
  echo please install crane first >&2
  exit 1
fi
if ! which jq &>/dev/null
then
  echo please install jq first >&2
  exit 1
fi

fetch_plain(){
  local DSTIMG=$1
  local TAG=$2
  local DIGEST=$3

  cat <<EOF >> "$OUTPUT".sh
#!/bin/bash
crane push $DIGEST.tar \$TARGETHOST/\${TARGETNAMESPACE:-library}/$DSTIMG
curl -H "Content-Type: application/vnd.docker.distribution.manifest.v2+json"\\
   -H "Authorization: \$AUTHCRED"\\
   --data-binary @$DIGEST.json -X PUT \\
    https://\$TARGETHOST/v2/\${TARGETNAMESPACE:-library}/${DSTIMG%:*}/manifests/sha256:$DIGEST
crane tag \$TARGETHOST/\${TARGETNAMESPACE:-library}/${DSTIMG%:*}@sha256:$DIGEST $TAG
EOF
}

fetch_multi() {
  local SRCIMG=$1
  local DSTIMG=$2
  local TAG=$3
  local DIGEST=$4
  for DGST in $(jq -r .manifests[].digest "$DIGEST".json)
  do
    crane manifest "$SRCIMG@$DGST" > "${DGST#sha256:}".json
    crane pull "$SRCIMG@$DGST ${DGST#sha256:}.tar"
    fetch_plain "$DSTIMG $TAG ${DGST#sha256:}"
  done
  cat <<EOF >> "$OUTPUT".sh
#!/bin/bash
curl -H "Content-Type: application/vnd.docker.distribution.manifest.list.v2+json"\\
   -H "Authorization: \$AUTHCRED"\\
   --data-binary @$DIGEST.json -X PUT \\
    https://\$TARGETHOST/v2/\${TARGETNAMESPACE:-library}/${DSTIMG%:*}/manifests/sha256:$DIGEST
crane tag \$TARGETHOST/\${TARGETNAMESPACE:-library}/${DSTIMG%:*}@sha256:$DIGEST $TAG
EOF
}

fetch() {
  local SRCIMG=$1
  if [ "$SRCIMG" == "${SRCIMG%%/*}" ]
  then
    local DSTIMG="$SRCIMG"
  else
    HPART="${SRCIMG%%/*}"
    if [ "$HPART" == "${HPART%%.*}" ]
    then
      local DSTIMG="$SRCIMG"
    else
      local DSTIMG=${SRCIMG#*/}
    fi
  fi
  local TAG=${DSTIMG#*:}
  if [ "$TAG" == "$DSTIMG" ]
  then
    local TAG=latest
  fi

  local DIGEST
  DIGEST=$(crane digest "$SRCIMG$HASH" | sed 's/^sha256://')
  export OUTPUT="auto"
  rm -f $OUTPUT.sh
  cat <<EOF > $OUTPUT.sh
#!/bin/bash
# Copyright 2021 Google LLC
#

if [ x"\$AUTHCRED" = x ]
then
  echo AUHCRED not defined
  exit 1
fi

EOF
  crane manifest "$SRCIMG$HASH" > "$DIGEST".json
  case $(jq -r .mediaType "$DIGEST".json) in
    application/vnd.docker.distribution.manifest.list.v2+json)
      fetch_multi "$SRCIMG $DSTIMG $TAG $DIGEST"
      ;;
    application/vnd.docker.distribution.manifest.v2+json)
      crane pull "$SRCIMG" "$DIGEST".tar
      fetch_plain "$DSTIMG" "$TAG" "$DIGEST"
      ;;
  esac
}

usage() {
  cat <<EOF >&2
Usage: $0 [-h] image dest-dir

Download and save image contents and manifests in dest-dir.
You can laterly run the \`auto.sh\' in dest-dir to upload the image to another registry.
To use the generated \`auto.sh\', you need to set the following environment variables:
    TARGETHOST: the hostname of private registry you want to push to.
    TARGETNAMESPACE: the namespace ifn that registry you want to push to, default is "library"
    AUTHCRED: the credentials used for authenticate to the registry, for basic authentication, 
        use this command to set(assume user and pass are username and password respectively):
        export AUTHCRED="Basic \$(echo -n \$user:\$pass|base64)"
EOF
  exit 1
}

while getopts ":h" arg; do
  case $arg in
    h)
      usage
      exit 0
      ;;
    *)
      exit 0
      ;;
  esac
done

if [ $# -lt 2 ]
then
  usage
  exit 1
fi

set -e
mkdir "$2" 
cd "$2"
fetch "$1"

