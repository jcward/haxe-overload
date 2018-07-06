# haxe-seoverload
Haxe macro library to support overloaded functions in static extensions

## Terminology

Let's use the simple phrase "tools class" to mean, a class with (zero or more) overloaded extension methods,
meant to be used as a static extension.

## Requirements

- Your tools class must implement `SEOMacro.Overloaded`
- Overloaded methods must be static functions of a tools class.

## Limitations

- The functions are renamed under the hood, so you can't call them dynamically at runtime. Let me know if you're interested in runtime invocation.
- Currently, each function name (e.g. `replace`) can only be defined in a single tools class.
- Code completion is not yet implemented, but there [is hope](https://twitter.com/Jeff__Ward/status/1014891629612707842) for proper completion...

## Install

### Via Haxelib:

1) Install: `haxelib install seoverload`

2) Add to your build.hxml file: `-lib seoverload`

### Manually:

1) Copy `SEOMacro.hx` into your class path

2) Add to your build.hxml file the contents of extraParams.hxml:

```
--macro addGlobalMetadata("", "@:build(SEOMacro.build_all())")
```

## Usage

The seoverloads library doesn't include any tools classes by default. You're expected
to write them. Here's an example tools class:

```
package some.pkg;

// Provides three replace methods on String, similar to JavaScript's str.replace()
class MyStringTools implements SEOMacro.Overloaded
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
```

And now you can use this tools class like so:

```
using some.pkg.MyStringTools;

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
```
