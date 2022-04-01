#!/bin/bash

# The script is for patching an app with user notification before starting. Parameter 4 is the name of the
# app to be patched, parameter 5 is the name of the app process, parameter 6 is the policy trigger name to
# install the app. The script is relatively basic and can't currently kill more than one process or patch
# more than one app.
# Version 1.0 created 03-24-2022 by Michael Permann

APP_NAME=$4
APP_PROCESS_NAME=$5
POLICY_TRIGGER_NAME=$6
CURRENT_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
USER_ID=$(/usr/bin/id -u "$CURRENT_USER")
AEA11_LOGO="/Library/Application Support/HeartlandAEA11/Images/HeartlandLogo@512px.png"
JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
JAMF_BINARY=$(which jamf)
TITLE="Quit Application"
DESCRIPTION="Greetings Heartland Area Education Agency Staff

An update for $APP_NAME is available.  Please return to $APP_NAME and save your work and quit the application BEFORE returning here and clicking the \"OK\" button to proceed with the update. Caution: your work could be lost if you don't save it and quit $APP_NAME before clicking the \"OK\" button.

You may click the \"Cancel\" button to delay this update.

Thanks! - IT Department"
TITLE2="Update Complete"
DESCRIPTION2="Thank You! 

$APP_NAME has been updated on your computer. You may relaunch it now if you wish."
BUTTON1="OK"
BUTTON2="Cancel"
DEFAULT_BUTTON="2"

echo "$APP_NAME"
echo "$APP_PROCESS_NAME"
echo "$POLICY_TRIGGER_NAME"

APP_PROCESS_ID=$(/bin/ps ax | /usr/bin/pgrep -x "$APP_PROCESS_NAME" | /usr/bin/grep -v grep | /usr/bin/awk '{ print $1 }')
echo "$APP_NAME process ID $APP_PROCESS_ID"

if [ -z "$APP_PROCESS_ID" ] # Check whether app is running by testing if process id is zero
then 
    echo "App NOT running so silently install app"
    "$JAMF_BINARY" policy -event "$POLICY_TRIGGER_NAME"
    exit 0
else
    DIALOG=$(/bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE" -description "$DESCRIPTION" -icon "$AEA11_LOGO" -button1 "$BUTTON1" -button2 "$BUTTON2" -defaultButton "$DEFAULT_BUTTON")
    if [ "$DIALOG" = "2" ] # Check if the default cancel button was clicked
    then
        echo "User chose $BUTTON2 so deferring install"
        exit 1
    else
        echo "User chose $BUTTON1 so proceeding with install"
        APP_PROCESS_ID=$(/bin/ps ax | /usr/bin/pgrep -x "$APP_PROCESS_NAME" | /usr/bin/grep -v grep | /usr/bin/awk '{ print $1 }')
        echo "$APP_NAME process ID $APP_PROCESS_ID"
        if [ -z "$APP_PROCESS_ID" ] # Check whether app is running by testing if process id is zero
        then
            echo "User chose $BUTTON1 and app NOT running so proceed with install"
            "$JAMF_BINARY" policy -event "$POLICY_TRIGGER_NAME"
            /bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE2" -description "$DESCRIPTION2" -icon "$AEA11_LOGO" -button1 "$BUTTON1" -defaultButton "1"
            exit 0
        else
            echo "User chose $BUTTON1 and app is running so killing app process ID $APP_PROCESS_ID"
            kill -9 "$APP_PROCESS_ID"
            echo "Proceeding with app install"
            "$JAMF_BINARY" policy -event "$POLICY_TRIGGER_NAME"
            # Add message it's safe to re-open app
            /bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE2" -description "$DESCRIPTION2" -icon "$AEA11_LOGO" -button1 "$BUTTON1" -defaultButton "1"
            exit 0
        fi
    fi
fi
