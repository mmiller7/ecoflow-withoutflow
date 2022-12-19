This folder has some stuff I used to get Home Assistant working with the Ecoflow cloud MQTT server.

If you don't have a Linux system to run the MQTT login script, you can put it on your Home Assistant
server and use the SSH addon to run the script and interact with it.

Start with the SSH script and take note of it's output with credentials and config lines it will
help you to generate based on your battery.  At this time, it assumes you only have one battery.
If you have multiple, you will need to run it repeatedly or manually create the additional serial
number topics for MQTT subscription.

The topics and sensors may vary by battery, I have a Delta Max 2000.  The YAML assumes you also
have a single battery.  If you have multiple, I would suggest you duplicate the YAML package
once per battery and then modify the names of each sensor (AND where it uses it within the file!)
so that they are unique to the battery.  Yes, there's a lot of them.

You will also need to create the MQTT Broker addon config file and set it up with the extra
options under the addon configuration "Customize" as follows:
active: true
folder: mosquitto

Remember to restart Mosquitto Broker and check the log that it connects (and stays connected)
to the Ecoflow server.

In theory, then you can just drop the package file in and reload Home Assistant it should work.
To learn more about package files and how to use them, visit their documentation:
https://www.home-assistant.io/docs/configuration/packages/
It's basically just a configuration.yaml that has a different name and is included into the
main one, but makes it easier to share and organize them by device.
