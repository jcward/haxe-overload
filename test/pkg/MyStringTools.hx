package pkg;

class MyStringTools implements OverloadMacro.IOverloaded
{
  public static function replace(haystack:String, needle:String, by:String):String {
    return StringTools.replace(haystack, needle, by);
  }

  public static function replace(haystack:String, needle:EReg, by:String):String {
    return needle.replace(haystack, by);
  }

  public static function replace(haystack:String, needle:EReg, replacer:String->String):String {
    return needle.map(haystack, function(e) {
      return replacer(e.matched(0));
    });
  }
}
