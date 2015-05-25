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
package de.polygonal.zz.render.platform.flash.legacy;

import de.polygonal.ds.Itr;
import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;

/**
	An iterator for traversing the display list.
**/
class DisplayListIterator implements de.polygonal.ds.Itr<DisplayObject>
{
	public static function iterator(root:DisplayObjectContainer):DisplayListIterator
	{
		return new DisplayListIterator(root);
	}
	
	var mRoot:DisplayObjectContainer;
	var mStack:Array<DisplayObject>;
	var mStackSize:Int;
	
	public function new(root:DisplayObjectContainer)
	{
		mStack = new Array<DisplayObject>();
		mRoot = root;
		reset();
	}
	
	public function hasNext():Bool
	{
		return mStackSize > 0;
	}
	
	public function reset():Itr<DisplayObject>
	{
		mStack[0] = mRoot;
		mStackSize = 1;
		return this;
	}
	
	public function next():DisplayObject
	{
		var o = mStack[--mStackSize];
		if (Std.is(o, DisplayObjectContainer))
		{
			var c:DisplayObjectContainer = untyped o;
			for (i in 0...c.numChildren) mStack[mStackSize++] = c.getChildAt(i);
		}
		return o;
	}
	
	public function remove()
	{
		throw "unsupported operation";
	}
}