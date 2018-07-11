# haxe-seoverload
Haxe macro library to support overloaded functions (via static extension, or abstract.)

- Status: beta
- [Discussion thread](https://community.haxe.org/t/toying-with-a-macro-for-overloading-via-static-extension/840/)

## Purpose

Haxe doesn't natively support overloaded functions. That's probably for the best. But some
APIs just feel nicer with overloaded methods.

For example, I suggest JavaScript's [String.replace](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replace)
API -- which takes strings, regular expressions, and a replacement string or a replacer function -- is rather tidy. I don't have
to remember that, in Haxe's native API, these capabilities are spread out under `StringTools.replace`, `EReg.replace`,
and `EReg.map`.

But to achieve this in native, staticly typed Haxe, I'd need 1) some way to map my calls to the correct
function signature, and 2) proper VSCode completion support. That is precisely what this library does.

It lets you write libraries that look like this:

![image](https://user-images.githubusercontent.com/2192439/42592807-e0e107a6-8507-11e8-96fe-4800a342d82e.png)

And by `using MyStringTools` it provides overloaded functions via static extension, even with proper code completion:

![compl](https://user-images.githubusercontent.com/2192439/42593316-54306188-8509-11e8-86ed-cea293722f59.gif)

## Limitations

- The functions are renamed under the hood, so you can't call them dynamically at runtime. Let me know if you're interested in runtime invocation.
- See issues.

## Terminology

Let's use the simple phrase "tools class" to mean, a class with (zero or more) overloaded methods,
intended to be used as a static extension.

## Requirements

- Your tools class must implement `SEOMacro.Overloaded`
- Overloaded methods must be static functions of a tools class.

## Install

### Via Haxelib:

1) Install: `haxelib install seoverload`

2) Add to your build.hxml file: `-lib seoverload`

### Manually:

1) Copy `SEOMacro.hx` into your class path

2) Add to your build.hxml file the contents of extraParams.hxml:

```haxe
--macro addGlobalMetadata("", "@:build(SEOMacro.build_all())")
```

## Usage

The seoverload library doesn't include any tools classes by default. You're expected
to write them. Here's an example tools class:

```haxe
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

```haxe
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
