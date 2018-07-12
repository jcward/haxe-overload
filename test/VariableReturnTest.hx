using pkg.VariableReturn;

class Test
{
  public static function main()
  {
    trace("Haxe is great!");

    // Testing variable return types. Not currently possible...
    // but we *could* try to type the containing expression ;)

    var i:Int = s.multi_return();
    trace('Got int: $i');

    var s:String = s.multi_return();
    trace('Got str: $s');

  }
}
