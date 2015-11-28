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
package de.polygonal.zz.scene;

import de.polygonal.core.math.Coord2f;
import de.polygonal.core.math.Mat44;
import de.polygonal.core.math.Mathematics.M;
import de.polygonal.core.math.Rectf;
import de.polygonal.core.math.Recti;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.render.Renderer;

/**
	A camera defines the region that is shown in the render-target.
	
	It is composed of a source rectangle (defined with setSize()), which defines _what_ part of the scene is shown,
	and a target viewport which defines _where_ the contents of the source rectangle will be displayed on the render target (window).
	
	This allows you to scroll, rotate or zoom the entire scene.
**/
@:access(de.polygonal.zz.render.Renderer)
class Camera
{
	public var enabled:Bool = true;
	
	/**
		The size of the source rectangle which defines what part of the scene is shown.
	**/
	public function getSize():Sizei
	{
		mSizeOut.of(mSize);
		return mSizeOut;
	}
	
	/**
		Sets the size of the source rectangle in world space to define what part of the scene is shown.
		
		E.g. if the render-target has the same dimensions as `size`, everything is rendered 1:1 (one pixel equals one world unit).
	**/
	public function setSize(width:Int, height:Int)
	{
		mSize.x = width;
		mSize.y = height;
		invalidate();
	}
	
	public var sizeX(get_sizeX, set_sizeX):Int;
	inline function get_sizeX():Int
	{
		return mSize.x;
	}
	function set_sizeX(value:Int):Int
	{
		mSize.x = value;
		invalidate();
		return value;
	}
	
	public var sizeY(get_sizeY, set_sizeY):Int;
	inline function get_sizeY():Int
	{
		return mSize.y;
	}
	function set_sizeY(value:Int):Int
	{
		mSize.y = value;
		invalidate();
		return value;
	}
	
	public var centerX(get_centerX, set_centerX):Float;
	inline function get_centerX():Float
	{
		return mCenter.x;
	}
	function set_centerX(value:Float):Float
	{
		mCenter.x = value;
		invalidate();
		return value;
	}
	
	public var centerY(get_centerY, set_centerY):Float;
	inline function get_centerY():Float
	{
		return mCenter.y;
	}
	function set_centerY(value:Float):Float
	{
		mCenter.y = value;
		invalidate();
		return value;
	}
	
	/**
		The center position of the source rectangle in world space (the "eye" position).
	**/
	public function getCenter():Coord2f
	{
		mCenterOut.of(mCenter);
		return mCenterOut;
	}
	
	/**
		The center position of the source rectangle in world space (the "eye" position).
	**/
	public function setCenter(x:Float, y:Float)
	{
		mCenter.x = x;
		mCenter.y = y;
		invalidate();
	}
	
	/**
		The rotation angle of the image plane, in degrees.
	**/
	public var rotation(get_rotation, set_rotation):Float;
	inline function get_rotation():Float
	{
		return mRotation;
	}
	inline function set_rotation(value:Float):Float
	{
		invalidate();
		return mRotation = value;
	}
	
	/**
		Simulates zoom by resizing the image plane relatively to its current size.
		
		- a zoom factor > 1 makes the view smaller so objects appear bigger.
		- a zoom factor < 1 makes the view bigger so objects appear smaller.
	**/
	
	public var zoom(get_zoom, set_zoom):Float;
	inline function get_zoom():Float
	{
		return mZoom;
	}
	inline function set_zoom(value:Float):Float
	{
		invalidate();
		return mZoom = value;
	}
	
	var mSize:Sizei;
	var mSizeOut:Sizei;
	
	var mCenter:Coord2f;
	var mCenterOut:Coord2f;
	
	var mRotation:Float = 0;
	var mZoom:Float = 1;
	
	var mViewport:Rectf;
	var mViewportOut:Rectf;
	
	var mViewMatrix:Mat44;
	var mInvViewMatrix:Mat44;
	
	var mRenderer:Renderer;
	
	var mTransformChanged:Bool;
	var mInvTransformChanged:Bool;
	
	public function new(renderer:Renderer)
	{
		mRenderer = renderer;
		
		mSize = new Sizei();
		mSizeOut = new Sizei();
		
		mCenter = new Coord2f();
		mCenterOut = new Coord2f();
		
		mViewport = new Rectf(0, 0, 1, 1);
		mViewportOut = new Rectf(0, 0, 1, 1);
		
		mViewMatrix = new Mat44();
		mInvViewMatrix = new Mat44();
		
		reset(new Recti(0, 0, 512, 512));
	}
	
	public function free()
	{
		mCenter = null;
		mViewMatrix = null;
	}
	
	/**
		The target viewport rectangle, defined as a ratio in the range [0,1] of the size of the render-target.
		
		- useful for implementing split-screens or mini-maps
		- if the source rectangle has not the same size as the viewport, its contents will be stretched to fit in.
	**/
	/*public function getViewport():Rectf
	{
		mViewportOut.of(mViewport);
		return mViewportOut;
	}
	
	public function setViewport(value:Rectf)
	{
		mViewport.of(value);
		mRenderer.getRenderTarget().setViewport(getViewport());
		invalidate();
		return value;
	}*/
	
	/**
		Resets the camera to show the region inside the given `rect` rectangle.
		
		- this also sets the rotation to 0 and the zoom factor to 1.
		- the viewport is left untouched.
	**/
	public function reset(rect:Recti)
	{
		mCenter.x = rect.x + rect.w / 2;
		mCenter.y = rect.y + rect.h / 2;
		mSize.x = rect.w;
		mSize.y = rect.h;
		mRotation = 0;
		mZoom = 1;
		mTransformChanged = true;
		mInvTransformChanged = true;
	}
	
	/**
		Transform vertices from world-space to camera-space.
	**/
	public function getViewMatrix():Mat44
	{
		if (mTransformChanged)
		{
			mTransformChanged = false;
			
			//scale and rotate around center (=eye) point
			var tx = mCenter.x;
			var ty = mCenter.y;
			mViewMatrix.setAsTranslate(-tx, -ty, 0);
			mViewMatrix.catScale(zoom, zoom, 1);
			mViewMatrix.catRotateZ(rotation * M.DEG_RAD);
			mViewMatrix.catTranslate(tx, ty, 0);
			
			//move to eye position
			mViewMatrix.catTranslate(-tx, -ty, 0);
			
			//TODO recompute inverse transform matrix?
		}
		
		return mViewMatrix;
	}
	
	/**
		Transform vertices from camera-space to world-space.
	**/
	public function getInvViewMatrix():Mat44
	{
		if (mInvTransformChanged)
		{
			mInvTransformChanged = false;
			mViewMatrix.inverseConst(mInvViewMatrix);
		}
		
		return mInvViewMatrix;
	}
	
	inline function invalidate()
	{
		mTransformChanged = true;
		mInvTransformChanged = true;
		mRenderer.onCameraChanged();
	}
}