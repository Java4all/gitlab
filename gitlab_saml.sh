#!/bin/bash
################################################################################################
#                                                                                               #
# Created 9/27/19  by Sergii Lysan mailto:elesvi@gmail.com                                      #
# GitlLab SAML SSO configuration Automation Script                                              #
#                                                                                               #
# Usage:                                                                                        #
#   ./gitlab_saml.sh  $1 $2 $3 $4 $5 $6                                                         #
#                                                                                               #
#   note: please, use '' for argument variables                                                 #
#                                                                                               #
#  arguments                                                                                    #
#    $1 - gitlab admin user login; default value is 'user'                                      #
#    $2 - gitlab admin password; default value is 'password'                                    #
#    $3 - gitlab_group_saml_endpoint; default value is '/groups/groupname/-/saml'               #
#    $4 - saml provider enabled for GitLab group; default value is 'true'                       #
#    $5 - saml provider enforced sso for GitLab group members; default value is 'false'         #
#    $6 - saml provider sso url; default value is 'https://sso.example.com/sso/idp/SSO.saml}    #
#    $7 - saml provider cert fingerprint; default value is '874ac729278eb0359c87421ffca8b36b}   #
#                                                                                               #
#  Requirments:                                                                                 #
#   - Linux/Mac OS                                                                              #
#   - perl                                                                                      #
#   - bash                                                                                      #
################################################################################################

### Script setting section ###############################
#
# Trap to cleanup cookie file in case of unexpected exits.
trap 'rm -f $COOKIE_FILE; exit 1' 1 2 3 6
#
# Log directory and file
LOGDIR=.
LOGFILE=$LOGDIR/gitlabsamllog-$(date +%m-%d-%y-%H:%M).log
#
# Location of cookie file
COOKIE_FILE=$(mktemp -t cookies.XXXXXXXXX) >> "$LOGFILE" 2>&1
if [ $? -ne 0 ] || [ -z "$COOKIE_FILE" ]
then
 echo "Temporary cookie file creation failed. See $LOGFILE for more details." |  tee -a "$LOGFILE"
 exit 1
fi
echo "Created temporary cookie file $COOKIE_FILE" >> "$LOGFILE"
#
### End Script settigs section ###########################

### Script variables section #####################################
#
#GitLab host, admin user and password
gitlab_host="https://gitlab.com"
gitlab_user=${1:-user}
gitlab_password=${2:-password}
gitlab_group_saml_endpoint=${3:-/groups/groupname/-/saml}
#
#SAML settings for GitLab Group on SAML setting page
saml_provider_enabled=${4:-true}
saml_provider_enforced_sso=${5:-false}
saml_provider_sso_url=${6:-https://sso.example.com/sso/idp/SSO.saml}
saml_provider_cert_fingerprint=${7:-874ac729278eb0359c87421ffca8b36bb72087b3}
#
#### Script variables section #####################################

#### Main section #################################################
#
# Open the GitLab login page and get a user session cookie
body_header=$(curl -c $COOKIE_FILE -i "${gitlab_host}/users/sign_in" -s)
#
# Get csrf token for the user active page
csrf_token=$(echo $body_header | perl -ne 'print "$1\n" if /new_user.*?authenticity_token"[[:blank:]]value="(.+?)"/' | sed -n 1p)
#
# Get authorized user cookies token for the user active session
curl -b $COOKIE_FILE -c $COOKIE_FILE -i "${gitlab_host}/users/sign_in" --data "user[login]=${gitlab_user}&user[password]=${gitlab_password}" --data-urlencode "authenticity_token=${csrf_token}"
#
# Get csrf token for the user active authorized session
body_header=$(curl -H 'user-agent: curl' -b $COOKIE_FILE -i "${gitlab_host}${gitlab_group_saml_endpoint}" -s)
csrf_token=$(echo $body_header | perl -ne 'print "$1\n" if /authenticity_token"[[:blank:]]value="(.+?)"/' | sed -n 1p)
#
# POST request to Gitlab and "generate SAML SSO access token form"
body_header=$(curl -L -b $COOKIE_FILE "${gitlab_host}${gitlab_group_saml_endpoint}" --data-urlencode "authenticity_token=${csrf_token}" --data 'utf8=%E2%9C%93&_method=patch' --data "saml_provider[enabled]=${saml_provider_enabled}" --data "saml_provider[enforced_sso]=${saml_provider_enforced_sso}" --data "saml_provider[sso_url]=${saml_provider_sso_url}" --data "saml_provider[certificate_fingerprint]=${saml_provider_cert_fingerprint}")
#
#### End Main section #################################################

#### Summary output section #################################################
#
# Get request for SAML SSO URL page and save the response HTML
body_header=$(curl -L -b $COOKIE_FILE "${gitlab_host}${gitlab_group_saml_endpoint}")
sso_url=$(echo $body_header | perl -ne 'print "$1\n" if /qa-certificate-fingerprint-field".*?value="(.+?)"/' | sed -n 1p)
cert_fingerprint=$(echo $body_header | perl -ne 'print "$1\n" if /qa-identity-provider-sso-field".*?value="(.+?)"/' | sed -n 1p)
#
echo "#################################################"
echo " SSO URL Address: $sso_url"
echo " Certificate fingerprint: $cert_fingerprint"
echo "#################################################"
#
##### End Summary output section #################################################

##### Clean-up and exit section #################################################
#
rm -f $COOKIE_FILE 
exit 0
#
###### End Clean-up and exit section ################################################