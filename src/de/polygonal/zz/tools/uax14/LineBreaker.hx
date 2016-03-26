/*
Copyright (c) 2016 Michael Baczynski, http://www.polygonal.de

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
package de.polygonal.zz.tools.uax14;

import de.polygonal.zz.tools.uax14.BreakClass.*;
import de.polygonal.zz.tools.uax14.Pairs.*;

typedef LineBreakInfo = { position:Int, required:Bool }

/**
	An implementation of the Unicode Line Breaking Algorithm (UAX #14)
	See https://github.com/devongovett/linebreak
**/
class LineBreaker
{
	var classTrie:UnicodeTrie;
	
	var mString:String;
	
	var pos = 0;
	var lastPos = 0;
	var curClass:Dynamic = null;
	var nextClass:Dynamic = null;
	
	public function new()
	{
		classTrie = new UnicodeTrie();
		reset();
	}
	
	public function setText(string:String)
	{
		mString = string;
		reset();
	}
	
	function reset()
	{
		pos = 0;
		lastPos = 0;
		curClass = null;
		nextClass = null;
	}
	
	public function nextBreak():LineBreakInfo
	{
		inline function mapClass(x)
		{
			return
				switch (x)
				{
					case AI, SA, SG, XX: AL;
					case CJ: NS;
					case _: x;
				}
		};
		
		inline function mapFirst(x:Int)
		{
			return
				switch (x)
				{
					case LF, NL: BK;
					case CB: BA;
					case SP: WJ;
					case _: x;
				}
		};
		
		function nextCharClass(first = false)
		{
			inline function nextCodePoint()
			{
				var code = mString.charCodeAt(pos++);
				var next = mString.charCodeAt(pos);
				
				return
				if ((0xd800 <= code && code <= 0xdbff) && (0xdc00 <= next && next <= 0xdfff))
				{
					pos++;
					((code - 0xd800) * 0x400) + (next - 0xdc00) + 0x10000;
				}
				else
					code;
			};
			
			var t = classTrie.get(nextCodePoint());
			return mapClass(t);
		};
		
		inline function breakobj(position:Int, required:Bool = null)
			return {position: position, required: required != null ? required : false};
		
		var lut = Pairs.pairTable;
		
		var cur = -1, lastClass, shouldBreak;
		if (curClass == null)
		{
			curClass = mapFirst(nextCharClass());
		}
		while (pos < mString.length)
		{
			lastPos = pos;
			lastClass = nextClass;
			nextClass = nextCharClass();
			if (curClass == BK || (curClass == CR && nextClass != LF))
			{
				curClass = mapFirst(mapClass(nextClass));
				return breakobj(lastPos, true);
			}
			
			cur = 
			switch (nextClass)
			{
				case SP: curClass;
				case BK, LF, NL: BK;
				case CR: CR;
				case CB: BA;
				case _: -1;
			}
			
			if (cur != -1)
			{
				curClass = cur;
				if (nextClass == CB)
					return breakobj(lastPos);
				continue;
			}
			
			shouldBreak = false;
			
			switch (lut[curClass][nextClass])
			{
				case DI_BRK:
					shouldBreak = true;
				
				case IN_BRK:
					shouldBreak = lastClass == SP;
				
				case CI_BRK:
					shouldBreak = lastClass == SP;
					if (!shouldBreak)
						continue;
				
				case CP_BRK:
					if (lastClass != SP)
						continue;
			}
			
			curClass = nextClass;
			if (shouldBreak)
				return breakobj(lastPos);
		}
		
		if (pos >= mString.length)
		{
			if (lastPos < mString.length)
			{
				lastPos = mString.length;
				return breakobj(mString.length);
			}
			else
				return null;
		}
		return null;
	};
}