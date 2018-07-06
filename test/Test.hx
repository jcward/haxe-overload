using pkg.MyStringTools;

class Test
{
  public static function main()
  {
    trace("Haxe is great!");
    var s = "my string";

    // uses the first signature
    s = s.replace('my', 'our');
    trace(s); // our string

    // uses the second signature
    s = s.replace(~/str/, 'th');
    trace(s); // our thing

    // uses the third signature
    s = s.replace(~/[aeiou]/g, function(match) { return match.toUpperCase(); });
    trace(s); // OUr thIng
  }
}
