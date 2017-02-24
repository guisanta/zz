/*
Copyright (c) 2017 Michael Baczynski, http://www.polygonal.de

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
package de.polygonal.zz.tools.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

class MakePublicVarsReadOnly
{
	macro public static function build():Array<Field>
	{
		var publicFields = Context.getLocalClass().get().meta.has(":publicFields");
		
		var fields = Context.getBuildFields();
		var out = [];
		for (i in fields)
		{
			switch (i.kind)
			{
				case FVar(tp, b):
					
					if (i.access.length == 1 && i.access[0] == APublic ||
						i.access.length == 0 && publicFields)
					{
						out.push({
								name: i.name,
								doc: i.doc,
								access: i.access,
								kind: FProp("default", "null", tp),
								pos: i.pos,
								meta: i.meta
							});
					}
					else
						out.push(i);
				
				case _:
					out.push(i);
			}
		}
		return out;
	}
}