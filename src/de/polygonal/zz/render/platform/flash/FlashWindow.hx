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
package de.polygonal.zz.render.platform.flash;

import de.polygonal.core.math.Mathematics;
import de.polygonal.zz.render.RenderWindowListener;
import de.polygonal.zz.render.platform.flash.legacy.DisplayListUtil;
import flash.Lib;
import flash.display.*;
import flash.display3D.*;
import flash.events.*;
import flash.system.Capabilities;
import flash.ui.Mouse;

@:enum
abstract Stage3dAntiAliasFlag(Int) { var None = 0; var Low = 2; var High = 4; var Ultra = 16; }

@:access(de.polygonal.zz.render.RenderWindowListener)
@:access(de.polygonal.zz.render.Renderer)
class FlashWindow extends RenderWindow
{
	public var stage(default, null):Stage;
	
	var mStage3d:Stage3D;
	var mStage3dContext:Context3D;
	var mContextCreatedCounter:Int;
	var mAntiAliasFlag = Stage3dAntiAliasFlag.None;
	var mWantBestResolution = false;
	var mEnableDepthAndStencil = false;
	
	var mCanvas:DisplayObject;
	var mDrawBoxing:Bool;
	var mFullscreen = false;
	var mVisible = true;
	var mContext:Dynamic;
	
	public function new(listener:RenderWindowListener)
	{
		super(listener);
		stage = Lib.current.stage;
		stage.frameRate = 60;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.stageFocusRect = false;
		stage.doubleClickEnabled = true;
		stage.colorCorrection = ColorCorrection.OFF;
		dpi = Mathematics.max(Std.int(Capabilities.screenDPI), 96);
		stage.addEventListener(Event.RESIZE, onResize);
		stage.addEventListener(Event.FULLSCREEN, onFullScreen);
		stage.addEventListener(Event.ACTIVATE, onActivate);
		stage.addEventListener(Event.DEACTIVATE, onDeactivate);
		mSize.set(stage.stageWidth, stage.stageHeight);
	}
	
	override public function free()
	{
		super.free();
		
		if (mCanvas != null)
		{
			if (Std.is(mCanvas, DisplayObjectContainer))
				DisplayListUtil.removeAll(cast mCanvas);
			else
			if (Std.is(mCanvas, Bitmap))
				cast(mCanvas, Bitmap).bitmapData.dispose();
			else
			if (Std.is(mCanvas, Shape))
				cast(mCanvas, Shape).graphics.clear();
			
			DisplayListUtil.remove(mCanvas);
			mCanvas = null;
		}
		
		stage.removeEventListener(Event.RESIZE, onResize);
		stage.removeEventListener(Event.FULLSCREEN, onFullScreen);
		stage.removeEventListener(Event.ACTIVATE, onActivate);
		stage.removeEventListener(Event.DEACTIVATE, onDeactivate);
		stage.removeEventListener(MouseEvent.RIGHT_CLICK, onRightClick);
		
		stage = null;
		
		if (mStage3d != null)
		{
			if (mStage3dContext != null)
			{
				mStage3dContext.dispose();
				mStage3dContext = null;
			}
			mStage3d = null;
		}
	}
	
	public function initLegacyContext(canvas:DisplayObject, drawBoxing = true):FlashWindow
	{
		mDrawBoxing = drawBoxing;
		
		canvas.name = "canvas";
		
		mContext = canvas;
		
		if (Std.is(canvas, Bitmap))
			mContext = null;
		else
		if (Std.is(canvas, Shape))
			mContext = cast(canvas, Shape).graphics;
		
		if (Std.is(canvas, InteractiveObject))
		{
			var o:InteractiveObject = cast canvas;
			o.tabEnabled = false;
			o.mouseEnabled = false;
		}
		
		if (Std.is(canvas, DisplayObjectContainer))
		{
			var o:DisplayObjectContainer = cast canvas;
			o.mouseChildren = false;
			o.tabChildren = false;
		}
		
		if (canvas.parent == null) stage.addChild(canvas);
		
		mCanvas = canvas;
		
		configureBackBuffer();
		
		mListener.onContext();
		
		resize(stage.stageWidth, stage.stageHeight);
		return this;
	}
	
	public function initStage3dContext(?renderMode:Context3DRenderMode, ?profile:Context3DProfile):FlashWindow
	{
		if (renderMode == null) renderMode = Context3DRenderMode.AUTO;
		
		mStage3d = stage.stage3Ds[0];
		mStage3d.addEventListener(Event.CONTEXT3D_CREATE, onContext3dCreate);
		mStage3d.addEventListener(ErrorEvent.ERROR, onError);
		mContextCreatedCounter = 0;
		
		try
		{
			if (profile == null) profile = flash.display3D.Context3DProfile.BASELINE;
			L.d('requesting context (profile=$profile)', "stage3d");
			mStage3d.requestContext3D(cast renderMode, profile);
		}
		catch(error:Dynamic)
		{
			L.e(Std.string(error), "stage3d");
		}
		return this;
	}
	
	public function setAntiAliasFlag(flag:Stage3dAntiAliasFlag)
	{
		mAntiAliasFlag = flag;
		configureBackBuffer();
	}
	
	override public function getContext():Dynamic
	{
		return mContext;
	}
	
	override public function showCursor()
	{
		Mouse.show();
	}
	
	override public function hideCursor()
	{
		Mouse.hide();
	}
	
	override public function hideContextMenu()
	{
		stage.addEventListener(MouseEvent.RIGHT_CLICK, onRightClick);
	}
	
	override public function isFullscreen():Bool
	{
		return mFullscreen;
	}
	
	override public function isFullscreenSupported():Bool
	{
		#if air
		return false;
		#else
		return Lib.current.stage.allowsFullScreenInteractive;
		#end
	}
	
	override public function enterFullscreen()
	{
		stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
	}
	
	override public function leaveFullscreen()
	{
		stage.displayState = StageDisplayState.NORMAL;
	}
	
	override function configureBackBuffer()
	{
		var view = getPixelViewport();
		
		if (mStage3d != null)
		{
			if (mStage3dContext == null || mStage3dContext.driverInfo == "Disposed") return;
			
			mStage3dContext.configureBackBuffer(view.w, view.h,
				cast mAntiAliasFlag, mEnableDepthAndStencil, mWantBestResolution);
			mStage3d.x = view.x;
			mStage3d.y = view.y;
			return;
		}
		
		assert(mCanvas != null);
		
		function drawBoxing()
		{
			if (!mDrawBoxing) return;
			
			var boxing:Shape = cast mCanvas.parent.getChildByName("boxing");
			if (hasViewport())
			{
				if (boxing == null)
				{
					boxing = new Shape();
					boxing.name = "boxing";
					mCanvas.parent.addChild(boxing);
				}
				var g = boxing.graphics;
				g.clear();
				g.beginFill(0, 1);
				g.drawRect(0, 0, mSize.x, mSize.y);
				g.drawRect(view.x, view.y, view.w, view.h);
				g.endFill();
				boxing.cacheAsBitmap = true;
			}
			else
			{
				if (boxing != null)
				{
					boxing.graphics.clear();
					mCanvas.parent.removeChild(boxing);
				}
			}
		}
		
		if (Std.is(mCanvas, Bitmap))
		{
			var b:Bitmap = cast mCanvas;
			if (b.bitmapData != null) b.bitmapData.dispose();
			
			b.x = view.x;
			b.y = view.y;
			
			if (internalResolution != null)
			{
				b.bitmapData = new BitmapData(internalResolution.x, internalResolution.y, true, color);
				b.scaleX = view.w / internalResolution.x;
				b.scaleY = view.h / internalResolution.y;
			}
			else
			{
				b.bitmapData = new BitmapData(view.w, view.h, true, color);
				b.scaleX = b.scaleY = 1;
			}
			
			b.smoothing = true;
			
			mContext = b.bitmapData;
		}
		else
		if (Std.is(mCanvas, Sprite))
		{
			if (internalResolution != null)
			{
				mCanvas.scaleX = view.w / internalResolution.x;
				mCanvas.scaleY = view.h / internalResolution.y;
				mCanvas.x = view.x;
				mCanvas.y = view.y;
			}
			else
			{
				mCanvas.scaleX = mCanvas.scaleY = 1;
				mCanvas.x = view.x;
				mCanvas.y = view.y;
			}
			
			drawBoxing();
		}
		else
		if (Std.is(mCanvas, Shape))
		{
			mCanvas.scaleX = mCanvas.scaleY = 1;
			mCanvas.x = view.x;
			mCanvas.y = view.y;
			
			drawBoxing();
		}
	}
	
	function onResize(?_)
	{
		resize(stage.stageWidth, stage.stageHeight);
	}
	
	function onFullScreen(e:Event)
	{
		mFullscreen = stage.displayState == StageDisplayState.FULL_SCREEN_INTERACTIVE;
		mListener.onFullscreenChanged(mFullscreen);
	}
	
	function onActivate(e:Event)
	{
		if (mVisible) return;
		mVisible = true;
		mListener.onVisibilityChanged(true);
	}
	
	function onDeactivate(e:Event)
	{
		if (!mVisible) return;
		mVisible = false;
		mListener.onVisibilityChanged(false);
	}
	
	function onContext3dCreate(_)
	{
		mStage3dContext = mStage3d.context3D;
		
		mStage3dContext.setCulling(Context3DTriangleFace.NONE);
		mStage3dContext.setDepthTest(false, Context3DCompareMode.ALWAYS);
		
		#if debug
		mStage3dContext.enableErrorChecking = true;
		#else
		mStage3dContext.enableErrorChecking = false;
		#end
		
		mContext = mStage3dContext;
		
		configureBackBuffer();
		
		mListener.onContext();
		
		resize(stage.stageWidth, stage.stageHeight);
		
		if (++mContextCreatedCounter == 1)
		{
			L.d('driverInfo: ${mStage3dContext.driverInfo}', "stage3d");
			if (mRenderer != null)
				mRenderer.onInitRenderContext(mStage3dContext);
		}
		else
		{
			if (mRenderer != null)
				mRenderer.onRestoreRenderContext(mStage3dContext);
		}
	}
	
	function onRightClick(_)
	{
	}
	
	function onError(e)
	{
		L.e(Std.string(e));
	}
}