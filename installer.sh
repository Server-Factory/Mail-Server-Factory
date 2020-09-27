#!/bin/sh

installerScript=Core/Utils/factory_installer.sh
if test -e "$installerScript"; then

  if "$installerScript" "mail"; then

    factoryPath="/usr/local/bin"
    sudo cp -f Core/Utils/factory.sh "$factoryPath" &&
      cp -f mail_factory.sh "$factoryPath"
  else

    echo "Installation failed"
    exit 1
  fi
else

  echo "No $installerScript found at: $(pwd)"
  exit 1
fi
