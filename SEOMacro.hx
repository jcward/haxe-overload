#if macro

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;

import haxe.ds.StringMap;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;

using Lambda;

typedef SEInfoType = {
  se_cls : haxe.macro.Type.ClassType,
  cnt_per_field : StringMap<Int>,
  cls_name:String
}

class SEOMacro
{

  private static inline var SEO_META_NAME = 'seoverload';
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

    var seoverload_metadata = [];
    for (name in fields_by_name.keys()) {
      // Only fields with more than 1 instance
      if (fields_by_name.get(name).length<2) continue;

      // Hmm, can't push a Map<String, Int> through meta...
      // seoverload_cnt.set(name, fields_by_name.get(name).length);
      seoverload_metadata.push(macro $v{ name });
      seoverload_metadata.push(macro $v{ fields_by_name.get(name).length });
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
    // var meta_expr = Context.parse('[ '+[ for (key in seoverload_cnt.keys()) '"$key" => ${ seoverload_cnt.get(key) }' ].join(',')+']', Context.currentPos());
    cls.meta.add(SEO_META_NAME, seoverload_metadata, Context.currentPos());

    return fields;
  }

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
      var meta = se_cls.meta.extract(SEO_META_NAME)[0];
      if (!(meta!=null && meta.params!=null && meta.params.length>0)) continue;

      // Convert metadata to StringMap<Int> (why doesn't $v{} support ["foo"=>5] ?)
      var seoverload_cnt = new StringMap<Int>();
      var i = 0;
      while (i<meta.params.length) {
        seoverload_cnt.set( meta.params[i].getValue(), meta.params[i+1].getValue() );
        i += 2;
      }
      // trace(seoverload_cnt); // e.g. { replace=>5, to_array=>3 }

      // trace('In ${ cls.name } using: ${ se_cls.name }');
      var cls_name = (se_cls.pack.length>0 ? se_cls.pack.join('.') : '') + '.' + se_cls.name;
      var se_info = { se_cls:se_cls, cnt_per_field:seoverload_cnt, cls_name:cls_name };
      
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

  private static function subject_has_field(subject:Expr, field_name:String):SHFResult
  {
    try {
      switch Context.typeof(subject) {
        case TInst(cls, cls_params):
          for (field in cls.get().fields.get()) if (field.name==field_name) return SHF_TRUE;
        default:
      }
    } catch (e:Dynamic) {
      return SHF_UNKNOWN;
    }

    return SHF_FALSE;
  }

  private static function modifyExpr(expr:Expr, se_info:SEInfoType):Expr
  {
    if (expr == null) return null;

    switch (expr.expr) {
      case ECall({ expr:EField(subject, field_name) }, params):
        if (subject_has_field(subject, field_name)!=SHF_TRUE && se_info.cnt_per_field.exists(field_name)) {
          var mapped_params = [ for (e in params) modifyExpr(e, se_info) ];
          var pe:Expr = macro $a{ mapped_params };
          var rtn = macro SEOMacro.check_se($subject, $v{ field_name }, $v{ se_info.cls_name }, $v{ se_info.cnt_per_field.get(field_name) }, ($pe : Array<Dynamic>));
          rtn.pos = expr.pos; // Report type errors at the site of the funciton call
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

    if (subject_has_field(subject, field_name)!=SHF_FALSE) {
      // TODO: check other usings? Issue #3
      return macro $e{ subject }.$field_name( $a{ ps} );
    }

    // Put the subject expression first in the list
    ps.unshift( subject );

    // We will simply try typing each function call.
    for (i in 0...num) {

      // Note: we could try to see if subject was the same type as the first
      //       function arg... but the compiler will already do that for us.
      var expanded_field = '${ field_name }${ overload_suffix(i) }';
      var eval = macro $p{ cls_name.split('.') }.$expanded_field($a{ ps });

      try {
        var t = Context.typeof(eval);
        // trace('TYPE IS: $t');
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

class SEOMacro
{
  public static macro function check_se(subject:Expr, field_name:String, cls_name:String, num:Int, params:Expr):Expr
  {
    return null;
  }
}

#end

@:autoBuild(SEOMacro.build_overloaded())
interface Overloaded
{
}

enum SHFResult {
  SHF_UNKNOWN;
  SHF_TRUE;
  SHF_FALSE;
}
