/*
Copyright (c) 2014 Michael Baczynski, http://www.polygonal.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package de.polygonal.zz.controller;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
	Adds a static constant storing an unique integer value.
	
	Example:
	
	<pre>
	@:autoBuild(de.polygonal.zz.controller.ControllerMacro.build("TYPE"))
	class A {}
	class B extends A {}
	class C extends A {}
	</pre>
	
	Result:
	
	<pre>
	class A {}
	
	class B extends A
	{
	    inline public static var TYPE:Int = 1;
	    public function new()
	    {
	        super();
	    }
	}
	class C extends A
	{
	    inline public static var TYPE:Int = 2;
	    public function new()
	    {
	        super();
	    }
	}
	</pre>
**/
class ControllerType
{
	#if macro
	macro public static function build(name:String = "TYPE"):Array<Field>
	{
		_counter++;
		var p = Context.currentPos();
		var fields = Context.getBuildFields();
		fields.push(
		{
			name: name,
			doc: null,
			meta: [{name: ":keep", pos: p}],
			access: [APublic, AStatic, AInline],
			kind: FVar(TPath({pack: [], name: "Int", params: [], sub: null}), {expr: EConst(CInt(Std.string(_counter))), pos: p}),
			pos: p
		});
		return fields;
	}
	static var _counter = 0;
	#end
}