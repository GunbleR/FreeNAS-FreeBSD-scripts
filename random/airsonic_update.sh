#!/usr/local/bin/bash
repo="airsonic-advanced/airsonic-advanced"
cd /tmp
myloop=0
while [ $myloop -lt 3 ]; do
  mytag=$( curl --silent "https://api.github.com/repos/$repo/releases" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/' |                                    # Pluck JSON value
    head -1 )
  curl -L -o airsonic.war "https://github.com/$repo/releases/download/$mytag/airsonic.war"
  curl -L -o airsonic.sha "https://github.com/$repo/releases/download/$mytag/artifacts-checksums.sha"
#  echo "https://github.com/$repo/releases/download/$mytag/airsonic.war"
echo "im downloading $myloop"
  VAR1=$(grep airsonic.war airsonic.sha  | cut -d " " -f1)
  VAR2=$(sha256 -q  airsonic.war)
  if [ "$VAR1" = "$VAR2" ]; then
   echo "Strings are equal."
    break
  else
    if [ $myloop -lt 2 ]; then
      let 'myloop+=1'
      echo "download #$myloop failed. retrying."
    else
      echo "download failed 3 times. stopping update."
      exit 1
    fi
  fi
done
echo $myloop
chown subsonic:subsonic airsonic.war
service airsonic stop
mv /usr/local/share/airsonic/airsonic.war.old /usr/local/share/airsonic/airsonic.war.old1
mv /usr/local/share/airsonic/airsonic.war /usr/local/share/airsonic/airsonic.war.old
mv airsonic.war /usr/local/share/airsonic/airsonic.war
service airsonic start
# curl --silent "https://github.com/$repo/releases/tag" | jq -r .tag_name
