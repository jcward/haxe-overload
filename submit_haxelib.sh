echo "Be sure to check version number in haxelib.json:"
cat haxelib.json | grep -i version
echo "lib.haxe.org currently has:"
curl -Ls http://lib.haxe.org/p/overload | grep '<title>'
sleep 1
read -r -p "Are you sure? [y/N] " response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
then
  rm -f hxoverload.zip
  zip -r hxoverload.zip OverloadMacro.hx haxelib.json extraParams.hxml README.md LICENSE
  haxelib submit hxoverload.zip
else
  echo "Cancelled"
fi
