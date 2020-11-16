#!/bin/bash -e

## !! This script uses internal and undocumented APIs they are subject to change at any point, do not use in production.

CURRENT_DIR=$(dirname $0)

USING_OPERATORS=false

### Inputs
help="Usage $0 \n-r optional: release-name \n-n optional: namespace \n-g optional: git_remote_url \n-t optional: remote name \n-d optional: remote desc\n-o: Using operators version of asset repo"
while getopts "r:n:a:u:p:t:g:d:o" opt; do
  case ${opt} in
  r)
    RELEASE_NAME="$OPTARG"
    ;;
  n)
    NAMESPACE="$OPTARG"
    ;;
  a)
    echo "-a option ignored"
    ;;
  u)
    echo "-u option ignored"
    ;;
  p)
    echo "-p option ignored"
    ;;
  g)
    GIT_REPO="$OPTARG"
    ;;
  t)
    REMOTE_NAME="$OPTARG"
    ;;
  d)
    REMOTE_DESC="$OPTARG"
    ;;
  o)
    USING_OPERATORS=true
    ;;
  \?)
    echo -e $help
    ;;
  esac
done

## Defaults
NAMESPACE=${NAMESPACE:-integration}
RELEASE_NAME=${RELEASE_NAME:-demo}
GIT_REPO=${GIT_REPO:-"https://github.com/IBM/cp4i-demos.git"}
REMOTE_NAME=${REMOTE_NAME:-"CP4I Demo Assets"}
REMOTE_DESC=${REMOTE_DESC:-"Remote that populates the asset repository with assets for CP4I demos"}

asset_repo_release=$RELEASE_NAME
asset_repo_namespace=$NAMESPACE
### End inputs

remote="{ \"metadata\": { \"asset_type\": \"remote_repo\", \"name\": \"$REMOTE_NAME\", \"description\": \"$REMOTE_DESC\" }, \"entity\": { \"remote_repo\": { \"asset_types\": \"\", \"remote_type\": \"git_connection\", \"branch\": \"main\", \"schedule\": \"EVERY_FIVE_MINS\", \"uri\": \"$GIT_REPO\" } } }"
tick="\xE2\x9C\x94"
cross="\xE2\x9D\x8C"

echo "=== Initialising Asset repository with a remote ==="
rm -rf ar_create_tmp
mkdir -p ar_create_tmp

for i in $(seq 1 60); do
  cp4iuser=$(oc get secrets -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 --decode)
  cp4ipwd=$(oc get secrets -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 --decode)
  icpConsoleUrl="https://$(oc get routes -n ibm-common-services cp-console -o jsonpath='{.spec.host}')"

  echo "- Generating access token for user at $icpConsoleUrl"
  # get an icp token
  token_response=$(curl --insecure -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "grant_type=password&scope=openid&username=$cp4iuser&password=$cp4ipwd" $icpConsoleUrl/idprovider/v1/auth/identitytoken)
  token=""

  if [[ ! -z "$token_response" ]]; then
    if jq -e '.access_token' >/dev/null 2>&1 <<<"$token_response"; then
      token=$(jq -r '.access_token' <<<"$token_response")
      break
    else
      echo "Error: Failed to parse JSON, $token_response. (Attempt $i of 60)."
    fi
  else
    echo "Error: No token found (Attempt $i of 60)"
  fi
  echo "Checking again in 10 seconds..."
  sleep 10
done

echo "=== Checking the route has been created ==="
i=1
retries=30
interval=10
if [[ "$USING_OPERATORS" == "true" ]]; then
  desiredResponseContent="$RELEASE_NAME-ibm-ar-$NAMESPACE"
else
  desiredResponseContent="$RELEASE_NAME-$NAMESPACE"
fi

ar_path=""
until [[ "$ar_path" == *"$desiredResponseContent"* ]]; do
  echo "Waiting for asset repo route to be created, attempt number: $i..."
  if [[ "$USING_OPERATORS" == "true" ]]; then
    ar_path=$(oc get ar -n $NAMESPACE $RELEASE_NAME -o json | jq -r '.status.endpoints[] | select ( .name == "ui").uri' | sed 's#^https://##;')
    ${CURRENT_DIR}/fix-cs-dependencies.sh
  else
    ar_path=$(oc get route -n $NAMESPACE -l release=$RELEASE_NAME -o json | jq '.items | .[0].spec.host' -r)
  fi
  ((i = i + 1))
  if [[ "$retries" -eq "$i" ]]; then
    echo "Error: Asset repository route could not be found"
    exit 1
  fi
  sleep $interval
done

printf "$tick "
echo "Asset repository as available at $ar_path"

echo "=== Checking that Asset repository is live ==="
i=1
retries=60
interval=10
response=500
function get_catalogs() {
  response=$(curl --silent --insecure \
    https://$1/api/catalogs -H "Authorization: Bearer $2" -o /dev/null -w %{http_code})
}

get_catalogs $ar_path $token
## retries request until we get a 200, or hit max retries
until [[ $response =~ 200 || "$retries" -eq "$i" ]]; do
  echo "Waiting for asset repo to come alive, attempt number: $i..."
  get_catalogs $ar_path $token
  ((i = i + 1))
  echo "Response code: $response"
  sleep $interval
done
## If we never got a successful response, exit
if [[ ! $response =~ 200 || $i -eq $retries ]]; then
  printf "$cross "
  echo "Error: Asset repository could not be contacted at $ar_path"
  exit 1
fi
printf "$tick "
echo "Asset repository contacted at $ar_path"

echo "=== Setting up git remote for Asset repository ==="

echo "- Checking that the Asset repository can communicate with git remote"
i=1
retries=10
interval=10
response=500
echo "" >./ar_create_tmp/remote.status.log

function test_remote() {
  response=$(curl -X POST --silent --insecure \
    https://$1/api/remotes/test -d "$3" -H "Content-Type: application/json" -H "Authorization: Bearer $2" -o ./ar_create_tmp/remote-status.log -w %{http_code})
}

## retries request until we get a 200, or hit max retries
test_remote $ar_path $token "$remote"
until [[ $response =~ 200 || "$retries" -eq "$i" ]]; do
  echo "Waiting for git remote repository to connect: $i..."
  test_remote $ar_path $token $remote
  ((i = i + 1))
  printf "Remote test response: "
  cat ./ar_create_tmp/remote-status.log
  echo ""
  echo "Response code: $response"
  sleep $interval
done
## If we never got a successful response, exit
if [[ ! $response =~ 200 || $i -eq $retries ]]; then
  printf $cross
  echo "Error: Git remote repository could not be contacted."
  exit 1
fi
printf "$tick "
echo "Git Remote repository contacted."

## Create a catalog
echo "- Creating catalog within asset repository"
create_response=$(curl --insecure -s https://$ar_path/api/catalogs -w %{http_code} -X POST -d "$modified_remote" -o ./ar_create_tmp/catalog_create.json -H "Content-Type: application/json" -H "Authorization: Bearer $token")
if [[ ! $create_response =~ 200 ]]; then
  printf "$cross "
  echo "Response code: $create_response"
  cat ./ar_create_tmp/catalog_create.json
  exit 1
fi
catalogId=$(jq '.id' ./ar_create_tmp/catalog_create.json -r)
# sleeping here because of eventual consistency bug with catalog creation
sleep 5
printf "$tick "
echo "Catalog created with id: $catalogId"

## Fetch remote config for a catalog
echo "- Fetching remote config for catalog"
config_response=$(curl --insecure -s https://$ar_path/api/remotes/config/$catalogId?remote_type=git_connection -w %{http_code} -o ./ar_create_tmp/remote_config.json -H "Content-Type: application/json" -H "Authorization: Bearer $token")
if [[ ! $config_response =~ 200 ]]; then
  printf "$cross "
  echo "Response code: $config_response"
  cat ./ar_create_tmp/remote_config.json
  exit 1
fi
## Modify remote.json to include asset types from configs
printf "$tick "
echo "Fetched remote config for catalog id $catalogId"
asset_types=$(jq '.assetTypes | map(.name) | join(",")' ./ar_create_tmp/remote_config.json -r)
echo "- Configuring remote for the following asset types $asset_types"
modified_remote=$(jq --arg asset_types $asset_types '.entity.remote_repo.asset_types= $asset_types' <<<"$remote")
printf "$tick "
echo "Git remote config asset types populated."

## Create remote
echo "=== Creating git remote for Asset repository ===="
create_response=$(curl --insecure -s https://$ar_path/api/remotes/?catalog_id=$catalogId -w %{http_code} -X POST -d "$modified_remote" -o ./ar_create_tmp/remote_create.json -H "Content-Type: application/json" -H "Authorization: Bearer $token")
if [[ ! $create_response =~ 201 ]]; then
  printf "$cross "
  echo "Response code: $create_response"
  cat ./ar_create_tmp/remote_create.json
  exit 1
fi
printf "$tick "
echo "Git remote created."
echo "=== Asset repository initialised with a git remote ==="
rm -rf ./ar_create_tmp
