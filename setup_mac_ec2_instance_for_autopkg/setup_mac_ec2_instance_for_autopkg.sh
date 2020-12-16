#!/bin/bash

# This script is designed to configure an AWS Mac EC2 instance with the following:
#
# Account password for the default ec2-user account
# git
# AutoPkg
# AutoPkgr
# JSSImporter
#
# Once these tools and modules are installed, the script configures AutoPkg 
# to use the recipe repos defined in the AutoPkg repos section.
# -------------------------------------------------------------------------------------- #
## Editable locations and settings
## AutoPkg repos:
#
# Enter the list of AutoPkg repos which need
# to be set up.
#
# All listed recipe repos should go between the two ENDMSG lines. 
# The list should look similar to the one shown below:
#
# read -r -d '' autopkg_repos <<ENDMSG
# recipes
# jss-recipes
# https://github.com/username/recipe-repo-name-here.git
# ENDMSG
#

read -r -d '' autopkg_repos <<ENDMSG

ENDMSG

# If you choose to hardcode API information into the script, uncomment the lines below
# and set one or more of the following values:
#
# The username for an account on the Jamf Pro server with sufficient API privileges
# The password for the account
# The Jamf Pro URL

jamfproURL=""	## Set the Jamf Pro URL here if you want it hardcoded.
apiUser=""		## Set the username here if you want it hardcoded.
apiPass=""		## Set the password here if you want it hardcoded.

# Jamf Pro distribution point account name and password, used by
# file share distribution points.
# 
# In normal usage, this is sufficient to get access to the
# distribution point information stored in the Jamf Pro server.

jamfdp_repo_name="" ## Set the distribution point repository name here if you want it hardcoded.
jamfdp_repo_password="" ## Set the distribution point repository password here if you want it hardcoded.

# If you're using a Jamf Pro cloud distribution point as your master distribution point, 
# the cloud_distribution_point variable should look like this:
#
# cloud_distribution_point="yes"
#
# Otherwise, it should look like this:
#
# cloud_distribution_point=""

cloud_distribution_point=""

# Set password for default AWS account on Mac instances

autopkg_userpassword=""

# If you want to enable VNC, the enableVNC variable should look like this:
#
# enableVNC="yes"
#
# Otherwise, it should look like this:
#
# enableVNC=""
#
# Note: the autopkg_userpassword variable needs to be set.

enableVNC="yes"

# If you want to enable automatic login of the default user account, the enableAutoLogin
# variable should look like this:
#
# enableAutoLogin="yes"
# Otherwise, it should look like this:
#
# enableAutoLogin=""
#
# Note: the autopkg_userpassword variable needs to be set.

enableAutoLogin="yes"

# -------------------------------------------------------------------------------------- #
## No editing required below here

# Set exit code

exitCode=0

# Define default username used by AWS on Mac instances

autopkg_username="ec2-user"

# Set password for default user account if one is defined by the autopkg_userpassword
# variable. Otherwise, no password is set for the account.

if [[ "$autopkg_username" = "ec2-user" ]] && [[ -n "$autopkg_userpassword" ]]; then
    /usr/bin/dscl . passwd /Users/"$autopkg_username" ${autopkg_userpassword}
fi

# User Home Directory

autopkg_userhome=$(/usr/bin/dscl . -read /Users/"$autopkg_username" NFSHomeDirectory | awk '{print $2}')

# AutoPkg preferences file

autopkg_prefs="$autopkg_userhome/Library/Preferences/com.github.autopkg.plist"

# Define log location

log_location="$autopkg_userhome/Library/Logs/autopkg-setup-for-$(date +%Y-%m-%d-%H%M%S).log"

# Define ScriptLogging behavior

ScriptLogging(){

    DATE=$(date +%Y-%m-%d\ %H:%M:%S)
    LOG="$log_location"    
    echo "$DATE" " $1" >> $LOG
}

# Enable VNC

if [[ "$enableVNC" = "yes" ]] && [[ -n "$autopkg_userpassword" ]]; then
    /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -restart -agent -privs -all
fi

installCommandLineTools() {
    echo "### Installing the latest Xcode command line tools..." >> "$log_location" 2>&1
    echo
    # Save current IFS state
    OLDIFS=$IFS
    IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"
    # restore IFS to previous state
    IFS=$OLDIFS
    
    cmd_line_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    
    # Create the placeholder file which is checked by the softwareupdate tool 
    # before allowing the installation of the Xcode command line tools.
    
    touch "$cmd_line_tools_temp_file"
    
    # Identify the correct update in the Software Update feed with "Command Line Tools" in the name for the OS version in question.
    
    if [[ ( ${osvers_major} -eq 10 && ${osvers_minor} -ge 15 ) || ( ${osvers_major} -eq 11 && ${osvers_minor} -ge 0 ) ]]; then
       cmd_line_tools=$(softwareupdate -l | awk '/\*\ Label: Command Line Tools/ { $1=$1;print }' | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 9-)	
    elif [[ ( ${osvers_major} -eq 10 && ${osvers_minor} -gt 9 ) ]] && [[ ( ${osvers_major} -eq 10 && ${osvers_minor} -lt 15 ) ]]; then
       cmd_line_tools=$(softwareupdate -l | awk '/\*\ Command Line Tools/ { $1=$1;print }' | grep "$macos_vers" | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 2-)
    fi
    
    # Check to see if the softwareupdate tool has returned more than one Xcode
    # command line tool installation option. If it has, use the last one listed
    # as that should be the latest Xcode command line tool installer.
    
    if (( $(grep -c . <<<"$cmd_line_tools") > 1 )); then
       cmd_line_tools_output="$cmd_line_tools"
       cmd_line_tools=$(printf "$cmd_line_tools_output" | tail -1)
    fi
    
    #Install the command line tools
    
    softwareupdate -i "$cmd_line_tools" --verbose
    
    # Remove the temp file
    
    if [[ -f "$cmd_line_tools_temp_file" ]]; then
      rm "$cmd_line_tools_temp_file"
    fi
}

installAutoPkg() {

    # Install the latest release of AutoPkg

    autopkg_location_LATEST=$(/usr/bin/curl https://api.github.com/repos/autopkg/autopkg/releases/latest | awk '/browser_download_url/ {print $2}' | tr -d '"')
    /usr/bin/curl -L -s "${autopkg_location_LATEST}" -o "$autopkg_userhome/autopkg-latest.pkg" 2>&1 | tee -a "$log_location"

    ScriptLogging "Installing AutoPkg"
    installer -verboseR -pkg "$autopkg_userhome/autopkg-latest.pkg" -target / >> "$log_location" 2>&1
     if [[ $? -eq 0 ]]; then
  		ScriptLogging "AutoPkg Installed."
  	  else
  		ScriptLogging "ERROR! AutoPkg Install Failed!"
  		exitCode=1
     fi
}

installJSSImporter() { 

    # Install the latest release of JSSImporter

    jssimporter_location_LATEST=$(/usr/bin/curl https://api.github.com/repos/jssimporter/JSSImporter/releases/latest | awk '/browser_download_url/ {print $2}' | tr -d '"')
    /usr/bin/curl -L -s "${jssimporter_location_LATEST}" -o "$autopkg_userhome/jssimporter-latest.pkg" 2>&1 | tee -a "$log_location"

    ScriptLogging "Installing JSSImporter"
    installer -verboseR -pkg "$autopkg_userhome/jssimporter-latest.pkg" -target / >> "$log_location" 2>&1
     if [[ $? -eq 0 ]]; then
  		ScriptLogging "JSSImporter Installed"
  	  else
  		ScriptLogging "ERROR! JSSImporter Install Failed!"
  		exitCode=1
     fi
}

installAutoPkgr() { 

    # Install the latest release of AutoPkgr by adding the
    # homebysix-recipes AutoPkg recipe repo and installing AutoPkgr
    # using the AutoPkgr.install recipe available from that repo.
        
    sudo -u "$autopkg_username" "${autopkg_location}" repo-add homebysix-recipes >> "$log_location" 2>&1
    ScriptLogging "Installing AutoPkgr"
    sudo -u "$autopkg_username" "${autopkg_location}" run AutoPkgr.install >> "$log_location" 2>&1
     if [[ $? -eq 0 ]]; then
  		ScriptLogging "AutoPkgr Installed."
  	  else
  		ScriptLogging "ERROR! AutoPkgr Install Failed!"
  		exitCode=1
     fi
    sudo -u "$autopkg_username" "${autopkg_location}" repo-delete homebysix-recipes >> "$log_location" 2>&1
}

## Main section

# If the log file is not available, create it

if [[ ! -r "$log_location" ]]; then
    sudo -u "$autopkg_username" mkdir -p "$autopkg_userhome/Library/Logs"
    sudo -u "$autopkg_username" touch "$log_location"
fi

# Commands
autopkg_location="/usr/local/bin/autopkg"
autopkgr_location="/Applications/AutoPkgr.app"
brew_location="/usr/local/bin/brew"
defaults_location="/usr/bin/defaults"
jssimporter_location="/Library/AutoPkg/autopkglib/JSSImporter.py"
plistbuddy_location="/usr/libexec/PlistBuddy"

# Ensure the latest version of the Xcode command line tools are installed.

installCommandLineTools

# Ensure that Homebrew is up to date

sudo -u "$autopkg_username" "${brew_location}" update >> "$log_location" 2>&1
sudo -u "$autopkg_username" "${brew_location}" upgrade >> "$log_location" 2>&1

# Get AutoPkg if not already installed
if [[ ! -x ${autopkg_location} ]]; then
    installAutoPkg
    # Clean up if necessary.
    
    if [[ -e "$autopkg_userhome/autopkg-latest.pkg" ]]; then
        rm "$autopkg_userhome/autopkg-latest.pkg"
    fi    
else
    ScriptLogging "AutoPkg installed"
fi

# Check for JSSImporter and install if needed

if [[ ! -x "$jssimporter_location" ]]; then
    installJSSImporter
    # Clean up if necessary
    
    if [[ -e "$autopkg_userhome/jssimporter-latest.pkg" ]]; then
       rm "$autopkg_userhome/jssimporter-latest.pkg"
    fi
else
    ScriptLogging "JSSImporter installed"
fi

# Check for AutoPkgr and install if needed

if [[ ! -x "$autopkgr_location" ]]; then
    installAutoPkgr
    # Clean up if necessary
    
    if [[ -d "$autopkg_userhome/Library/AutoPkg/Cache/com.github.homebysix.install.AutoPkgr" ]]; then
       rm -rf "$autopkg_userhome/Library/AutoPkg/Cache/com.github.homebysix.install.AutoPkgr"
    fi
else
    ScriptLogging "AutoPkgr installed"
fi

if [[ -x ${autopkg_location} ]] && [[ -x ${autopkgr_location} ]] && [[ -x ${jssimporter_location} ]]; then

  ScriptLogging "AutoPkg, AutoPkgr and JSSImporter verified as installed."

  # Add AutoPkg repos (checks if already added)

  sudo -u "$autopkg_username" ${autopkg_location} repo-add ${autopkg_repos} >> "$log_location" 2>&1

  # Update AutoPkg repos (if the repos were already there no update would otherwise happen)

  sudo -u "$autopkg_username" ${autopkg_location} repo-update ${autopkg_repos} >> "$log_location" 2>&1

  ScriptLogging "AutoPkg Repos Configured"

  # Configure JSSImporter with the following information:
  #
  # Jamf Pro address
  # Jamf Pro API account username
  # Jamf Pro API account username

  sudo -u "$autopkg_username" ${defaults_location} write ${autopkg_prefs} JSS_URL "${jamfproURL}" >> "$log_location" 2>&1
  sudo -u "$autopkg_username" ${defaults_location} write ${autopkg_prefs} API_USERNAME "${apiUser}" >> "$log_location" 2>&1
  sudo -u "$autopkg_username" ${defaults_location} write ${autopkg_prefs} API_PASSWORD "${apiPass}" >> "$log_location" 2>&1

  # Remove any existing Jamf Pro distribution point settings

  sudo -u "$autopkg_username" ${plistbuddy_location} -c "Delete :JSS_REPOS array" ${autopkg_prefs} >> "$log_location" 2>&1 
  
  if [[ "$cloud_distribution_point" = "yes" ]]; then
  
      # Add Cloud Distribution Point (CDP) to the JSSImporter settings.
  
      sudo -u "$autopkg_username" ${plistbuddy_location} -c "Add :JSS_REPOS array" ${autopkg_prefs} >> "$log_location" 2>&1
      sudo -u "$autopkg_username" ${plistbuddy_location} -c "Add :JSS_REPOS:0 dict" ${autopkg_prefs} >> "$log_location" 2>&1
      sudo -u "$autopkg_username" ${plistbuddy_location} -c "Add :JSS_REPOS:0:type string CDP" ${autopkg_prefs} >> "$log_location" 2>&1

  else
  
      # Add the distribution point repository name and repository password 
      # to the JSSImporter settings, which is necessary to access the file  
      # share distribution point info stored in your Jamf Pro server.
  
      sudo -u "$autopkg_username" ${plistbuddy_location} -c "Add :JSS_REPOS array" ${autopkg_prefs} >> "$log_location" 2>&1
      sudo -u "$autopkg_username" ${plistbuddy_location} -c "Add :JSS_REPOS:0 dict" ${autopkg_prefs} >> "$log_location" 2>&1
      sudo -u "$autopkg_username" ${plistbuddy_location} -c "Add :JSS_REPOS:0:name string ${jamfdp_repo_name}" ${autopkg_prefs} >> "$log_location" 2>&1
      sudo -u "$autopkg_username" ${plistbuddy_location} -c "Add :JSS_REPOS:0:password string ${jamfdp_repo_password}" ${autopkg_prefs} >> "$log_location" 2>&1
  fi
  
  echo
  echo "### AutoPkg, AutoPkgr and JSSImporter configured and ready for use with the following repos. For setup details, please see $log_location." >> "$log_location" 2>&1
  echo "$(sudo -u "$autopkg_username" "${autopkg_location}" repo-list)" >> "$log_location" 2>&1
else
  echo
  echo "### Error! AutoPkg, AutoPkgr and JSSImporter not installed properly. For setup details, please see $log_location." >> "$log_location" 2>&1
fi

if [[ "$enableAutoLogin" = "yes" ]] && [[ -n "$autopkg_userpassword" ]]; then
   # Enabling automatic login of AWS ec2-user
   ScriptLogging "Enabling autologin of $autopkg_username account."
   sudo -u "$autopkg_username" /usr/local/bin/brew tap xfreebird/utils
   sudo -u "$autopkg_username" /usr/local/bin/brew install kcpassword

   if [[ -x "/usr/local/bin/kcpassword" ]] && [[ -x "/usr/local/Cellar/kcpassword/1.0.0/bin/enable_autologin" ]]; then
       /usr/local/Cellar/kcpassword/1.0.0/bin/enable_autologin ${autopkg_username} ${autopkg_userpassword} > /dev/null 2>&1
       if [[ $(/usr/bin/defaults read /Library/Preferences/com.apple.loginwindow.plist autoLoginUser) = "$autopkg_username" ]] && [[ -f "/etc/kcpassword" ]]; then
          ScriptLogging "Autologin enabled successfully."
       else
          ScriptLogging "Error! Autologin setup failed!"
          exitCode=1
       fi
   fi
fi
exit "$exitCode"