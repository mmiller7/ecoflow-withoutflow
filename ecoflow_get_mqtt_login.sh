#!/bin/bash

# This is a script which helps you translate your "normal" user/password
# into a MQTT login so you can fetch status from Ecoflow servers.
#
# This script is based on information in GitHub issue
# https://github.com/v1ckxy/ecoflow-withoutflow/issues/1



# Abort if we hit any errors
set -e

echo "Please provide your normal EcoFlow login information"
read -p 'User Email: ' uservar
read -p 'Password:   ' passvar

echo ""
echo "Ok, now we will request a token."

# Compute the base64 password
passvar_encoded=`echo -n $passvar | base64`
echo "Base64-encoded password calculated: $passvar_encoded"

echo "Preparing JSON request . . ."
os="linux"
osVersion=`uname -r`
json_request="{
  \"os\": \"${os}\",
  \"scene\": \"IOT_APP\",
  \"appVersion\": \"1.0.0\",
  \"osVersion\": \"${osVersion}\",
  \"password\": \"${passvar_encoded}\",
  \"oauth\": {
    \"bundleId\": \"com.ef.EcoFlow\"
  },
  \"email\": \"${uservar}\",
  \"userType\": \"ECOFLOW\"
}"

echo "-------------------------------------------------------------------------"
echo "$json_request" | jq . 
echo "-------------------------------------------------------------------------"
echo ""
echo "Sending JSON request to https://api.ecoflow.com/auth/login . . ."
token_result=`curl -s -H "Accept: application/json" -H "Content-Type: application/json"  -X POST -d "${json_request}"  https://api.ecoflow.com/auth/login`
echo "Result: code $?"
echo "-------------------------------------------------------------------------"
echo "$token_result" | jq .
echo "-------------------------------------------------------------------------"

# Pull the token value out of the response
token_value=`echo "$token_result" | jq -r '.data.token'`
echo ""
echo "Extracted token:"
echo "-------------------------------------------------------------------------"
echo "$token_value"
echo "-------------------------------------------------------------------------"
echo "*************************************************************************"
echo "*  WARNING: Protect this login information as it will allow access to   *"
echo "*           your account and devices!                                   *"
echo "*************************************************************************"
echo ""

echo "Sending token certification request to"
echo "https://api.ecoflow.com/iot-auth/app/certification . . ."
cert_result=`curl -s -H "Accept: application/json" -H "Authorization: Bearer $token_value"  https://api.ecoflow.com/iot-auth/app/certification`
echo "Result: code $?"
echo "-------------------------------------------------------------------------"
echo "$cert_result" | jq .
echo "-------------------------------------------------------------------------"

# Pull out the useful info
mqtt_protocol=`echo "$cert_result" | jq -r '.data.protocol'`
mqtt_server=`echo "$cert_result" | jq -r '.data.url'`
mqtt_port=`echo "$cert_result" | jq -r '.data.port'`
mqtt_username=`echo "$cert_result" | jq -r '.data.certificateAccount'`
mqtt_password=`echo "$cert_result" | jq -r '.data.certificatePassword'`

echo ""
echo "Your MQTT client connection information is:"
echo "#########################################################################"
echo "#"
echo "#  Protocol: ${mqtt_protocol}://"
echo "#  Host:     ${mqtt_server}"
echo "#  Port:     ${mqtt_port}"
echo "#  Username: ${mqtt_username}"
echo "#  Password: ${mqtt_password}"
echo "#"
echo "#########################################################################"
echo "*************************************************************************"
echo "*  WARNING: Protect this login information as it will allow access to   *"
echo "*           your account and devices!                                   *"
echo "*************************************************************************"
echo ""

echo ""
echo ""
echo "Now we will figure out your MQTT topic."
echo ""
read -p 'Enter EcoFlow Battery Serial Number: ' serial_num
mqtt_topic="/app/device/property/${serial_num}"
echo ""
echo ""
echo ""
echo "Your MQTT Topic is:"
echo "#########################################################################"
echo "$mqtt_topic"
echo "#########################################################################"
echo ""

echo "To subscribe to all messages from a terminal, you could use this command:"
echo "mosquitto_sub -h \"${mqtt_server}\" -p ${mqtt_port} -u \"${mqtt_username}\" -P \"${mqtt_password}\" -t \"${mqtt_topic}\""
echo "*************************************************************************"
echo "*  WARNING: Protect this login information as it will allow access to   *"
echo "*           your account and devices!                                   *"
echo "*************************************************************************"
echo ""
echo "For pritty output, to subscribe to all messages from a terminal, you could use this command:"
echo "mosquitto_sub -h \"${mqtt_server}\" -p ${mqtt_port} -u \"${mqtt_username}\" -P \"${mqtt_password}\" -t \"${mqtt_topic}\" | jq ."
echo "*************************************************************************"
echo "*  WARNING: Protect this login information as it will allow access to   *"
echo "*           your account and devices!                                   *"
echo "*************************************************************************"

echo ""
