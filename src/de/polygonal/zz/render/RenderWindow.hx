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

import de.polygonal.core.math.Coord2.Coord2i;
import de.polygonal.ds.Bits;
import de.polygonal.zz.render.RenderWindowListener.InputType;
import haxe.EnumFlags;

@:access(de.polygonal.zz.render.RenderWindowListener)
class RenderWindow extends RenderTarget
{
	public var multiTouch(get_multiTouch, set_multiTouch):Bool;
	inline function get_multiTouch():Bool return mMultiTouch;
	function set_multiTouch(value:Bool):Bool return mMultiTouch = value;
	
	public var dpi(default, null):Int = 96;
	
	var mListener:RenderWindowListener;
	var mPointer = new Coord2i();
	var mMultiTouch = false;
	var mMouseDown = false;
	
	function new(listener:RenderWindowListener)
	{
		super();
		
		mListener = listener;
		mPointer = new Coord2i();
	}
	
	override public function free()
	{
		super.free();
		mListener = null;
		mPointer = null;
	}
	
	public function isFullscreen():Bool
	{
		return throw "override for implementation";
	}
	
	public function isFullscreenSupported():Bool
	{
		return throw "override for implementation";
	}
	
	public function enterFullscreen()
	{
		throw "override for implementation";
	}
	
	public function leaveFullscreen()
	{
		throw "override for implementation";
	}
	
	public function showCursor()
	{
		throw "override for implementation";
	}
	
	public function hideCursor()
	{
		throw "override for implementation";
	}
	
	public function hideContextMenu()
	{
		throw "override for implementation";
	}
	
	public function getPointer():Coord2i
	{
		throw "override for implementation";
	}
	
	override public function resize(width:Int, height:Int)
	{
		super.resize(width, height);
		
		mListener.onResize(getSize());
	}
	
	inline function pointerInsideViewport(x:Int, y:Int):Bool
	{
		if (hasViewport())
		{
			var v = getPixelViewport();
			return (x < v.x || y < v.y || x > v.r || y > v.b) ? false : true;
		}
		else
			return true;
	}
}