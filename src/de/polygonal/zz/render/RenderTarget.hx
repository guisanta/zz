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
import de.polygonal.core.math.Recti;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.texture.TextureLib;

@:access(de.polygonal.zz.render.Renderer)
class RenderTarget
{
	public var color:UInt = 0xffffffff;
	
	var mSize = new Sizei(0, 0);
	var mSizeOut = new Sizei(0, 0);
	var mViewport:Rectf = new Rectf(0, 0, 1, 1);
	var mViewportOut = new Rectf(0, 0, 1, 1);
	var mViewportPx = new Recti();
	var mViewportPxOut = new Recti();
	var mViewportChanged = true;
	var mViewportDefined = false;
	var mInvalidate = true;
	
	var mRenderer:Renderer;
	
	public var internalResolution:Sizei;
	
	function new()
	{
	}
	
	public function free()
	{
		mSize = null;
		mSizeOut = null;
		mViewport = null;
		mViewportOut = null;
		mViewportPx = null;
		mRenderer = null;
	}
	
	public function getContext():Dynamic
	{
		return throw "override for implementation";
	}
	
	/**
		A `renderer` draws into a render target.
	**/
	public function setRenderer(renderer:Renderer)
	{
		TextureLib.setRenderer(renderer);
		
		mRenderer = renderer;
		mRenderer.setRenderTarget(this);
		
		if (getContext() != null) renderer.onInitRenderContext(getContext());
	}
	
	/**
		The size of the rendering region (the device resolution).
	**/
	inline public function getSize():Coord2i
	{
		mSizeOut.of(mSize);
		return mSizeOut;
	}
	
	/**
		Clears the rendering region with a single color.
	**/
	public function clear()
	{
		assert(mRenderer != null);
		
		if (mInvalidate)
		{
			if (mSize.isZero()) return;
			
			L.i('configure back buffer ${mSize.x}x${mSize.y}px');
			
			configureBackBuffer();
			
			if (mRenderer != null)
				mRenderer.onTargetResize(mSize.x, mSize.y);
			
			mInvalidate = false;
		}
		
		mRenderer.clear();
	}
	
	/**
		Displays the back buffer.
	**/
	public function present()
	{
		assert(mRenderer != null);
		
		mRenderer.present();
	}
	
	/**
		Returns false if the viewport covers the entire window, otherwise returns true.
	**/
	inline public function hasViewport():Bool
	{
		return mViewportDefined;
	}
	
	/**
		The current viewport in the range [0,1].
	**/
	public function getViewport():Rectf
	{
		mViewportOut.of(mViewport);
		return mViewportOut;
	}
	
	/**
		The viewport is the rectangular region __of the window__ where the image is drawn.
	**/
	public function setViewport(viewport:Rectf)
	{
		if (viewport == null)
		{
			mViewport = new Rectf(0, 0, 1, 1);
			mViewportDefined = false;
		}
		else
		{
			mViewport = new Rectf();
			mViewport.of(viewport);
			mViewportDefined = !(
				viewport.x == 0 &&
				viewport.y == 0 &&
				viewport.w == 1 &&
				viewport.h == 1);
		}
		
		mViewportChanged = true;
		mInvalidate = true;
	}
	
	/**
		The pixels rectangle that the viewport covers in the render target.
	**/
	public function getPixelViewport():Recti
	{
		if (mViewportChanged)
		{
			mViewportChanged = false;
			
			var v = mViewport;
			var w = mSize.x;
			var h = mSize.y;
			
			if (mViewport == null)
			{
				mViewportPx.x = 0;
				mViewportPx.y = 0;
				mViewportPx.w = w;
				mViewportPx.h = h;
			}
			else
			{
				mViewportPx.x = Std.int(w * v.x + .5);
				mViewportPx.y = Std.int(h * v.y + .5);
				mViewportPx.w = Std.int(w * v.w);
				mViewportPx.h = Std.int(h * v.h);
			}
		}
		
		mViewportPxOut.of(mViewportPx);
		return mViewportPxOut;
	}
	
	public function resize(width:Int, height:Int)
	{
		L.d('resize render target: ${width}x${height}px');
		
		mSize.set(width, height);
		mInvalidate = true;
		mViewportChanged = true;
	}
	
	function configureBackBuffer()
	{
		throw "override for implementation";
	}
}