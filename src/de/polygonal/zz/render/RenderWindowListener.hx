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
package de.polygonal.zz.render;

import de.polygonal.core.math.Coord2i;
import de.polygonal.zz.data.Size.Sizei;

enum InputType { Press; Release; Move; Select; }

@:enum
abstract InputHint(Int)
{
	var LeftButton = 1;
	var MiddleButton = 2;
	var RightButton = 3;
}

interface RenderWindowListener
{
	private function onContext():Void;
	
	private function onResize(size:Sizei):Void;
	
	private function onVisibilityChanged(isVisible:Bool):Void;
	
	private function onFullscreenChanged(isFullscreen:Bool):Void;
	
	private function onInput(coord:Coord2i, type:InputType, id:Int, hint:InputHint = cast 0):Void;
}