#if macro

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;

import haxe.ds.StringMap;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;

using Lambda;

typedef OVInfoType = {
  se_cls : haxe.macro.Type.ClassType,
  cnt_per_field : StringMap<Int>,
  cls_name:String
}

class OverloadMacro
{

  private static inline var OVERLOAD_META_NAME = 'overload_macro';
  private static inline function overload_suffix(i:Int) return '__ovr_${i}';

  // Build macro that runs on the overloaded SE Tools classes
  public static macro function build_overloaded():Array<Field>
  {
    var cls = Context.getLocalClass().get();
    var fields:Array<Field> = Context.getBuildFields();

    var fields_by_name = new StringMap<Array<Field>>();
    for (field in fields) {
      // only applies to static functions
      if (field.access.has(AStatic)) {
        switch field.kind {
          case FFun(f):
            if (!fields_by_name.exists(field.name)) fields_by_name.set(field.name, []);
            fields_by_name.get(field.name).push(field);
          default:
        }
      }
    }

    var overload_metadata = [];
    for (name in fields_by_name.keys()) {
      // Only fields with more than 1 instance
      if (fields_by_name.get(name).length<2) continue;

      // Hmm, can't push a Map<String, Int> through meta...
      // overload_cnt.set(name, fields_by_name.get(name).length);
      overload_metadata.push(macro $v{ name });
      overload_metadata.push(macro $v{ fields_by_name.get(name).length });
      var i = 0;
      for (field in fields_by_name.get(name)) {
        // Need to rename the fields.
        field.name = '${ name }${ overload_suffix(i) }';

        //  TODO? Could possible ensure unique args here...
        i++;
      }
    }

    // Add overload metadata (StringMap<Int> didn't work in getValue... using Dynamic)
    // Could map this way...
    // var meta_expr = Context.parse('[ '+[ for (key in overload_cnt.keys()) '"$key" => ${ overload_cnt.get(key) }' ].join(',')+']', Context.currentPos());
    cls.meta.add(OVERLOAD_META_NAME, overload_metadata, Context.currentPos());

#if display // In display mode, generate a custom class with @:overload metadata
    var cls_name = (cls.pack.length>0 ? cls.pack.join('.') : '') + '.' + cls.name;
    handle_display_mode(cls_name, fields_by_name);
#end

    return fields;
  }


#if display
  // In display mode, we need to populate a method with the proper @:overload
  // so that we can display multiple function signatures:
  private static function handle_display_mode(cls_name:String, fields_by_name:StringMap<Array<Field>>)
  {
    var dcn = display_class_name(cls_name);
    var ot = macro class $dcn { };
    for (name in fields_by_name.keys()) {
      // Only fields with more than 1 instance
      var overloads = fields_by_name.get(name);
      if (overloads.length<2) continue;
      // Take the first field, and put it on the display class
      var first = overloads.shift();
      first = {
        name:name,
        access:first.access,
        kind:first.kind,
        pos:first.pos,
        meta:first.meta
      };
      ot.fields.push(first);
      // Take the remaining fields, and set @:overload metadata with them:
      for (other in overloads) {
        switch other.kind {
          case FFun(f):
            var signature = { expr:EFunction(null, { args:f.args, ret:f.ret, expr:{ expr:EBlock([]), pos:first.pos} }), pos:first.pos };
            var overload_meta = { name:':overload', params:[signature], pos:first.pos };
            first.meta.push(overload_meta);
          default:
        }
      }
    }

    // Define the for-display-only class:
    Context.defineType(ot);
  }
  private static function display_class_name(n:String):String
  {
    return 'Overloaded__${ n.split(".").join("_") }';
  }
#end

  // Build macro added to *all* classes be extraParams.hxml -- careful,
  // be extremely performance minded
  public static macro function build_all():Array<Field>
  {
    var fields:Array<Field> = Context.getBuildFields();

    var cref = Context.getLocalClass();
    if (cref==null) return fields;
    var cls = cref.get();
    if (cls==null) return fields;

    // Examine each class in the 'using' declarations
    for (used in Context.getLocalUsing()) {
      var se_cls = used.get();

      // Check for the overloaded metadata
      var meta = se_cls.meta.extract(OVERLOAD_META_NAME)[0];
      if (!(meta!=null && meta.params!=null && meta.params.length>0)) continue;

      // Convert metadata to StringMap<Int> (why doesn't $v{} support ["foo"=>5] ?)
      var overload_cnt = new StringMap<Int>();
      var i = 0;
      while (i<meta.params.length) {
        overload_cnt.set( meta.params[i].getValue(), meta.params[i+1].getValue() );
        i += 2;
      }
      // trace(overload_cnt); // e.g. { replace=>5, to_array=>3 }

      // trace('In ${ cls.name } using: ${ se_cls.name }');
      var cls_name = (se_cls.pack.length>0 ? se_cls.pack.join('.') : '') + '.' + se_cls.name;
      var se_info = { se_cls:se_cls, cnt_per_field:overload_cnt, cls_name:cls_name };
      
      for(field in fields) {
        switch (field.kind) {
          case FVar(t, e):
            field.kind = FVar(t, modifyExpr(e, se_info));
          case FProp(get, set, t, e):
            field.kind = FProp(get, set, t, modifyExpr(e, se_info));
          case FFun(f):
            f.expr = modifyExpr(f.expr, se_info);
        }
      }
    }

    return fields;
  }


  private static function modifyExpr(expr:Expr, se_info:OVInfoType):Expr
  {
    if (expr == null) return null;

    switch (expr.expr) {
      case ECall({ expr:EField(subject, field_name) }, params):
        if (se_info.cnt_per_field.exists(field_name)) {
          var mapped_params = [ for (e in params) modifyExpr(e, se_info) ];
          var pe:Expr = macro $a{ mapped_params };
          #if display
            // In display mode, we bounce the call to a generated Overload__<cls_name> clss,
            // which has a <field_name> function with the proper @:overload metadata.
            var disp_cls = display_class_name(se_info.cls_name);
            var rtn = macro $i{ disp_cls }.$field_name(($pe : Array<Expr>));
          #else
            var rtn = macro OverloadMacro.check_se($subject, $v{ field_name }, $v{ se_info.cls_name }, $v{ se_info.cnt_per_field.get(field_name) }, ($pe : Array<Expr>));
          #end
          rtn.pos = expr.pos; // Report type errors at the site of the function call
          // trace(rtn.toString());
          return rtn;
        }
      default:
    }

    return ExprTools.map(expr, function(e) { return modifyExpr(e, se_info); });
  }

  private static function unwrap_to_array(expr:ExprDef):Array<Expr> {
    return switch expr {
      case EArrayDecl(ps): ps;
      case EParenthesis(e): return unwrap_to_array(e.expr);
      case ECheckType(e, _): return unwrap_to_array(e.expr);
      case EUntyped(e): return unwrap_to_array(e.expr);
      default: throw 'Error: unexpected expr looking for EArrayDecl: $expr';
    }
  }

  public static function check_se(subject:Expr, field_name:String, cls_name:String, num:Int, params:Expr):Expr
  {
    var ps = unwrap_to_array(params.expr);

    // First, check if subject function call is valid (without overloading)
    try {
      var eval = macro ${ subject }.$field_name($a{ ps });
      //trace('${ eval.toString() }');
      var t = Context.typeof(eval);
      //trace('WITHOUT OVERLOADING, TYPE IS: $t');
      return eval;
    } catch (e:Dynamic) { }

    // No? Ok, let's check overloads...

    // Put the subject expression first in the list (ala static extension)
    ps.unshift( subject );

    // We will simply try typing each function call.
    for (i in 0...num) {

      // Note: we could try to see if subject was the same type as the first
      //       function arg... but the compiler will already do that for us.
      var expanded_field = '${ field_name }${ overload_suffix(i) }';
      var eval = macro $p{ cls_name.split('.') }.$expanded_field($a{ ps });

      try {
        //trace('${ eval.toString() }');
        var t = Context.typeof(eval);
        //trace('WITH OVERLOADING, TYPE IS: $t');
        return eval;
      } catch (e:Dynamic) {
        // Not correctly typed, try the next signature
      }
    }

    Context.error('No suitable overload found for ${ subject.toString() }.$field_name, params: ${ ps.toString() }', Context.currentPos());
    return macro null;
  }

}


#else

import haxe.macro.Expr;

class OverloadMacro
{
  public static macro function check_se(subject:Expr, field_name:String, cls_name:String, num:Int, params:Expr):Expr
  {
    return null;
  }
}

#end

@:autoBuild(OverloadMacro.build_overloaded())
interface IOverloaded
{
}
