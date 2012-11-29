/*
 *                            _/                                                    _/
 *       _/_/_/      _/_/    _/  _/    _/    _/_/_/    _/_/    _/_/_/      _/_/_/  _/
 *      _/    _/  _/    _/  _/  _/    _/  _/    _/  _/    _/  _/    _/  _/    _/  _/
 *     _/    _/  _/    _/  _/  _/    _/  _/    _/  _/    _/  _/    _/  _/    _/  _/
 *    _/_/_/      _/_/    _/    _/_/_/    _/_/_/    _/_/    _/    _/    _/_/_/  _/
 *   _/                            _/        _/
 *  _/                        _/_/      _/_/
 *
 * POLYGONAL - A HAXE LIBRARY FOR GAME DEVELOPERS
 * Copyright (c) 2009 Michael Baczynski, http://www.polygonal.de
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
package de.polygonal.zz.render.module;

import de.polygonal.core.fmt.NumberFormat;
import de.polygonal.core.fmt.Sprintf;
import de.polygonal.core.Root;
import de.polygonal.core.util.Assert;
import de.polygonal.ds.Bits;
import de.polygonal.ds.DA;
import de.polygonal.ds.IntHashTable;
import de.polygonal.zz.render.effect.Effect.*;
import de.polygonal.zz.render.effect.Effect;
import de.polygonal.zz.render.effect.SpriteSheetEffect;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.render.flash.stage3d.paintbox.Stage3DBrush;
import de.polygonal.zz.render.flash.stage3d.paintbox.Stage3DBrushRectNull;
import de.polygonal.zz.render.flash.stage3d.paintbox.Stage3DBrushRectSolid;
import de.polygonal.zz.render.flash.stage3d.paintbox.Stage3DBrushRectTexture;
import de.polygonal.zz.render.flash.stage3d.paintbox.Stage3DBrushRectTextureBatch;
import de.polygonal.zz.render.flash.stage3d.Stage3DAntiAliasMode;
import de.polygonal.zz.render.flash.stage3d.Stage3DTexture;
import de.polygonal.zz.render.flash.stage3d.Stage3DTextureFlag;
import de.polygonal.zz.render.RenderSurface;
import de.polygonal.zz.render.texture.Image;
import de.polygonal.zz.render.texture.Tex;
import de.polygonal.zz.scene.AlphaState;
import de.polygonal.zz.scene.Camera;
import de.polygonal.zz.scene.GeometryType;
import de.polygonal.zz.scene.Renderer;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.scene.TriMesh;
import flash.display.Stage3D;
import flash.display3D.Context3D;
import flash.display3D.Context3DBlendFactor;
import flash.display3D.Context3DCompareMode;
import flash.display3D.Context3DTriangleFace;

class FlashStage3DRenderer extends Renderer
{
	public static var BATCH_STRATEGY        = 0; //0 => use vertex buffer, 1 => use constant registers
	public static var MAX_BATCH_SIZE        = 4096;
	public static var DEFAULT_TEXTURE_FLAGS = Stage3DTextureFlag.PRESET_QUALITY_MEDIUM;
	
	public var context(default, null):Context3D;
	public var numCallsToDrawTriangle:Int;
	public var currStage3DTexture:Stage3DTexture;
	
	var _antiAliasMode:Int;
	var _enableDepthBufferAndStencil:Bool;
	var _batchActive:Bool;
	var _batch:DA<Spatial>;
	var _currBrush:Stage3DBrush;
	var _paintBox:IntHashTable<Stage3DBrush>;
	var _textureHandles:IntHashTable<Stage3DTexture>;
	var _srcBlendFactorLUT:Array<Context3DBlendFactor>;
	var _dstBlendFactorLUT:Array<Context3DBlendFactor>;
	
	public function new()
	{
		super();
		
		if (!RenderSurface.isHardware())
			throw 'stage3d not available';
		
		context = RenderSurface.stage3D.context3D;
		context.setCulling(Context3DTriangleFace.NONE);
		context.setDepthTest(false, Context3DCompareMode.ALWAYS);
		
		#if debug
		trace('driverInfo: ' + context.driverInfo);
		context.enableErrorChecking = true;
		#end
		
		setAntiAlias(Stage3DAntiAliasMode.Low);
		
		_paintBox = new IntHashTable(256, 256, false, 256);
		
		registerBrush(Stage3DBrushRectNull, 0, 0);
		
		registerSharedBrush(Stage3DBrushRectSolid, EFF_COLOR | EFF_ALPHA | EFF_COLOR_XFORM, 0);
		
		registerBrush(Stage3DBrushRectTexture, EFF_TEXTURE                              , DEFAULT_TEXTURE_FLAGS, false);
		registerBrush(Stage3DBrushRectTexture, EFF_TEXTURE | EFF_ALPHA                  , DEFAULT_TEXTURE_FLAGS, false);
		registerBrush(Stage3DBrushRectTexture, EFF_TEXTURE | EFF_COLOR_XFORM            , DEFAULT_TEXTURE_FLAGS, false);
		registerBrush(Stage3DBrushRectTexture, EFF_TEXTURE | EFF_ALPHA | EFF_COLOR_XFORM, DEFAULT_TEXTURE_FLAGS, false);
		
		registerBrush(Stage3DBrushRectTextureBatch, EFF_TEXTURE                              , DEFAULT_TEXTURE_FLAGS, true);
		registerBrush(Stage3DBrushRectTextureBatch, EFF_TEXTURE | EFF_ALPHA                  , DEFAULT_TEXTURE_FLAGS, true);
		registerBrush(Stage3DBrushRectTextureBatch, EFF_TEXTURE | EFF_COLOR_XFORM            , DEFAULT_TEXTURE_FLAGS, true);
		registerBrush(Stage3DBrushRectTextureBatch, EFF_TEXTURE | EFF_ALPHA | EFF_COLOR_XFORM, DEFAULT_TEXTURE_FLAGS, true);
		
		_srcBlendFactorLUT = 
		[
			Context3DBlendFactor.ZERO,
			Context3DBlendFactor.ONE,
			Context3DBlendFactor.DESTINATION_COLOR,
			Context3DBlendFactor.ONE_MINUS_DESTINATION_COLOR,
			Context3DBlendFactor.SOURCE_ALPHA,
			Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA,
			Context3DBlendFactor.DESTINATION_ALPHA,
			Context3DBlendFactor.ONE_MINUS_DESTINATION_ALPHA
		];
		
		_dstBlendFactorLUT = 
		[
			Context3DBlendFactor.ZERO,
			Context3DBlendFactor.ONE,
			Context3DBlendFactor.SOURCE_COLOR,
			Context3DBlendFactor.ONE_MINUS_SOURCE_COLOR,
			Context3DBlendFactor.SOURCE_ALPHA,
			Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA,
			Context3DBlendFactor.DESTINATION_ALPHA,
			Context3DBlendFactor.ONE_MINUS_DESTINATION_ALPHA
		];
		
		_camera = null;
		_textureHandles = new IntHashTable(32, 32, false, 32);
		_enableDepthBufferAndStencil = false;
		_batch = new DA();
		configureBackBuffer();
		
		//batch rendering is on by default
		drawDeferred = drawDeferredBatch;
	}
	
	override public function free()
	{
		for (handle in _textureHandles)
		{
			if (handle == null) continue;
			handle.free();
		}
		_textureHandles.free();
		_textureHandles = null;
		
		context.dispose();
		context = null;
		
		super.free();
	}
	
	override public function createTex(image:Image):Tex
	{
		return new Tex(image, true, true);
	}
	
	override public function onViewPortChange()
	{
		super.onViewPortChange();
		configureBackBuffer();
	}
	
	/**
	 * Default is <em>Stage3DAntiAliasMode.Low</em>.
	 */
	public function setAntiAlias(mode:Stage3DAntiAliasMode)
	{
		var mode = 
		switch (mode) 
		{
			case Stage3DAntiAliasMode.None:   0;
			case Stage3DAntiAliasMode.Low:    2;
			case Stage3DAntiAliasMode.High:   4;
			case Stage3DAntiAliasMode.Ultra: 16;
		}
		
		if (mode != _antiAliasMode)
		{
			_antiAliasMode = mode;
			if (context != null) configureBackBuffer();
		}
	}
	
	/**
	 * Default value is false.
	 */
	public function enableDepthBufferAndStencil(x:Bool)
	{
		if (x != _enableDepthBufferAndStencil)
		{
			_enableDepthBufferAndStencil = x;
			configureBackBuffer();
		}
	}
	
	public function initStage3DTexture(tex:Tex):Stage3DTexture
	{
		var t = _textureHandles.get(tex.key);
		if (t == null)
		{
			trace('create & upload texture (%d)', tex.key);
			t = new Stage3DTexture(tex);
			t.upload(context);
			_textureHandles.set(tex.key, t);
		}
		return t;
	}
	
	public function freeStage3DTexture(tex:Tex):Void
	{
		var t = _textureHandles.get(tex.key);
		if (t != null)
		{
			trace('dispose texture (%d)', tex.key);
			t.free();
			_textureHandles.clr(tex.key);
		}
	}
	
	override public function drawTextureEffect(effect:TextureEffect)
	{
		super.drawTextureEffect(effect);
		
		currTexture = effect.tex;
		currStage3DTexture = initStage3DTexture(currTexture);
		
		var brush = getBrush(effect.flags, currStage3DTexture.flags, false);
		brush.bindVertexBuffer();
		brush.add(currGeometry);
		brush.draw(this);
		brush.unbindVertexBuffer();
	}
	
	override public function drawSpriteSheetEffect(effect:SpriteSheetEffect)
	{
		if (_batchActive)
		{
			var effectFlags = effect.flags;
			
			//accumulate for batch rendering
			if (_currBrush == null)
			{
				_currBrush = getBrush(effectFlags, currStage3DTexture.flags, true);
			}
			
			//currEffectFlags = effectFlags;
			
			//_getBrush(effect.getState(), true).
			
			//_brushRectVertexBatch.batch(currGeometry);
			//_currBrush.batch(currGeometry);
			
			throw 'todo drawSpriteSheetEffect _rectConstantBatch';
			
			//_rectConstantBatch.batch(currGeometry);
		}
		else
		{
			super.drawSpriteSheetEffect(effect);
			
			//var alphaState = currGeometry.states.get(Type.enumIndex(GlobalStateType.Alpha));
			//if (alphaState != null)
			
			//single drawTriangles() call per object
			currTexture = effect.tex;
			currStage3DTexture = initStage3DTexture(currTexture);
			
			var brush = getBrush(effect.flags, currStage3DTexture.flags, false);
			brush.bindVertexBuffer();
			brush.add(currGeometry);
			brush.draw(this);
			brush.unbindVertexBuffer();
		}
	}
	
	//TODO should support different brushes
	/*override public function drawSpriteSheetBatchEffect(effect:SpriteSheetBatchEffect)
	{
		//disable effect, accumulate children, restore effect
		_batchActive = true;
		
		var tmp = currGlobalEffect;
		
		currNode.effect = null;
		currNode.draw(this, noCulling);
		
		//same texture for all nodes
		currTexture = effect.tex;
		
		//_paint(_currBrush);
		
		_batchActive = false;
		currNode.effect = tmp;
	}*/
	
	/*override public function drawBitmapFont(effect:BitmapFontEffect)
	{
		//should be a mesh...
		var mesh:TriMesh = cast currGeometry;
		throw 'todo';
	}*/
	
	override public function drawDeferredBatch()
	{
		if (_deferredObjects.isEmpty()) return;
		
		//disable deferred drawing
		var save = drawDeferred;
		drawDeferred = null;
		
		var currEffectFlags = -1;
		var prevBrush:Stage3DBrush = null;
		var currBrush:Stage3DBrush = null;
		currTexture = null;
		
		var numBatchCalls = 0;
		
		for (i in 0..._deferredObjects.size())
		{
			var o = _deferredObjects.get(i);
			
			//TODO untested
			if (o.isNode())
			{
				//TODO if a node has a batch flag, just send all child nodes to the renderer...
				//just draw them batched..
				//if (o.effect == o.effect.__spriteSheetBatchEffect)
					//o.draw(this, noCulling);
				continue;
			}
			
			#if debug
			D.assert(o.effect != null, 'no effect assigned');
			#end
			
			var effect = o.effect;
			var effectFlags = effect.flags;
			
			//first geometry node?
			if (currEffectFlags == -1)
			{
				currEffectFlags = effectFlags;
				currTexture = effect.tex;
				
				if (currTexture != null)
				{
					currStage3DTexture = initStage3DTexture(currTexture);
					currBrush = getBrush(effectFlags, currStage3DTexture.flags, true);
				}
				else
					currBrush = getBrush(effectFlags, 0, false);
				
				currBrush.add(o.__geometry);
			}
			else
			{
				//effect state change or batch exhausted?
				if (effectFlags != currEffectFlags || effect.tex != currTexture || currBrush.isFull())
				{
					//draw current batch
					if (currBrush != prevBrush)
					{
						if (prevBrush != null) prevBrush.unbindVertexBuffer();
						currBrush.bindVertexBuffer();
					}
					prevBrush = currBrush;
					
					currBrush.draw(this);
					numBatchCalls++;
					
					//start new batch with current geometry
					currEffectFlags = effectFlags;
					currTexture = effect.tex;
					currStage3DTexture = initStage3DTexture(currTexture);
					currBrush = getBrush(effectFlags, currStage3DTexture.flags, true);
				}
				
				currBrush.add(o.__geometry);
			}
		}
		
		//draw remainder
		if (!currBrush.isEmpty())
		{
			if (currBrush != prevBrush)
			{
				if (prevBrush != null)
					prevBrush.unbindVertexBuffer();
				currBrush.bindVertexBuffer();
			}
			currBrush.draw(this);
			numBatchCalls++;
		}
		
		currBrush.unbindVertexBuffer();
		
		//restore deferred drawing
		drawDeferred = save;
	}
	
	override public function setAlphaState(state:AlphaState)
	{
		context.setBlendFactors
		(
			_srcBlendFactorLUT[Type.enumIndex(state.src)],
			_dstBlendFactorLUT[Type.enumIndex(state.dst)]
		);
	}
	
	override function drawElements()
	{
		if (currGeometry.type == GeometryType.QUAD)
		{
			if (currEffect == null)
			{
				return;
			}
			
			var e = currEffect.flags;
			
			var textureFlags = 0;
			
			if (allowTextures)
			{
				if (currTexture != null)
				{
					currStage3DTexture = initStage3DTexture(currTexture);
					textureFlags = currStage3DTexture.flags;
				}
			}
			else
				e &= ~EFF_TEXTURE;
			
			var brush = getBrush(e, textureFlags, false);
			brush.bindVertexBuffer();
			brush.add(currGeometry);
			brush.draw(this);
			brush.unbindVertexBuffer();
		}
		else
		if (currGeometry.type == GeometryType.TRIMESH)
		{
			
		}
	}
	
	override function onBeginScene()
	{
		context.clear(_backgroundColor.r, _backgroundColor.g, _backgroundColor.b, _backgroundColor.a);
		numCallsToDrawTriangle = 0;
	}
	
	override function onEndScene()
	{
		context.present();
	}
	
	function configureBackBuffer()
	{
		try
		{
			context.configureBackBuffer(RenderSurface.width, RenderSurface.height, _antiAliasMode, _enableDepthBufferAndStencil);
		}
		catch (unknown:Dynamic)
		{
			Root.error(Std.string(unknown));
		}
	}
	
	function registerBrush(brush:Class<Stage3DBrush>, supportedEffects:Int, textureFlags = 0, supportsBatching = false)
	{
		var args:Array<Dynamic> = [context, supportedEffects, textureFlags];
		
		if (supportedEffects & EFF_TEXTURE == 0) args.pop();
		
		var brush = Type.createInstance(brush, args);
		
		_paintBox.set(getBrushKey(supportedEffects, textureFlags, supportsBatching), brush);
	}
	
	function registerSharedBrush(brush:Class<Stage3DBrush>, supportedEffects:Int, textureFlags:Int, supportsBatching = false)
	{
		var map = new IntHash<Int>();
		var k = 32 - Bits.nlz(supportedEffects);
		for (i in 0...k)
		{
			var mask = 1 << i;
			for (j in 0...k)
			{
				if (i == j) continue;
				map.set(mask, mask);
				mask |= (1 << j);
				
			}
		}
		
		var args:Array<Dynamic> = [context, supportedEffects, textureFlags];
		if (supportedEffects & EFF_TEXTURE == 0) args.pop();
		var brush = Type.createInstance(brush, args);
		
		var exclude = 0;
		var i = 0;
		var t = supportedEffects;
		while (t != 0)
		{
			if (t & 1 == 0)
				exclude |= 1 << i;
			i++;
			t >>= 1;
		}
		
		for (mask in map.keys())
			if (mask & exclude == 0)
				_paintBox.set(getBrushKey(mask, textureFlags, supportsBatching), brush);
	}
	
	inline function getBrush(supportedEffects:Int, textureFlags:Int, preferBatching:Bool):Stage3DBrush
	{
		var key = getBrushKey(supportedEffects, textureFlags, preferBatching);
		
		if (_paintBox.hasKey(key))
			return _paintBox.get(key);
		else
		{
			var brushClass = Type.getClass(_paintBox.get(getBrushKey(supportedEffects, DEFAULT_TEXTURE_FLAGS, preferBatching)));
			registerBrush(brushClass, supportedEffects, textureFlags, preferBatching);
			
			var brush = _paintBox.get(key);
			
			#if debug
			D.assert(brush != null, Sprintf.format('no registered found for effect %b and texture flags %b', [supportedEffects, textureFlags]));
			#end
			
			return brush;
		}
	}
	
	inline function getBrushKey(supportedEffects:Int, textureFlags:Int, supportsBatching:Bool):Int
	{
		return supportedEffects | textureFlags | (supportsBatching ? (1 << 25) : 0);
	}
	
	override function getType():Int 
	{
		return Renderer.TYPE_FLASH_HARDWARE;
	}
}