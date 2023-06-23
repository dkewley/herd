#!/bin/bash

region="us-west-2"
sso_region=$region
output="json"

echo "this script will attempt to create aws cli profiles from your sso profiles"
echo "you'll need acces to a working sso login credential"
echo "hint you can do this with 'aws sso login --profile youreasytorememberprofile'"
echo "here are the cache files aws uses for sso authentication"
ls -ltar ~/.aws/sso/cache/* | grep -v botocore
echo

echo "please enter the fully qualified most recent aws sso cache file"
read filename
echo

token=$(cat "$filename" | jq -r .accessToken)
start_url=$(cat "$filename" | jq -r .startUrl)
expires_at=$(cat "$filename" | jq -r .expiresAt)

portal=$(echo $start_url | sed -r 's@https://([^.]+).*@\1@')

echo "Creating profiles for $portal"
echo

typeset -i now_seconds expires_seconds
now_seconds=$(date +%s)
expires_seconds=$(date -j -f %FT%T%z +%s $(echo $expires_at | sed 's/Z$/+0000/'))

if [ $now_seconds -gt $expires_seconds ] ; then
  echo "This token has already expired. Please re-authenticate as needed, then re-run this script."
  exit 1
fi

# echo "enter your sso portal hostname, i.e. the value of <yourportal> in https://<yourportal>.awsapps.com/start#/"
# read portal
# echo

echo "The following output can be added to ~/.aws/config"
echo
# the following issues block us from using the sso-session renewable-token approach (until they're fixed):
# https://github.com/hashicorp/terraform-provider-aws/issues/28263
# https://github.com/hashicorp/terraform/issues/32465
# echo "[sso-session $portal]"
# echo "sso_start_url = $start_url"
# echo "sso_region = $sso_region"
# echo

aws sso list-accounts \
	--region $sso_region \
	--access-token $token \
| jq -c '.accountList | sort_by(.accountName)[]' \
| while read line ; do
	account_name=$(echo $line | jq '.accountName' | sed 's/^"// ; s/"$// ; s/ /-/g');
	account_id=$(echo $line | jq '.accountId' | sed 's/^"// ; s/"$//');
	aws sso list-account-roles \
		--region $sso_region \
		--access-token $token \
		--account-id $account_id \
	| jq -r '[.roleList[].roleName] | sort[]' \
	| while read role; do
		echo "[profile $portal-$account_name-$role]";
		echo output = $output;
		echo region = $region;
		echo sso_account_id = $account_id;
		echo sso_role_name = $role;
		# sso_region and sso_start_url can be removed, and sso_session added,
		# once the two issues in above comments are resolved and the related echo's uncommented
		echo "sso_start_url = $start_url"
		echo "sso_region = $sso_region"
		# echo "sso_session = $portal"
		echo
	done
done
