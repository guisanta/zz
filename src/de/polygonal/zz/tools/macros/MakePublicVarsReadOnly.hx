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