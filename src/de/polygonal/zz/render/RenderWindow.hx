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
import de.polygonal.core.math.Rectf;
import de.polygonal.zz.data.Size.Sizei;

@:access(de.polygonal.zz.render.RenderWindowListener)
class RenderWindow extends RenderTarget
{
	public var multiTouch(get, set):Bool;
	inline function get_multiTouch():Bool return mMultiTouch;
	function set_multiTouch(value:Bool):Bool return mMultiTouch = value;
	
	public var dpi(default, null):Int = 96;
	
	var mListener:RenderWindowListener;
	var mPointer = new Coord2i();
	var mMultiTouch = false;
	var mPressed = false;
	
	function new(listener:RenderWindowListener)
	{
		super();
		mListener = listener;
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
	
	/**
		Adjusts the viewport to match `contentSize`.
	**/
	public function fitContent(contentSize:Sizei, allowWindowBoxing = false, nonUniformThreshold = 1.)
	{
		var size = getSize();
		
		var v = new Rectf();
		var rx = size.x / contentSize.x;
		var ry = size.y / contentSize.y;
		
		if (allowWindowBoxing && rx >= 1 && ry >= 1)
		{
			//windowboxing
			v.x = ((size.x - contentSize.x) / 2) / size.x;
			v.y = ((size.y - contentSize.y) / 2) / size.y;
			v.w = contentSize.x / size.x;
			v.h = contentSize.y / size.y;
		}
		else
		if (rx <= ry)
		{
			//letterboxing
			var h = contentSize.y * rx / size.y;
			if (h >= nonUniformThreshold) h = 1; //allow some non-uniform scaling
			v.x = 0;
			v.y = (1 - h) / 2;
			v.w = 1;
			v.h = h;
		}
		else
		{
			//pillarboxing
			var w = contentSize.x * ry / size.x;
			if (w >= nonUniformThreshold) w = 1; //allow some non-uniform scaling
			v.x = (1 - w) / 2;
			v.y = 0;
			v.w = w;
			v.h = 1;
		}
		
		setViewport(v);
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