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

import de.polygonal.core.math.Coord2.Coord2f;
import de.polygonal.core.math.Coord2.Coord2i;
import de.polygonal.core.math.Mat44;
import de.polygonal.core.math.Vec3;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.ArrayList;
import de.polygonal.zz.render.effect.*;
import de.polygonal.zz.scene.*;
import de.polygonal.zz.scene.AlphaBlendState.AlphaBlendMode;
import de.polygonal.zz.texture.*;
import haxe.EnumFlags;
import de.polygonal.core.util.ClassUtil;

@:allow(de.polygonal.zz.render.effect)
class Renderer
{
	public static var current:Renderer = null;
	
	public var currentMvp:Mat44;
	public var currentViewProjMat:Mat44;
	
	public var currentVisual:Visual;
	public var currentEffect:Effect;
	
	public var allowedGlobalStates:EnumFlags<GlobalStateType>;
	
	public var smooth(get, set):Bool;
	inline function get_smooth():Bool return mSmooth;
	inline function set_smooth(value:Bool):Bool
	{
		if (mSmooth != value)
			mSmoothChanged = true;
		mSmooth = value;
		return value;
	}
	
	/**
		If true, this renderer supports NPOT (non-power-of-two) textures. Default is false.
	**/
	public var supportsNonPowerOfTwoTextures(default, null):Bool = false;
	
	/**
		If true, culling is disabled. Default is false.
	**/
	public var noCull:Bool;
	
	public var allowTextures = true;
	
	public var maxBatchSize(default, null):Int = 4096;
	
	public var currentAlphaBlending:AlphaBlendState;
	
	public var currentAlphaMultiplier(default, null):Float = 1;
	
	var mRenderTarget:RenderTarget;
	
	var mCuller:Culler;
	var mCamera:Camera;
	
	var mProjMatrix:Mat44;
	var mInvProjMatrix:Mat44;
	
	var mCurSceneRoot:Node;
	
	var mSmooth:Bool;
	var mSmoothChanged:Bool;
	
	var mScratchVec:Vec3;
	
	public function new()
	{
		L.d('${ClassUtil.getUnqualifiedClassName(this)} created');
		
		mCuller = new Culler(this);
		
		mCamera = new Camera(this);
		
		mProjMatrix = new Mat44();
		mInvProjMatrix = new Mat44();
		
		currentMvp = new Mat44();
		currentViewProjMat = new Mat44();
		
		currentAlphaBlending = null;
		
		mSmooth = true;
		mSmoothChanged = true;
		
		mScratchVec = new Vec3();
		
		allowedGlobalStates = new EnumFlags<GlobalStateType>();
		allowedGlobalStates.set(GlobalStateType.AlphaBlend);
		allowedGlobalStates.set(GlobalStateType.AlphaMultiplier);
	}
	
	public function free()
	{
		mRenderTarget = null;
		mCuller.free();
		mCuller = null;
		mCamera.free();
		mCamera = null;
	}
	
	public function setRenderTarget(target:RenderTarget)
	{
		mRenderTarget = target;
	}
	
	public function getRenderTarget():RenderTarget return mRenderTarget;
	
	public function getCamera():Camera return mCamera;
	
	public function setCamera(value:Camera) mCamera = value;
	
	/**
		Finds the position of the pixel (`x`,`y`) in world space.
	**/
	public function mapPixelToWorld(x:Int, y:Int, output:Coord2f):Coord2f
	{
		var p = mScratchVec;
		
		//viewport -> homogeneous coordinates
		screenToCanonicalViewVolume(x, y, p);
		
		//homogenous -> camera coordinates
		mInvProjMatrix.timesVectorAffine2d(p); //TODO make sure invProjMatrix is current
		
		getCamera().getInvViewMatrix().timesVectorAffine2d(p);
		
		//TODO precompute matrix
		//var inverse = new Mat44();
		//currentViewProjMat.inverseConst(inverse);
		//inverse.timesVectorAffine2d(p);
		output.x = p.x;
		output.y = p.y;
		
		return output;
	}
	
	/**
		Finds the pixel of the render-target that matches the given 2d point (`x`,`y`) in world space.
	**/
	public function mapWorldToPixel(x:Float, y:Float, output:Coord2i):Coord2i
	{
		var p = mScratchVec;
		p.set(x, y, 0);
		
		//p' = PVp
		currentViewProjMat.timesVector(p); //TODO make sure it's current
		
		//maps normalized device coordinates into window (screen) coordinates
		viewportTransform(p);
		
		output.x = Std.int(p.x);
		output.y = Std.int(p.y);
		
		return output;
	}
	
	public function drawScene(scene:Node)
	{
		assert(scene != null);
		
		//quit if back buffer or context is invalid
		if (getRenderTarget().getSize().isZero()) return;
		if (getRenderTarget().getContext() == null) return;
		
		mCurSceneRoot = scene;
		
		//set projection matrix
		mProjMatrix = getProjectionMatrix();
		mProjMatrix.inverseConst(mInvProjMatrix);
		
		//set view-projection matrix
		currentViewProjMat.of(mProjMatrix);
		
		if (getCamera() != null) currentViewProjMat.timesMatrix(getCamera().getViewMatrix());
		
		//currentAlphaMultiplier = 1;
		//currentAlphaBlending = AlphaBlendMode.Normal;
		
		onBeginScene();
		
		var visibleSet = mCuller.computeVisibleSet(scene, noCull);
		
		drawVisibleSet(visibleSet);
		
		onEndScene();
	}
	
	/**
		Entry point to drawing the visible set of a scene graph.
	**/
	public function drawVisibleSet(visibleSet:ArrayList<Visual>)//, ?globalEffect:GlobalEffect)
	{
		//if (globalEffect == null) //TODO for batching?
		for (i in 0...visibleSet.size)
			drawVisual(Spatial.as(visibleSet.get(i), Visual));
		//else
			//globalEffect.draw(this, visibleSet);
	}
	
	function drawVisual(visual:Visual) //TODO inline, needs to be overrided?
	{
		currentVisual = visual;
		
		var e = visual.effect;
		
		assert(e != null);
		
		if (e.active)
		{
			currentEffect = e;
			setGlobalState(visual);
			e.draw(this);
			currentEffect = null;
		}
		
		currentVisual = null;
	}
	
	
	/*function setProjectionMatrix(x:Mat44)
	{
		mProjMatrix = x;
		mUpdateInverseProjectionMatrix = true;
	}
	
	function getInverseProjectionMatrix():Mat44
	{
		if (mUpdateInverseProjectionMatrix)
		{
			mUpdateInverseProjectionMatrix = false;
			mProjMatrix.inverseConst(mInvProjMatrix);
		}
		return mInvProjMatrix;
	}*/
	
	function getProjectionMatrix():Mat44
	{
		return throw 'override for implementation';
	}
	
	function viewportTransform(output:Vec3)
	{
		//maps normalized device coordinates into window (screen) coordinates
		var viewport = getRenderTarget().getPixelViewport();
		output.x = ( output.x + 1) / 2 * viewport.w + viewport.x;
		output.y = (-output.y + 1) / 2 * viewport.h + viewport.y;
	}
	
	function screenToCanonicalViewVolume(x:Int, y:Int, output:Vec3)
	{
		var viewport = getRenderTarget().getPixelViewport();
		output.x = -1. + 2. * (x - viewport.x) / viewport.w;
		output.y =  1. - 2. * (y - viewport.y) / viewport.h;
	}
	
	
	
	
	
	/**
		Computes the MVP (model-view-projection) matrix for `spatial` and stores the result in the this.`currentMvp`.
		
		Steps to go from model to clip space (starting with model coordinates):
		1. apply model matrix => world coodinates
		2. apply view matrix => camera coordinates
		3. apply projection matrix => homogeneous coordinates
	**/
	public function setModelViewProjMatrix(world:Xform):Mat44
	{
		//convert transformation to 4x4 matrix
		world.getHMatrix(currentMvp);
		
		//TODO optimize
		//concatenate with view and projection matrix
		currentMvp.cat(currentViewProjMat);
		
		return currentMvp;
	}
	
	function clear()
	{
	}
	
	function onBeginScene()
	{
	}
	
	function onEndScene()
	{
	}
	
	function present()
	{
	}
	
	function drawColorEffect(effect:ColorEffect)
	{
		throw "override for implementation";
	}
	
	function drawTextureEffect(effect:TextureEffect)
	{
		throw "override for implementation";
	}
	
	function drawTileMapEffect(effect:TileMapEffect)
	{
		throw "override for implementation";
	}
	
	function onInitRenderContext(handle:Dynamic)
	{
		throw "override for implementation";
	}
	
	function onRestoreRenderContext(handle:Dynamic)
	{
	}
	
	function onTargetResize(width:Int, height:Int)
	{
	}
	
	function onCameraChanged()
	{
	}
	
	//TODO initial values for new batch?
	public function setGlobalState(visual:Visual)
	{
		if (allowedGlobalStates.toInt() == 0) return;
		
		if (allowedGlobalStates.has(AlphaMultiplier))
		{
			var state = visual.stateList[GlobalStateType.AlphaMultiplier.getIndex()];
			var alpha = state != null ? state.as(AlphaMultiplierState).value : 1;
			if (alpha != currentAlphaMultiplier) setAlphaMultiplierState(currentAlphaMultiplier = alpha);
		}
		
		if (allowedGlobalStates.has(AlphaBlend))
		{
			var state = visual.stateList[GlobalStateType.AlphaBlend.getIndex()];
			if (state != null)
			{
				if (currentAlphaBlending == null || !currentAlphaBlending.equals(state))
				{
					currentAlphaBlending = state.as(AlphaBlendState);
					setAlphaBlendState(currentAlphaBlending.alphaBlendMode);
				}
			}
			else
			{
				if (currentAlphaBlending != null)
					setAlphaBlendState(AlphaBlendState.PRESET_NORMAL.alphaBlendMode);
			}
		}
	}
	
	function setAlphaMultiplierState(value:Float)
	{
	}
	
	function setAlphaBlendState(value:AlphaBlendMode)
	{
	}
}