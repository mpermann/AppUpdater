#!/bin/bash

# Name: AppUpdater.bash
# Version: 1.0.7
# Created: 03-24-2022 by Michael Permann
# Updated: 07-12-2024
# The script is for patching an app with user notification before starting, if the app is running. If the app
# is not running, it will be silently patched without any notification to the user. Parameter 4 is the name 
# of the app to patch. Parameter 5 is the name of the app process. Parameter 6 is the policy trigger name 
# for the policy installing the app. The script is relatively basic and can't currently kill more than one
# process or patch more than one app.

APP_NAME=$4
APP_PROCESS_NAME=$5
POLICY_TRIGGER_NAME=$6
CURRENT_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
USER_ID=$(/usr/bin/id -u "$CURRENT_USER")
LOGO="/Library/Management/PCC/Images/PCC1Logo@512px.png"
JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
JAMF_BINARY=$(which jamf)
TITLE="Quit Application"
DESCRIPTION="Greetings PERMANNent Computer Consulting LLC Staff

An update for $APP_NAME is available.  Please return to $APP_NAME and save your work and quit the application BEFORE returning here and clicking the \"OK\" button to proceed with the update. 

Caution: your work could be lost if you don't save it and quit $APP_NAME before clicking the \"OK\" button.

You may click the \"Cancel\" button to delay this update.

Any questions or issues please contact techsupport@permannentcc.com.
Thanks!"
TITLE2="Update Complete"
DESCRIPTION2="Thank You! 

$APP_NAME has been updated on your computer. You may relaunch it now if you wish."
BUTTON1="OK"
BUTTON2="Cancel"
DEFAULT_BUTTON="2"
APP_PROCESS_ID=$(/bin/ps ax | /usr/bin/pgrep -x "$APP_PROCESS_NAME" | /usr/bin/grep -v grep | /usr/bin/awk '{ print $1 }')

echo "App to Update: $APP_NAME  Process Name: $APP_PROCESS_NAME"
echo "Policy Trigger: $POLICY_TRIGGER_NAME  Process ID: $APP_PROCESS_ID"

if [ -z "$APP_PROCESS_ID" ] # Check whether app is running by testing if string length of process id is zero.
then 
    echo "App NOT running, so silently install app."
    "$JAMF_BINARY" policy -event "$POLICY_TRIGGER_NAME"
    "$JAMF_BINARY" recon
    exit 0
else
    DIALOG=$(/bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE" -description "$DESCRIPTION" -icon "$LOGO" -button1 "$BUTTON1" -button2 "$BUTTON2" -defaultButton "$DEFAULT_BUTTON")
    if [ "$DIALOG" = "2" ] # Check if the default cancel button was clicked.
    then
        echo "User chose $BUTTON2, so deferring install."
        exit 1
    else
        echo "User chose $BUTTON1, so proceeding with install."
        APP_PROCESS_ID=$(/bin/ps ax | /usr/bin/pgrep -x "$APP_PROCESS_NAME" | /usr/bin/grep -v grep | /usr/bin/awk '{ print $1 }')
        echo "$APP_NAME process ID: $APP_PROCESS_ID"
        if [ -z "$APP_PROCESS_ID" ] # Check whether app is running by testing if string length of process id is zero.
        then
            echo "User chose $BUTTON1 and app NOT running, so proceed with install."
            "$JAMF_BINARY" policy -event "$POLICY_TRIGGER_NAME"
            "$JAMF_BINARY" recon
            # Add message it's safe to re-open app.
            /bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE2" -description "$DESCRIPTION2" -icon "$LOGO" -button1 "$BUTTON1" -defaultButton "1"
            exit 0
        else
            echo "User chose $BUTTON1 and app is running, so killing app process ID: $APP_PROCESS_ID"
            kill -9 "$APP_PROCESS_ID"
            echo "Proceeding with app install."
            "$JAMF_BINARY" policy -event "$POLICY_TRIGGER_NAME"
            "$JAMF_BINARY" recon
            # Add message it's safe to re-open app.
            /bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE2" -description "$DESCRIPTION2" -icon "$LOGO" -button1 "$BUTTON1" -defaultButton "1"
            exit 0
        fi
    fi
fi
