package pkg;

class VariableReturn implements OverloadMacro.IOverloaded
{
  public static function multi_return(s:String):Int    { return 123; }
  public static function multi_return(s:String):String { return 'abc'; }

}
