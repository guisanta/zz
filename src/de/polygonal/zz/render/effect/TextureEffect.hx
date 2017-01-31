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
package de.polygonal.zz.render.effect;

import de.polygonal.core.math.Rectf;
import de.polygonal.core.math.Recti;
import de.polygonal.zz.render.effect.Effect;
import de.polygonal.zz.render.effect.Effect.*;
import de.polygonal.zz.render.Renderer;
import de.polygonal.zz.texture.atlas.TextureAtlas;
import de.polygonal.zz.texture.Texture;

class TextureEffect extends Effect
{
	#if flash
	inline public static var HINT_COMPRESSED = 0x01;
	inline public static var HINT_COMPRESSED_ALPHA = 0x02;
	#end
	
	inline public static var TYPE = 1;
	
	public var texture:Texture;
	
	public var atlas(default, null):TextureAtlas;
	
	public var cropRectUv:Rectf;
	public var cropRectPx:Recti;
	
	public var uvOffsetX:Float = 0;
	public var uvOffsetY:Float = 0;
	public var uvScaleX:Float = 1;
	public var uvScaleY:Float = 1;
	
	var mFrameId:Int = -1;
	
	var mCropRectPx:Recti;
	var mCropRectUv:Rectf;
	
	public function new()
	{
		super(TYPE);
		
		mCropRectPx = new Recti(0, 0, 0, 0);
		mCropRectUv = new Rectf(0, 0, 0, 0);
	}
	
	public function setTexture(texture:Texture, ?atlas:TextureAtlas):TextureEffect
	{
		mFrameId = -1;
		
		this.texture = texture;
		this.atlas = atlas;
		
		var sx = texture.sourceSize.x;
		var sy = texture.sourceSize.y;
		
		cropRectPx = mCropRectPx;
		cropRectPx.w = sx;
		cropRectPx.h = sy;
		
		cropRectUv = mCropRectUv;
		cropRectUv.w = sx / texture.paddedSize.x;
		cropRectUv.h = sy / texture.paddedSize.y;
		
		hint = 0;
		
		pma = texture.isAlphaPremultiplied;
		
		#if flash
		if (texture.isCompressed)
		{
			pma = false;
			switch (texture.format)
			{
				case flash.display3D.Context3DTextureFormat.COMPRESSED:
					hint |= HINT_COMPRESSED;
				
				case flash.display3D.Context3DTextureFormat.COMPRESSED_ALPHA:
					hint |= HINT_COMPRESSED_ALPHA;
				
				case _:
			}
		}
		#end
		
		return this;
	}
	
	override public function free()
	{
		super.free();
		cropRectUv = null;
		cropRectPx = null;
	}
	
	inline public function getFrameId():Int
	{
		return mFrameId;
	}
	
	inline public function setFrameId(value:Int)
	{
		if (mFrameId != value) updateFrame(value);
	}
	
	function updateFrame(frame:Int)
	{
		mFrameId = frame;
		cropRectUv = atlas.getFrameById(frame).texCoordUv;
		cropRectPx = atlas.getFrameById(frame).texCoordPx;
	}
	
	override public function draw(renderer:Renderer)
	{
		renderer.drawTextureEffect(this);
	}
}