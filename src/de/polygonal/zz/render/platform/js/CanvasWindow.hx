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
package de.polygonal.zz.render.platform.js;

import de.polygonal.core.math.Coord2.Coord2i;
import de.polygonal.core.math.Mathematics;
import de.polygonal.zz.render.RenderWindowListener;
import haxe.Timer;
import js.Browser;
import js.html.CanvasElement;
import js.html.Event;
import js.html.EventTarget;
import js.html.TouchEvent;
import js.html.MouseEvent;

@:access(de.polygonal.zz.render.Renderer)
@:access(de.polygonal.zz.render.RenderWindowListener)
class CanvasWindow extends RenderWindow
{
	public var canvas(default, null):CanvasElement;
	
	var mFullscreen = false;
	var mContext:Dynamic;
	var mUseExistingCanvasElement:Bool;
	var mTimer:Timer;
	var mFirstTouchId:Float = null;
	var mOffset = new Coord2i();
	var mDevicePixelRatio:Float = 1;
	var mCoord = new Coord2i();
	var mMouseButtonMask:Int = 1 << 1;
	
	public function new(listener:RenderWindowListener)
	{
		super(listener);
		
		var doc = Browser.document;
		var win = Browser.window;
		
		var div = doc.createDivElement();
		div.id = "tmpdiv";
		div.style.height = "1in";
		div.style.width = "1in";
		doc.body.appendChild(div);
		var dpiX = doc.getElementById("tmpdiv").offsetWidth * win.devicePixelRatio;
		var dpiY = doc.getElementById("tmpdiv").offsetHeight * win.devicePixelRatio;
		dpi = Mathematics.max(Std.int(Math.max(dpiX, dpiY)), 96);
		doc.body.removeChild(div);
		div = null;
		
		//disable elastic scrolling
		doc.body.addEventListener("touchmove", function(e) e.preventDefault(), false);
		
		//disable context menu
		doc.body.oncontextmenu = function() return false;
		
		mUseExistingCanvasElement = false;
		if (doc.body.getElementsByTagName("canvas").length == 1)
		{
			canvas = cast doc.body.getElementsByTagName("canvas").item(0);
			mUseExistingCanvasElement = true;
		}
		else
		{
			canvas = doc.createCanvasElement();
			canvas.id = "surface";
			doc.body.appendChild(canvas);
		}
		
		if (isFullscreenSupported())
		{
			addPrefixListener(doc, "fullscreenchange", onFullscreenChange);
			addPrefixListener(doc, "MSFullscreenChange", onFullscreenChange);
		}
		
		var hidden = callPrefixMethod(doc, "hidden");
		if (hidden != null) //visibility api
			addPrefixListener(doc, "visibilitychange", onVisibilityChange);
		else
		{
			//ios
			win.addEventListener("pageshow", onVisibilityChange);
			win.addEventListener("pagehide", onVisibilityChange);
		}
		
		var target:EventTarget = mUseExistingCanvasElement ? canvas.parentElement : win;
		if (doc.createTouch == null)
		{
			target.addEventListener("mousedown", onMouseDown);
			target.addEventListener("mouseup", onMouseUp);
			target.addEventListener("mousemove", onMouseMove);
			target.addEventListener("click", onClick);
		}
		else
		{
			target.addEventListener("touchstart", onTouchStart);
			target.addEventListener("touchend", onTouchEnd);
			target.addEventListener("touchmove", onTouchMove);
		}
		
		if (!mUseExistingCanvasElement) win.addEventListener("resize", onResize);
	}
	
	public function initCanvas2dContext()
	{
		mContext = canvas.getContext2d();
		
		configureBackBuffer();
		
		mListener.onContext();
		
		detectResize();
		
		mTimer = new Timer(1000);
		mTimer.run = detectResize;
		mTimer.run();
	}
	
	public function initWebGlContext()
	{
		//https://www.khronos.org/registry/webgl/specs/latest/1.0/#5.2
		var attributes =
		{
			alpha: true,
			antialias: true,
			depth: true,
			premultipliedAlpha: true,
			preserveDrawingBuffer: false,
			stencil: true
		};
		
		Reflect.setField(attributes, "failIfMajorPerformanceCaveat", true);
		Reflect.setField(attributes, "preferLowPowerToHighPerformance", true);
		mContext = canvas.getContextWebGL(attributes);
		
		configureBackBuffer();
		
		mListener.onContext();
		
		detectResize();
		
		mTimer = new Timer(1000);
		mTimer.run = detectResize;
		mTimer.run();
	}
	
	public function enableRightMouseButton()
	{
		mMouseButtonMask |= 1 << 3;
	}
	
	public function enableMiddleMouseButton()
	{
		mMouseButtonMask |= 1 << 2;
	}
	
	override public function free()
	{
		super.free();
		
		var doc = Browser.document;
		var win = Browser.window;
		win.removeEventListener("mousedown", onMouseDown);
		win.removeEventListener("mouseup", onMouseUp);
		win.removeEventListener("mousemove", onMouseMove);
		win.removeEventListener("click", onClick);
		win.removeEventListener("touchstart", onTouchStart);
		win.addEventListener("touchend", onTouchEnd);
		win.addEventListener("touchmove", onTouchMove);
		win.removeEventListener("resize", onResize);
		removePrefixListener(doc, "fullscreenchange", onFullscreenChange);
		removePrefixListener(doc, "MSFullscreenChange", onFullscreenChange);
		removePrefixListener(doc, "visibilitychange", onVisibilityChange);
		win.removeEventListener("pageshow", onVisibilityChange);
		win.removeEventListener("pagehide", onVisibilityChange);
	}
	
	override public function getContext():Dynamic
	{
		return mContext;
	}
	
	override public function getPointer():Coord2i
	{
		return mPointer;
	}
	
	override public function showCursor() 
	{
		canvas.style.cursor = "default";
	}
	
	override public function hideCursor()
	{
		canvas.style.cursor = "none";
	}
	
	override public function hideContextMenu()
	{
		Browser.window.oncontextmenu = function(e) return false;
	}
	
	override public function isFullscreen():Bool
	{
		return mFullscreen;
	}
	
	override public function isFullscreenSupported():Bool
	{
		return callPrefixMethod(Browser.document, ["fullscreenEnabled", "fullScreenEnabled"]) == true;
	}
	
	override public function enterFullscreen()
	{
		if (!isFullscreenSupported() || mFullscreen) return;
		
		callPrefixMethod(Browser.document.documentElement, ["requestFullScreen", "requestFullscreen"]);
	}
	
	override public function leaveFullscreen()
	{
		callPrefixMethod(Browser.document, ["exitFullscreen", "cancelFullScreen"]);
	}
	
	override function configureBackBuffer()
	{
		var view = getPixelViewport();
		
		inline function px(value:Int) return '${value}px';
		
		var s = canvas.style;
		s.position = "absolute";
		s.left   = px(Std.int(view.x / mDevicePixelRatio));
		s.top    = px(Std.int(view.y / mDevicePixelRatio));
		s.width  = px(Std.int(view.w / mDevicePixelRatio));
		s.height = px(Std.int(view.h / mDevicePixelRatio));
		
		if (internalResolution != null)
		{
			canvas.width = internalResolution.x;
			canvas.height = internalResolution.y;
		}
		else
		{
			canvas.width = view.w;
			canvas.height = view.h;
		}
	}
	
	function onFullscreenChange(_)
	{
		var state = callPrefixMethod(Browser.document, ["isFullScreen", "fullScreen"]);
		if (state != null)
			mFullscreen = state;
		else
		{
			var o = callPrefixMethod(Browser.document, "fullscreenElement"); //ie
			mFullscreen = o != null;
		}
		
		mListener.onFullscreenChanged(mFullscreen);
	}
	
	function onVisibilityChange(e:Event)
	{
		if (~/visibilitychange/i.match(e.type))
		{
			var hidden:Bool = callPrefixMethod(Browser.document, "hidden");
			mListener.onVisibilityChanged(!hidden);
		}
		else
		{
			switch (e.type)
			{
				case "pageshow": mListener.onVisibilityChanged(true);
				case "pagehide": mListener.onVisibilityChanged(false);
			}
		}
	}
	
	function onResize(_)
	{
		var viewport:Dynamic = Browser.document.querySelector("meta[name=viewport]");
		untyped __js__("viewport.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0')");
		
		var win = Browser.window;
		var w = win.innerWidth;
		var h = win.innerHeight;
		mDevicePixelRatio = win.devicePixelRatio;
		w = Std.int(w * mDevicePixelRatio);
		h = Std.int(h * mDevicePixelRatio);
		
		resize(w, h);
	}
	
	function onMouseDown(e:MouseEvent)
	{
		if (mMouseButtonMask & (1 << e.which) == 0) return;
		
		mPressed = true;
		var x = e.clientX - mOffset.x;
		var y = e.clientY - mOffset.y;
		onInput(x, y, Press, 0, true, cast e.which);
	}
	
	function onMouseUp(e:MouseEvent)
	{
		if (mMouseButtonMask & (1 << e.which) == 0) return;
		
		mPressed = false;
		var x = e.clientX - mOffset.x;
		var y = e.clientY - mOffset.y;
		onInput(x, y, Release, true, cast e.which);
	}
	
	function onMouseMove(e:MouseEvent)
	{
		var x = e.clientX - mOffset.x;
		var y = e.clientY - mOffset.y;
		onInput(x, y, Move);
	}
	
	function onClick(e:MouseEvent)
	{
		if (mMouseButtonMask & (1 << e.which) == 0) return;
		
		var x = e.clientX - mOffset.x;
		var y = e.clientY - mOffset.y;
		onInput(x, y, Select, 0, true, cast e.which);
	}
	
	function onTouchStart(e:TouchEvent)
	{
		e.preventDefault(); 
		var x, y, updatePointer;
		if (multiTouch)
		{
			for (i in e.changedTouches)
			{
				x = i.clientX - mOffset.x;
				y = i.clientY - mOffset.y;
				
				updatePointer = false;
				if (mFirstTouchId == null)
				{
					mPressed = true;
					mFirstTouchId = i.identifier;
					updatePointer = true;
				}
				
				onInput(x, y, Press, i.identifier, updatePointer);
			}
		}
		else
		{
			for (i in e.changedTouches)
			{
				if (mFirstTouchId == null)
				{
					mPressed = true;
					mFirstTouchId = i.identifier;
					x = i.clientX - mOffset.x;
					y = i.clientY - mOffset.y;
					onInput(x, y, Press, i.identifier);
					break;
				}
			}
		}
	}
	
	function onTouchEnd(e:TouchEvent)
	{
		var x, y;
		if (multiTouch)
		{
			for (i in e.changedTouches)
			{
				x = i.clientX - mOffset.x;
				y = i.clientY - mOffset.y;
				onInput(x, y, Release, i.identifier, i.identifier == mFirstTouchId);
				onInput(x, y, Select, i.identifier, false);
			}
		}
		else
		{
			for (i in e.changedTouches)
			{
				if (i.identifier == mFirstTouchId)
				{
					mFirstTouchId = null;
					x = i.clientX - mOffset.x;
					y = i.clientY - mOffset.y;
					onInput(x, y, Release, i.identifier);
					onInput(x, y, Select, i.identifier, false);
					mPressed = false;
					break;
				}
			}
		}
	}
	
	function onTouchMove(e:TouchEvent)
	{
		var x, y;
		if (multiTouch)
		{
			for (i in e.changedTouches)
			{
				x = i.clientX - mOffset.x;
				y = i.clientY - mOffset.y;
				onInput(x, y, Move, i.identifier, i.identifier == mFirstTouchId);
			}
		}
		else
		{
			for (i in e.changedTouches)
			{
				if (i.identifier == mFirstTouchId)
				{
					x = i.clientX - mOffset.x;
					y = i.clientY - mOffset.y;
					onInput(x, y, Move, i.identifier);
					break;
				}
			}
		}
	}
	
	function onInput(x:Int, y:Int, type:InputType, id = 0, updatePointer = true, hint:InputHint = cast 0)
	{
		x = Std.int(x * mDevicePixelRatio);
		y = Std.int(y * mDevicePixelRatio);
		if (updatePointer) mPointer.set(x, y);
		
		if (!mPressed && type == Move) return;
		if (!pointerInsideViewport(x, y)) return;
		
		mListener.onInput(mCoord.set(x, y), type, id, hint);
	}
	
	function detectResize()
	{
		var w, h;
		
		if (mUseExistingCanvasElement)
		{
			var p = canvas.parentElement;
			w = p.clientWidth;
			h = p.clientHeight;
			mOffset.set(p.offsetLeft, p.offsetTop);
		}
		else
		{
			w = Browser.window.innerWidth;
			h = Browser.window.innerHeight;
			mOffset.set(0, 0);
		}
		
		mDevicePixelRatio = Browser.window.devicePixelRatio;
		w = Std.int(w * mDevicePixelRatio);
		h = Std.int(h * mDevicePixelRatio);
		
		if (mSize.x != w || mSize.y != h)
		{
			resize(w, h);
			Browser.window.scrollTo(0, 1); //http://stackoverflow.com/questions/6011223/how-to-completely-hide-the-navigation-bar-in-iphone-html5/6011305#6011305
		}
	}
	
	function callPrefixMethod(object:Dynamic, ?name:String, ?names:Array<String>):Dynamic
	{
		var a = [name];
		if (names != null) a = names;
		for (i in a)
		{
			for (prefix in ["webkit", "moz", "ms", "o", ""])
			{
				var s = i;
				if (prefix != "") s = i.substr(0, 1).toUpperCase() + i.substr(1);
				s = prefix + s;
				untyped
				{
					var t = __typeof__(object[s]);
					if (__js__("t !== 'undefined'"))
						return __js__("t == 'function' ? object[s]() : object[s]");
				}
			}
		}
		return null;
	}
	
	function addPrefixListener(dispatcher:EventTarget, type:String, listener:Dynamic)
	{
		for (prefix in ["webkit", "moz", "ms", "o", ""])
			dispatcher.addEventListener(prefix + type, listener);
	}
	
	function removePrefixListener(dispatcher:EventTarget, type:String, listener:Dynamic)
	{
		for (prefix in ["webkit", "moz", "ms", "o", ""])
			dispatcher.removeEventListener(prefix + type, listener);
	}
}