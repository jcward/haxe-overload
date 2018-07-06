echo "Be sure to check version number in haxelib.json:"
cat haxelib.json | grep -i version
echo "lib.haxe.org currently has:"
curl -Ls http://lib.haxe.org/p/seoverload | grep '<title>'
sleep 1
read -r -p "Are you sure? [y/N] " response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
then
  rm -f hxseo.zip
  zip -r hxseo.zip SEOMacro.hx haxelib.json extraParams.hxml README.md LICENSE
  haxelib submit hxseo.zip
else
  echo "Cancelled"
fi
