#!/bin/bash

# This is a script which helps you translate your "normal" user/password
# into a MQTT login so you can fetch status from Ecoflow servers.
#
# This script is based on information in GitHub issue
# https://github.com/v1ckxy/ecoflow-withoutflow/issues/1



# Abort if we hit any errors
set -e

# Set this up because some systems like hassos don't have uuidgen
function uuidgen {
  cat /proc/sys/kernel/random/uuid
}

# Generate Ecoflow-compatible random client ID
# NOTE: Must be called *AFTER* fetching login data
function mqtt_client_id_gen {
  echo "ANDROID_`uuidgen | tr '[:lower:]' '[:upper:]'`_${user_id}"
}


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
echo ""

# Pull the token value out of the response
token_value=`echo "$token_result" | jq -r '.data.token'`
user_id=`echo "$token_result" | jq -r '.data.user.userId'`
#echo "Extracted token:"
#echo "-------------------------------------------------------------------------"
#echo "$token_value"
#echo "-------------------------------------------------------------------------"
#echo "*************************************************************************"
#echo "*  WARNING: Protect this login information as it will allow access to   *"
#echo "*           your account and devices!                                   *"
#echo "*************************************************************************"
#echo ""

if [ "$token_value" == "null" ]; then
  echo "Error fetching token!"
	echo ""
	message=`echo "$token_result" | jq -r '.message'`
	echo "It might be related to the message \"$message\"."
	case "$message" in
		"密码错误")
			echo "I think this means \"Wrong Password\""
			;;
		"请输入有效的电子邮件地址")
			echo "I think this means \"Please enter a valid email address\""
			;;
  esac

  echo ""
  echo "Script exiting due to error."
	exit 1
fi

echo "Sending token certification request to"
echo "https://api.ecoflow.com/iot-auth/app/certification . . ."
cert_result=`curl -s -H "Accept: application/json" -H "Authorization: Bearer $token_value"  https://api.ecoflow.com/iot-auth/app/certification`
echo "Result: code $?"
echo "-------------------------------------------------------------------------"
echo "$cert_result" | jq .
echo "-------------------------------------------------------------------------"
echo ""

# Pull out the useful info
mqtt_protocol=`echo "$cert_result" | jq -r '.data.protocol'`
mqtt_server=`echo "$cert_result" | jq -r '.data.url'`
mqtt_port=`echo "$cert_result" | jq -r '.data.port'`
mqtt_username=`echo "$cert_result" | jq -r '.data.certificateAccount'`
mqtt_password=`echo "$cert_result" | jq -r '.data.certificatePassword'`


echo "Your MQTT client connection information is:"
echo "#########################################################################"
echo "#"
echo "#  Protocol: ${mqtt_protocol}://"
echo "#  Host:     ${mqtt_server}"
echo "#  Port:     ${mqtt_port}"
echo "#  Username: ${mqtt_username}"
echo "#  Password: ${mqtt_password}"
echo "#"
echo "#  A few valid unique client IDs for your account different MQTT clients:"
echo "#  `mqtt_client_id_gen`"
echo "#  `mqtt_client_id_gen`"
echo "#  `mqtt_client_id_gen`"
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
read -p 'Enter ONE EcoFlow Battery Serial Number: ' serial_num
read -p 'Enter a short-name (e.g. DM2K) unit:     ' short_name
mqtt_topic="/app/device/property/${serial_num}"
mqtt_writable_topics_prefix="/app/${user_id}/${serial_num}/thing/property"
friendly_prefix="bridge-ecoflow/${short_name}"

echo ""
echo ""
echo ""

echo "Your MQTT Topics are:"
echo "#########################################################################"
echo "#"
echo "#  Status Data: $mqtt_topic"
echo "#  Set:         ${mqtt_writable_topics_prefix}/set"
echo "#  Get:         ${mqtt_writable_topics_prefix}/get"
echo "#  Set Reply:   ${mqtt_writable_topics_prefix}/set_reply"
echo "#  Get Reply:   ${mqtt_writable_topics_prefix}/get_reply"
echo "#"
echo "#########################################################################"

echo ""
echo ""
echo ""

echo "Mosquitto Broker Bridge Config: (based on HassOS Addon config)"
echo "#########################################################################"
echo "#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
echo ""
echo "# File: /share/mosquitto/bridge_ecoflow.conf"
echo "#************************************************************************"
echo "#  WARNING: Protect this login information as it will allow access to   *"
echo "#           your account and devices!                                   *"
echo "#************************************************************************"
echo "connection bridge-ecoflow"
echo "address ${mqtt_server}:${mqtt_port}"
echo "remote_username ${mqtt_username}"
echo "remote_password ${mqtt_password}"
echo ""
echo "# Friendly named topics for device $short_name"
echo "topic \"\" in   0 ${friendly_prefix}/data $mqtt_topic"
echo "topic \"\" both 0 ${friendly_prefix}/set  ${mqtt_writable_topics_prefix}/set"
echo "topic \"\" both 0 ${friendly_prefix}/get  ${mqtt_writable_topics_prefix}/get"
echo "topic \"\" in   0 ${friendly_prefix}/set_reply ${mqtt_writable_topics_prefix}/set_reply"
echo "topic \"\" in   0 ${friendly_prefix}/get_reply ${mqtt_writable_topics_prefix}/get_reply"
echo ""
echo "remote_clientid `mqtt_client_id_gen`"
echo "cleansession true"
echo "try_private true"
echo "bridge_insecure false"
echo "bridge_protocol_version mqttv311"
echo "bridge_tls_version tlsv1.2"
echo "bridge_capath /etc/ssl/certs/"
echo ""
echo "#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo "#########################################################################"

echo ""

echo "To use the Home Assistant YAML MQTT sensors file I built, you will need"
echo "to *GLOBAL* find and replace the user-ID and serial-number placeholders:"
echo "#########################################################################"
echo "# Numerical User-ID:     ${user_id}"
echo "# Battery Serial-Number: ${serial_num}"
echo "#########################################################################"

echo ""
echo ""
echo ""

echo "To subscribe to status messages from a terminal, you could use this command:"
echo "mosquitto_sub -h \"${mqtt_server}\" -p ${mqtt_port} -u \"${mqtt_username}\" -P \"${mqtt_password}\" -i \"`mqtt_client_id_gen`\" -t \"${mqtt_topic}\" | jq ."
echo ""
echo "For monitoring app commands from a terminal, you could use this command:"
echo "mosquitto_sub -h \"${mqtt_server}\" -p ${mqtt_port} -u \"${mqtt_username}\" -P \"${mqtt_password}\" -i \"`mqtt_client_id_gen`\" -t \"${mqtt_writable_topics_prefix}/set\" | jq ."
echo ""
echo "For sending control commands from a terminal, you could use this command:"
echo "message=\"{ the command to send as json }\""
echo "mosquitto_pub -h \"${mqtt_server}\" -p ${mqtt_port} -u \"${mqtt_username}\" -P \"${mqtt_password}\" -i \"`mqtt_client_id_gen`\" -t \"${mqtt_writable_topics_prefix}/set\" -m \"\$message\" | jq ."
echo "*************************************************************************"
echo "*  WARNING: Protect this login information as it will allow access to   *"
echo "*           your account and devices!                                   *"
echo "*************************************************************************"

echo ""
echo "Done."
