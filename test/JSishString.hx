@:forward
abstract JSishString(String) from String to String
{
  // FYI: non-static macro secretly passes 'this' as first arg.
  public macro function replace(thys:haxe.macro.Expr, params:Array<haxe.macro.Expr>):haxe.macro.Expr
  {
    var as_str:haxe.macro.Expr = macro ($e{ thys }:String);
    return macro OverloadMacro.check_se($e{ as_str }, 'replace', 'pkg.MyStringTools', $v{ 3 }, $a{ params });
  }
}
